package tape.commands;

import tape.Manifest;
import haxe.io.Path;
import tape.Dependency;
import semver.SemVer;

using tink.CoreApi;

class Install extends Command {

    public static function run() {
        
    }

    public function runDefault()
        install().handle(report);

}