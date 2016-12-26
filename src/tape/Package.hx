package tape;

import tink.Url;

using tink.CoreApi;

interface Package {
    var manifest(default, null): Manifest;
    function install(reporter: Reporter): Promise<Noise>;
    function resolved(): Option<String>;
}

class LocalPackage implements Package {

    public var manifest(default, null): Manifest;

    public function new(manifest: Manifest)
        this.manifest = manifest;

    public function install(reporter: Reporter): Promise<Noise>
        return Noise;

    public function resolved()
        return None;

}

class RemotePackage implements Package {

    public var manifest(default, null): Manifest;
    var url: Url;

    public function new(manifest: Manifest, url: Url) {
        this.manifest = manifest;
        this.url = url;
    }

    public function install(reporter: Reporter): Promise<Noise> {
        return Noise;
    }

    public function resolved()
        return Some(url.toString());

}