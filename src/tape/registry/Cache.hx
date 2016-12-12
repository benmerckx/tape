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
        var cached = [], versions = registry.versions(name);
        if (!cache.versions.exists(name))
            cache.versions.set(name, []);
        return (cache.versions.get(name).iterator(): Stream<SemVer>) ... (
            function() {
                var list = cache.versions.get(name);
                function next()
                    return versions.next().flatMap(function(step) return switch step {
                        case Data(version):
                            if (cached.indexOf(version) > -1) {
                                next();
                            } else {
                                cached.push(version);
                                list.push(version);
                                Future.sync(Data(version));
                            }
                        default: Future.sync(step);
                    });
                return next();
            }
        : Stream<SemVer>);
    }

    public static function fromLock(lock: Lock, registry: Registry) {
        var cached = new Cache(registry);
        inline function fill(dependencies: Map<String, Manifest>)
            for (dependency in dependencies) {
                cached.cache.manifest.set(dependency.key(), dependency);
                cached.cache.manifest.set(dependency.key(), dependency);
            }
        fill(lock.dependencies);
        for (reel in lock.reels) fill(reel);
        return cached;
    }

}