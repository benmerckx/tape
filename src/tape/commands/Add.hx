package tape.commands;

import tape.Manifest;
import haxe.io.Path;
import tape.Dependency;
import semver.SemVer;

using tink.CoreApi;

class Add extends Command {

    public static function run(lib: String, source: Option<Source>) {
        var manifest: Manifest, version: SemVer, lock: Lock;
        return Manifest.fromFile(Manifest.FILE, Path.directory(Sys.getCwd()))
        .next(function (res) {
            manifest = res;
            return (Lock.fromFile(Lock.FILE, manifest): Surprise<Lock, Error>).map(
                function(res) return switch res {
                    case Success(v): Some(v);
                    case Failure(e): None;
                }
            );
        })
        .next(function(res) {
            manifest.addDependency(new Dependency(lib, switch source {
                case None: '*';
                case Some(v): v;
            }));
            return manifest.lock(Reporter.create('Creating lock'), res);
        })
        .next(function (res) {
            lock = res;
            version = lock.dependencies.get(lib).version;
            switch source {
                case None:
                    for (dep in manifest.dependencies) {
                        if (dep.name == lib)
                            dep.source = '^$version';
                    }
                default:
            }
            return Future.ofMany([manifest.write(), lock.write()]);
        })
        .next(function(_)
            return lock.install(Reporter.create('Installing dependencies'))
        )
        .next(function (_) 
            return 'Added "$lib@$version"'
        );
    }

    public function runDefault(lib: String, ?source: Option<Source>)
        run(lib, source).handle(report);

}