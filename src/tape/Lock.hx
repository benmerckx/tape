package tape;

import tink.streams.Stream;

enum Progress {
    Failed;
    Progressed;
    Done;
}

class Lock {

    var manifest: Manifest;

    public function new(manifest: Manifest) {
        this.manifest = manifest;
    }

    public function resolve(): Stream<Progress> {
        return null;
    }

}