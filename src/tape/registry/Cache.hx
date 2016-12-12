package tape.registry;

import tink.streams.Stream;
import tink.streams.StreamStep;
import semver.SemVer;
import tape.registry.Registry;

using tink.CoreApi;

class Cache implements RegistryBase {

    var registry: Registry;
    var cache = {
        manifest: new Map<String, Manifest>(),
        versions: new Map<String, Array<SemVer>>()
    }

    public function new(registry: Registry)
        this.registry = registry;

    public function manifest(name: String, version: SemVer): Promise<Manifest> {
        var key = '$name@$version';
        if (cache.manifest.exists(key))
            return cache.manifest.get(key);
        return (registry.manifest(name, version): Surprise<Manifest, Error>)
            .map(function(res) return switch res {
                case Success(manifest):
                    cache.manifest.set(key, manifest);
                    Success(manifest);
                default: res;
            });
    }

    public function versions(name): Stream<SemVer> {
        if (cache.versions.exists(name))
            return cache.versions.get(name).iterator();
        var cached = [], versions = registry.versions(name);
        return function() {
            return versions.next().map(function(step) return switch step {
                case Data(version):
                    cached.push(version);
                    Data(version);
                case End:
                    cache.versions.set(name, cached);
                    End;
                default: step;
            });
        }
    }

}