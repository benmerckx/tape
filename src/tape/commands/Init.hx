package tape.commands;

import mcli.CommandLine;
import tape.Manifest;
import haxe.io.Path;
import asys.FileSystem;

using tink.CoreApi;

class Init extends CommandLine {

    public function runDefault() {
        FileSystem.exists(Manifest.FILE).handle(function(exists) {
            if (exists)
                return Reporter.fail(TapeError.create('Manifest file "${Manifest.FILE}" already exists'));
            var name = Path.normalize(Sys.getCwd()).split('/').pop();
            var manifest = new Manifest(name, '0.0.0');
            manifest.write()
            .handle(function (res) switch res {
                case Success(_): Reporter.success('Initialized "$manifest"');
                case Failure(e): Reporter.fail(e);
            });
        });
    }

}