package tape;

import tink.http.Client;
import tape.config.HaxelibConfig;
import tape.registry.Haxelib;
import asys.io.File;
import haxe.io.Path;
import tink.http.Request;
import tink.http.Response;
import tink.runloop.Worker;
import tink.concurrent.Queue;
import tink.http.Header;
import haxe.zip.Reader;
import asys.io.FileInput;
import tape.registry.Local;

using tink.CoreApi;

typedef DownloaderData = {
    reporter: Reporter,
    worker: Worker
}

@:forward
abstract Downloader(DownloaderData) from DownloaderData {

    public function download(queue: Queue<Manifest>, path: String): Promise<Noise> {

        function next(?_): Promise<Noise> {
            var job = queue.pop();
            if (job == null) {
                this.reporter.report({description: 'Done'});
                return Noise;
            }
            return switch job.location {
                case Some(location):
                    var dir = Path.join([path, job.name, job.version]);
                    location.install(job.key(), dir, this.reporter)
                    .next(next);
                case None:
                    next();
                    //TapeError.create('No location found for "${job.key()}"');
            }
        }

        return Future.flatten(
            tink.RunLoop.current.delegate(function() {
                var trigger = Future.trigger();
                next().handle(function(result)
                    trigger.trigger(result)
                );
                return trigger.asFuture();
            }, this.worker)
        );
    }

}

class Installer {

    var lock: Lock;
    var reporter: Reporter;
    var amount = 4;
    var downloaders: Array<Downloader>;
    var queue = new Queue<Manifest>();

    public function new(lock: Lock, reporter: Reporter) {
        this.lock = lock;
        this.reporter = reporter;
    }

    public function install(): Promise<Noise> {
        var all = [];
        for (manifest in lock.allDependencies())
            // We don't need to download if available locally
            all.push(
                (Local.instance.manifest(manifest.name, manifest.version): Surprise<Manifest, Error>)
                .map(function(res) return switch res {
                    case Failure(e): 
                        queue.add(manifest);
                        true;
                    default: false;
                })
            );
        return Future.ofMany(all).flatMap(function(todo) {
            var max = todo.filter(function(item) return item).length;
            if (max > amount) max = amount;
            downloaders = [
                for (i in 0 ... max)
                    {
                        reporter: reporter.task('Fetching'), 
                        worker: tink.RunLoop.current.createSlave()
                    }
            ];
            return download().next(function (results) {
                for (res in results) switch res {
                    case Success(_):
                    case Failure(e): return e;
                }
                return Noise;
            });
        });
    }

    function download() {
        return HaxelibConfig.getGlobalRepositoryPath()
        .next(function (path) return Future.ofMany([
            for (downloader in downloaders)
                downloader.download(queue, path)
        ]));
    }

}