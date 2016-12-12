package tape.registry;

import tape.registry.Registry;
import haxe.io.Path;
import asys.FileSystem;
import semver.SemVer;
import tink.streams.Stream;
import asys.io.File;

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

class HaxelibConfig {

    static var REPNAME = "lib";
    static var IS_WINDOWS = Sys.systemName() == "Windows";

    public static function getConfigFile(): Promise<String> {
        inline function fail()
            return Failure(TapeError.create(
                'Could not determine home path. Please ensure that USERPROFILE or HOMEDRIVE+HOMEPATH environment variables are set.'
            ));
		inline function done(str)
            return File.getContent(Path.join([str, '.haxelib']));
        return if (IS_WINDOWS)
            switch Sys.getEnv("USERPROFILE") {
                case null: switch [Sys.getEnv("HOMEDRIVE"), Sys.getEnv("HOMEPATH")] {
                    case [drive, path] if (drive != null && path != null):
                        done(drive + path);
                    default: fail();
                }
                case profile: done(profile);
            }
        else switch Sys.getEnv("HOME") {
            case null: 
                Failure(TapeError.create('Could not determine home path. Please ensure that HOME environment variable is set.'));
            case v: done(v);
        }
    }

    public static function getGlobalRepositoryPath(): Promise<String>
		return switch Sys.getEnv("HAXELIB_PATH") {
            case null: (getConfigFile(): Surprise<String, Error>)
                .flatMap(function(res): Promise<String> return switch res {
                    case Success(file): file;
                    case Failure(e) if (IS_WINDOWS):
                        switch Sys.getEnv("HAXEPATH") {
                            case null: TapeError.create('HAXEPATH environment variable not defined, please run haxesetup.exe first', e);
                            case haxepath: Path.addTrailingSlash(haxepath.trim()) + REPNAME;
                        }
                    case Failure(e):
                        File.getContent("/etc/.haxelib");
                });
            case rep: return rep.trim();
        }

}