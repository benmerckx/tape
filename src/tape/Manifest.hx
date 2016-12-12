package tape;

import asys.io.File;
import haxe.DynamicAccess;
import haxe.Json;
import semver.SemVer;
import tape.solver.Solver;
import tink.RunLoop;

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
	@:optional 
    var main: String;
}

typedef ManifestData = {
	var name: String;
	var version: SemVer;
	var dependencies: Array<Dependency>;
    var reels: Map<String, Array<Dependency>>;
	var main: Option<String>;
}

@:forward
abstract Manifest(ManifestData) from ManifestData {

    public function new(name: String, version: SemVer)
        this = {
            name: name, version: version, 
            dependencies: [], reels: new Map(), 
            main: None
        }

    public function resolveLock(): Promise<Lock> {
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
            var worker = RunLoop.current.createSlave();
            results.push(Future.flatten(
                RunLoop.current.delegate(function() {
                    var trigger = Future.trigger();
                    task.solver.solve().handle(function(result) {
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
                return Failure(TapeError.create('Version conflicts', errors));
            return Success(lock);
        });
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
                main: data.main == null ? None : Some(data.main)
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

}