package tape.commands;

import tape.Manifest;
import haxe.io.Path;

using tink.CoreApi;

class Install extends Command {

    public static function run()
        return getLock()
        .next(install)
        .next(function (_) 
            return 'Done'
        );

    static function getLock(): Promise<Lock>
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
        });
    
    static function install(lock: Lock)
        return lock.install(Reporter.create('Installing dependencies'));

    public function runDefault()
        run().handle(report);

}