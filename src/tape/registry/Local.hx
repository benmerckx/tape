package tape.registry;

import tape.registry.Registry;
import haxe.io.Path;
import asys.FileSystem;
import semver.SemVer;
import tink.streams.Stream;
import tape.config.HaxelibConfig;

using tink.CoreApi;
using StringTools;

class Local implements RegistryBase {

    public static var instance(default, null): Registry = new Local();

    function new() {}

    public function manifest(name: String, version: SemVer): Promise<Manifest> {
        return HaxelibConfig.getGlobalRepositoryPath()
            .next(function(dir) {
                return Manifest.fromFile(Path.join([
                    dir, name, version.toString().replace('.', ','), 'haxelib.json'
                ]));
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