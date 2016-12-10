package tape;

import asys.io.File;
import haxe.DynamicAccess;
import haxe.Json;
import semver.SemVer;
import tape.Source;

using tink.CoreApi;

typedef JsonSchema = {
	var name: String;
	var version: String;
	@:optional 
    var dependencies: DynamicAccess<String>;
	@:optional 
    var main: String;
}

typedef ManifestData = {
	var name: String;
	var version: SemVer;
	var dependencies: Array<Dependency>;
	var main: Option<String>;
}

@:forward
abstract Manifest(ManifestData) from ManifestData {

    public function new(name: String, version: SemVer)
        this = {
            name: name, version: version, dependencies: [], main: None
        }

    public function resolveLock(): Promise<Lock>
        return new Solver(this).solve();

    public static function fromJsonSchema(data: JsonSchema): Outcome<Manifest, Error>
        return Error.catchExceptions(function(): ManifestData
            return {
                name: data.name,
                version: data.version,
                dependencies: [
                    for (key in data.dependencies.keys()) 
                        new Dependency(key, data.dependencies.get(key))
                ],
                main: data.main == null ? None : Some(data.main)
            }
        );

    public static function fromFile(path: String): Promise<Manifest>
        return File.getContent(path).map(function(res) return switch res {
            case Success(data):
                try
                    fromJsonSchema(Json.parse(data))
                catch (e: Dynamic)
                    Failure(new Error('Could not parse manifest file "$path": $e'));
            default: 
                Failure(new Error('Could not read manifest file "$path"'));
        });

}