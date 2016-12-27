package tape;

import asys.io.File;
import haxe.DynamicAccess;
import semver.SemVer;
import tape.solver.Solver;
import tape.Json;
import tink.Url;

using tink.CoreApi;

typedef JsonSchema = {
    ?name: String,
    ?version: String,
	?dependencies: DynamicAccess<String>,
	?tape: {
        ?dependencies: DynamicAccess<String>,
        ?reels: DynamicAccess<DynamicAccess<String>>
    },
    ?location: String
    // ...metadata...
}

typedef ManifestData = {
	var name: String;
	var version: SemVer;
	var dependencies: Array<Dependency>;
    var reels: Map<String, Array<Dependency>>;
	var metadata: Map<String, Any>;
    var location: Option<Location>;
}

@:forward
abstract Manifest(ManifestData) from ManifestData {

    public static var FILE = 'haxelib.json';

    public function new(name: String, version: SemVer, ?location: Location)
        this = {
            name: name, version: version, 
            dependencies: [], reels: new Map(), 
            metadata: new Map(),
            location: if(location == null) None else Some(location)
        }

    public function key()
        return this.name+'@'+this.version;

    public function write(): Promise<Noise>
        return File.saveContent(FILE, Json.stringify(toJson()));

    public function addDependency(dependency: Dependency)
        this.dependencies.push(dependency);

    public function hash()
        return haxe.crypto.Md5.encode(Json.stringify(toJson(false)));

    public function lock(reporter: Reporter, previous: Option<Lock>): Promise<Lock> {
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
            var worker = tink.RunLoop.current.createSlave();
            results.push(Future.flatten(
                tink.RunLoop.current.delegate(function() {
                    var trigger = Future.trigger();
                    task.solver.solve(reporter.task(
                        if (task.name == null) 'Resolving dependencies'
                        else 'Resolving reel "${task.name}"'
                    ), previous).handle(function(result) {
                        trigger.trigger({
                            name: task.name,
                            versions: result
                        });
                    });
                    return trigger.asFuture();
                }, worker)
            ));
        }
        
        return Future.ofMany(results).map(function(response) {
            var lock = new Lock(this);
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

    public function toJson(metadata = true) {
        var data: Map<String, Any> = 
            if (metadata) [for (key in this.metadata.keys()) key => this.metadata.get(key)];
            else new Map();
        data.set('name', this.name);
        data.set('version', (this.version: String));
        data.set('tape', {
            dependencies: dependenciesJson(this.dependencies),
            reels: [for (reel in this.reels.keys())
                reel => dependenciesJson(this.reels.get(reel))
            ]
        });
        switch this.location {
            case Some(url): data.set('location', url);
            default:
        }
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
                    if (data.name != null) 
                        if (~/^[A-Za-z0-9_.-]+$/.match(data.name))
                            data.name
                        else
                            throw 'Name field must be alphanumeric (including _.-)'
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
                }, 
                location:
                    if (data.location != null)
                        Some((data.location: Location))
                    else
                        None
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
                Failure(TapeError.create('Could not read manifest file "$path", use tape init to create one'));
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