package tape;

import asys.io.File;
import haxe.DynamicAccess;
import haxe.Json;

using tink.CoreApi;

typedef Schema = {
	var name: String;
	var version: String;
	@:optional var dependencies: DynamicAccess<Any>;
	@:optional var main: String;
}

class Manifest {

    public function new() {}

    public static function fromFile(path: String): Promise<Manifest>
        return File.getContent(path).map(function(res) return switch res {
            case Success(data):
                try {
                    var decoded: Schema = Json.parse(data);
                    Success(new Manifest());
                } catch (e: Dynamic) {
                    Failure(new Error('Could not parse manifest file "$path": $e'));
                }
            default: 
                Failure(new Error('Could not read manifest file "$path"'));
        });

}