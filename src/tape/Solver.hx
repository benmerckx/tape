package tape;

import tape.Source;

using tink.CoreApi;

class Solver {

    var root: Manifest;

    public function new(root: Manifest)
        this.root = root;
    
    public function solve(): Promise<Lock> {
        //var backtrack = [];
        //var remaining = [root];
        for (dep in root.dependencies) {
            switch dep.source {
                case Versioned(_, registry):
                    registry.fetchVersions(dep.name).handle(function(res) switch res {
                        case Success(versions):
                            for (version in versions)
                                registry.fetchManifest(dep.name, version).handle(function (res) switch res {
                                    case Success(manifest):
                                        trace(manifest.dependencies);
                                    case Failure(e):
                                        trace('e: '+e);
                                });
                        default:
                    });
                default:
            }
        }
        return null;
    }

}