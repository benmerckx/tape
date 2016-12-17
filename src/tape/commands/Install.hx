package tape.commands;

import tape.Manifest;
import haxe.io.Path;
import tape.Dependency;
import semver.SemVer;

using tink.CoreApi;

class Install extends Command {

    public static function run() {
        return Manifest.fromFile(Manifest.FILE, Path.directory(Sys.getCwd()))
        .next(function (manifest) {
            return (Lock.fromFile(Lock.FILE, manifest): Surprise<Lock, Error>).flatMap(
                function(res) return switch res {
                    case Success(v): Future.sync(Success(v));
                    case Failure(e): 
                        var lock: Lock;
                        manifest.lock(Reporter.create('Creating lock'), None)
                        .next(function(res) return (lock = res).write())
                        .next(function(_) return lock);
                }
            );
        })
        .next(function(lock)
            return lock.install(Reporter.create('Installing dependencies'))
        )
        .next(function (_) 
            return 'Done'
        );
    }

    public function runDefault()
        run().handle(report);

}