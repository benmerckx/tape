package tape.registry;

import semver.SemVer;
import tink.streams.Stream;

using tink.CoreApi;

interface Registry {
    function fetchVersions(name: String): Stream<SemVer>;
    function fetchManifest(name: String, version: SemVer): Promise<Manifest>;
}