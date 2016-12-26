package tape;

import semver.SemVer;
import tape.Source;
import tink.streams.Stream;
import tink.streams.StreamStep;
import tape.registry.Cache;

using tink.CoreApi;

typedef DependencyData = {
    name: String,
    source: Source
}

@:forward
abstract Dependency(DependencyData) from DependencyData {

    public function new(name: String, source: Source)
        return {
            name: name,
            source: source
        };

    public function candidates(lock: Option<Lock>): Stream<Manifest>
        return switch this.source {
            case Versioned(range, registry):
                registry = switch lock {
                    case Some(lock): Cache.fromLock(lock, registry);
                    case None: registry;
                }
                // The analyzer somehow fails if this.name is used in the closure
                var name = this.name;
                var versions = registry.versions(name)
                    .filter(function(version)
                        return range.satisfies(version)
                    );
                return function()
                    return 
                        versions.next()
                        .flatMap(function(step) return switch step {
                            case Data(version):
                                (registry
                                .manifest(name, version): Surprise<Manifest, Error>)
                                .map(function(res) return switch res {
                                    case Success(manifest): Data(manifest);
                                    case Failure(e): Fail(e);
                                });
                            case End: Future.sync(End);
                            case Fail(e): Future.sync(Fail(e));
                        });
            case Pinned(type, url): 
                throw 'todo';
        }

    @:to
    public function toString()
        return this.name+'@'+this.source;

}