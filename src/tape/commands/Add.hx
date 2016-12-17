package tape.commands;

import mcli.CommandLine;
import tape.Manifest;
import haxe.io.Path;
import tape.Dependency;
import semver.SemVer;

using tink.CoreApi;

class Add extends CommandLine {

    public function runDefault(lib: String, ?source: Option<Source>) {
        var manifest: Manifest, version: SemVer;
        Manifest.fromFile(Manifest.FILE, Path.directory(Sys.getCwd()))
        .next(function (res) {
            manifest = res;
            manifest.addDependency(new Dependency(lib, switch source {
                case None: '*';
                case Some(v): v;
            }));
            return manifest.lock(Reporter.create('Creating lock'));
        })
        .next(function (lock) {
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
        .handle(function (res) switch res {
            case Success(_): Reporter.success('Added "$lib@$version"');
            case Failure(e): Reporter.fail(e);
        });
    }

}