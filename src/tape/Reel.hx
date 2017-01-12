package tape;

import asys.FileSystem;
import asys.io.File;
import haxe.io.Path;

using tink.CoreApi;

@:forward
abstract Reel(Map<String, Manifest>) from Map<String, Manifest> {

    inline public function new()
        this = new Map();

    public function manifests()
        return [for (manifest in this) manifest];

    public function path(): Promise<Array<String>> {
        var dir: String;
        return Future.ofMany([for (manifest in this)
            manifest.localPath()
            .next(function (_)
                return extraOfDir(dir = _)
            )
            .next(function (info: Array<String>)
                return info.concat([
                    Path.join([dir, manifest.classPath]),
                    '-D ${manifest.name}=${manifest.version}'
                ])
            )
        ]).map(function (res) {
            var response = [];
            for (result in res)
                switch result {
                    case Failure(e): return Failure(e);
                    case Success(v):
                        response = response.concat(v);
                }
            return Success(response);
        });
    }
    
    function extraOfDir(dir: String): Future<Array<String>> {
        var trigger = Future.trigger();
        var response = [];
        var ndir = Path.join([dir, 'ndll']);
        FileSystem.exists(ndir).handle(function (exists) {
            if (exists) 
                response.push('-L ${ndir}/');
            File.getContent(Path.join([dir, 'extraParams.hxml']))
            .handle(function (res) trigger.trigger(switch res {
                case Success(data):
                    response.concat(data.split('\n'));
                default:
                    response;
            }));
        });
        return trigger.asFuture();
    }

}