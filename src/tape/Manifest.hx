package tape;

import asys.io.File;
import haxe.DynamicAccess;
import haxe.Json;
import semver.SemVer;
import tape.solver.Solver;

using tink.CoreApi;

typedef JsonSchema = {
    @:optional 
	var name: String;
    @:optional 
	var version: String;
	@:optional 
    var dependencies: DynamicAccess<String>;
	@:optional 
    var tape: {
        ?dependencies: DynamicAccess<String>,
        ?reels: DynamicAccess<DynamicAccess<String>>
    };
}

typedef ManifestData = {
	var name: String;
	var version: SemVer;
	var dependencies: Array<Dependency>;
    var reels: Map<String, Array<Dependency>>;
	var metadata: Map<String, Any>;
}

@:forward
abstract Manifest(ManifestData) from ManifestData {

    public static var FILE = 'haxelib.json';

    public function new(name: String, version: SemVer)
        this = {
            name: name, version: version, 
            dependencies: [], reels: new Map(), 
            metadata: new Map()
        }

    public function key()
        return this.name+'@'+this.version;

    public function write(): Promise<Noise>
        return File.saveContent(FILE, tape.Json.stringify(toJson()));

    public function addDependency(dependency: Dependency)
        this.dependencies.push(dependency);

    public function lock(reporter: Reporter): Promise<Lock> {
        var tasks = [], results = [];
        tasks.push({
            name: null, 
            solver: new Solver(this.dependencies)
        });
        for (reel in this.reels.keys())
            tasks.push({
                name: reel, 
                solver: new Solver(this.reels.get(reel).concat(this.dependencies))
            });
        for (task in tasks) {
            results.push(
                (task.solver.solve(reporter.task(
                    if (task.name == null) 'Resolving dependencies'
                    else 'Resolving reel "${task.name}"'
                    ))
                    : Surprise<Map<String, Manifest>, Error>)
            .map(function(result) return {
                name: task.name,
                versions: result
            }));
        }
        
        return Future.ofMany(results).map(function(response) {
            var lock = new Lock();
            var errors = [];
            for (result in response)
                switch result.versions {
                    case Success(versions):
                        if (result.name == null) lock.dependencies = versions;
                        else lock.reels.set(result.name, versions);
                    case Failure(e): errors.push(e);
                }
            if (errors.length > 0) 
                return Failure(TapeError.create('Could not lock down dependencies for "${this.name}"', errors));
            return Success(lock);
        });
    }

    function dependenciesJson(dependencies: Array<Dependency>)
        return [for (dependency in dependencies)
            dependency.name => '${dependency.source}'
        ];

    public function toJson() {
        var data = Reflect.copy(this.metadata);
        data.set('name', this.name);
        data.set('version', (this.version: String));
        data.set('tape', {
            dependencies: dependenciesJson(this.dependencies),
            reels: [for (reel in this.reels.keys())
                reel => dependenciesJson(this.reels.get(reel))
            ]
        });
        return data;
    }

    public static function fromJsonSchema(data: JsonSchema, ?name: String): Outcome<Manifest, Error> {
        function extract(input: DynamicAccess<String>)
            return [
                for (key in input.keys()) 
                    new Dependency(key, input.get(key))
            ];
        return Error.catchExceptions(function(): ManifestData
            return {
                name: 
                    if (data.name != null) data.name
                    else if (name != null) name
                    else throw 'Name field is empty',
                version: 
                    if (data.version != null) data.version
                    else if (name != null) ('0.0.0': SemVer)
                    else throw 'Version field is empty',
                dependencies: 
                    if (data.tape != null && data.tape.dependencies != null)
                        extract(data.tape.dependencies)
                    else
                        extract(data.dependencies),
                reels:
                    if (data.tape != null && data.tape.reels != null) [
                        for(reel in data.tape.reels.keys())
                            reel => extract(data.tape.reels.get(reel))
                    ] else new Map(),
                metadata: {
                    var fields: DynamicAccess<Any> = cast data;
                    var other = fields.keys().filter(function(key) 
                        return ['name', 'version', 'tape'].indexOf(key) == -1
                    );
                    [for (key in other) key => fields.get(key)];
                }
            }
        );
    }

    public static function fromFile(path: String, ?name: String): Promise<Manifest>
        return File.getContent(path).map(function(res) return switch res {
            case Success(data):
                try
                    fromJsonSchema(Json.parse(data), name)
                catch (e: Dynamic)
                    Failure(TapeError.create('Could not parse manifest file "$path"', TapeError.create('$e')));
            default: 
                Failure(TapeError.create('Could not read manifest file "$path"'));
        });

    @:to
    public function toString()
        return 
            [key()]
            .concat([
                for (dependency in this.dependencies) 
                    ' -'+dependency.toString()
            ]).join('\n');

}