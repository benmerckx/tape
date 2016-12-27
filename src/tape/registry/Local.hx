package tape.registry;

import tape.registry.Registry;
import haxe.io.Path;
import asys.FileSystem;
import semver.SemVer;
import tink.streams.Stream;
import tape.config.HaxelibConfig;
import tape.registry.Haxelib;
import tink.Url;
import tape.Location;

using tink.CoreApi;
using StringTools;

class Local implements RegistryBase {

    public static var instance(default, null): Registry = new Local();

    function new() {}

    public function manifest(name: String, version: SemVer): Promise<Manifest> {
        var local: String;
        var proper: String;
        var deprecated: String;
        return HaxelibConfig.getGlobalRepositoryPath()
            .next(function(dir) {
                var main = Path.join([dir, name]);
                return Future.ofMany([
                    FileSystem.exists(proper = Path.join([main, version])),
                    FileSystem.exists(deprecated = Path.join([main, version.toString().replace('.', ',')]))
                ]);
            }).next(function(exists: Array<Bool>)
                return switch [exists[0], exists[1]] {
                    case [true, _]: proper;
                    case [_, true]: deprecated;
                    default: TapeError.create('No local manifest found');
                }
            ).next(function(path: String)
                return Manifest.fromFile(Path.join([
                    path, Manifest.FILE
                ]))
            )
            .next(function(manifest) {
                switch manifest.location {
                    case None: manifest.location = 
                        Some({type: Remote, url: Url.parse(Haxelib.downloadUrl(manifest.name, manifest.version))});
                    default:
                }
                return manifest;
            });
    }

    public function versions(name): Stream<SemVer>
        return (HaxelibConfig.getGlobalRepositoryPath()
            .next(function(dir)
                return FileSystem.readDirectory(Path.join([dir, name]))
            ).next(function(directories) {
                var versions: Array<SemVer> = [];
                for (dir in directories)
                    try versions.push(dir.replace(',', '.'))
                    catch(e: Dynamic) {}
                versions.sort(SemVer.compare);
                versions.reverse();
                return (versions.iterator(): Stream<SemVer>);
            })
            .recover(function(e: Error)
                return Future.sync(([].iterator(): Stream<SemVer>))
            ): Promise<Stream<SemVer>>);

}