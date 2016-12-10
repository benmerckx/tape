package tape;

import semver.SemVer;

using tink.CoreApi;

interface Registry {
    function fetchVersions(name: String): Promise<Array<SemVer>>;
    function fetchManifest(name: String, version: SemVer): Promise<Manifest>;
}