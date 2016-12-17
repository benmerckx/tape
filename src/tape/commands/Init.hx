package tape.commands;

import tape.Manifest;
import haxe.io.Path;
import asys.FileSystem;

using tink.CoreApi;

class Init extends Command {

    public static function run() {
        return FileSystem.exists(Manifest.FILE).flatMap(function(exists) {
            if (exists)
                return Future.sync(Failure(TapeError.create('Manifest file "${Manifest.FILE}" already exists')));
            var name = Path.normalize(Sys.getCwd()).split('/').pop();
            var manifest = new Manifest(name, '0.0.0');
            return manifest.write()
                .next(function (res) return 'Initialized "$manifest"');
        });
    }

    public function runDefault()
        run().handle(report);

}