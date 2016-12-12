package tape.registry;

import semver.SemVer;
import tink.streams.Stream;

using tink.CoreApi;

interface RegistryBase {
    function versions(name: String): Stream<SemVer>;
    function manifest(name: String, version: SemVer): Promise<Manifest>;
}

@:forward
abstract Registry(RegistryBase) from RegistryBase {

    inline public function concat(registry: Registry) {
        if (Std.is(this, ConcatRegistry)) {
            (cast this: ConcatRegistry).parts.push(registry);
            return this;
        }
        return new ConcatRegistry([this, registry]);
    }

}

class ConcatRegistry implements RegistryBase {

    @:allow(tape.registry.Registry)
    var parts: Array<Registry>;

    public function new(parts)
        this.parts = parts;

    public function versions(name: String): Stream<SemVer>
        return ConcatStream.make([
            for (part in parts)
                part.versions(name)
        ]);

    public function manifest(name: String, version: SemVer): Promise<Manifest>
        return Future.async(function(done) {
            var remaining = parts.copy();
            function next() {
                if (remaining.length == 0)
                    return done(Failure(TapeError.create('Could not find version for "$name"')));
                remaining.shift()
                .manifest(name, version)
                .handle(function (res) switch res {
                    case Success(manifest): done(Success(manifest));
                    case Failure(e): next();
                });
            }
            next();
        });
}