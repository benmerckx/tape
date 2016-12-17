package tape.registry;

import tink.streams.Stream;
import tink.streams.StreamStep;
import semver.SemVer;
import tape.registry.Registry;
import tink.streams.Accumulator;

using tink.CoreApi;

typedef StreamCache<T> = {
    buffered: Array<Future<StreamStep<T>>>,
    original: Stream<T>
}

class Cache implements RegistryBase {

    var registry: Registry;
    var cache = {
        manifest: new Map<String, Promise<Manifest>>(),
        versions: new Map<String, StreamCache<SemVer>>()
    }

    public function new(registry: Registry)
        this.registry = registry;

    public function manifest(name: String, version: SemVer): Promise<Manifest> {
        var key = '$name@$version';
        if (!cache.manifest.exists(key))
            cache.manifest.set(key, registry.manifest(name, version));
        return cache.manifest.get(key);
    }

    function versionCache(name) {
        if (!cache.versions.exists(name)) 
            cache.versions.set(name, {buffered: [], original: registry.versions(name)});
        return cache.versions.get(name);
    }

    public function versions(name): Stream<SemVer> {
        var cached = versionCache(name);
        var progressed = 0;
        return function() {
            if (cached.buffered.length == progressed)
                cached.buffered.push(cached.original.next());
            return cached.buffered[progressed++];
        }
    }

    public static function fromLock(lock: Lock, registry: Registry) {
        var cached = new Cache(registry);
        function addToVersions(manifest: Manifest) {
            var cache = cached.versionCache(manifest.name);
            cache.buffered.push(Future.sync(Data(manifest.version)));
        }
        function fill(dependencies: Map<String, Manifest>)
            for (manifest in dependencies) {
                cached.cache.manifest.set(manifest.key(), manifest);
                addToVersions(manifest);
            }
        fill(lock.dependencies);
        for (reel in lock.reels) fill(reel);
        return cached;
    }

}