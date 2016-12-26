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

using tink.CoreApi;

typedef DownloaderData = {
    reporter: Reporter,
    worker: Worker
}

@:forward
abstract Downloader(DownloaderData) from DownloaderData {

    function install(manifest: Manifest, path: String, next: Void -> Promise<Noise>): Promise<Noise> {
        return Noise;/*
        this.reporter.report({description: 'Installing "${manifest.key()}"'});
        return (File.read(path): Promise<FileInput>)
        .next(function(file): Promise<Noise> {
            var entries;
            try entries = Reader.readZip(file)
            catch (e: Dynamic)
                return TapeError.create('Could not unzip "${manifest.key()}"', TapeError.create('$e'));
            function unzip(): Promise<Noise> {
                var entry = entries.pop();
                if (entry == null) return Noise;
                this.reporter.report({description: 'Unzipping "${entry.fileName}"'});
                return File.saveBytes(_, Reader.unzip(entry)).flatMap(function (res) return switch res {
                    case Success(_): unzip();
                    case Failure(e): Future.sync(Failure(TapeError.create('Could not unzip "${entry.fileName}"', e)));
                });
            }
            return unzip();
        });*/
    }

    public function download(queue: Queue<Manifest>, http: Client, path: String): Promise<Noise> {
        function outgoing(url: String) 
            return new OutgoingRequest(
                new OutgoingRequestHeader(GET, Haxelib.host, url,
                    [
                        new HeaderField('connection', 'close'), 
                        new HeaderField('content-length', '0')
                    ]
                ), ''
            );

        function next(): Promise<Noise> {
            var job = queue.pop();
            if (job == null) {
                this.reporter.report({description: 'Idle'});
                return Noise;
            }
            this.reporter.report({description: 'Downloading "${job.key()}"'});
            var zip = Path.join([path, '${job.key()}.zip']);
            var file = File.writeStream(zip);
            function response(res: IncomingResponse): Promise<Noise> {
                if (res.header.statusCode == 301) {
                    var location = res.header.byName('location').sure();
                    return http
                        .request(outgoing('$location'))
                        .flatMap(response);
                }
                if (res.header.statusCode != 200)
                    return res.body.all().map(function(errorRes) 
                        return Failure(
                            TapeError.create(res.header.statusCode, 
                                'Could not download "${job.name}@${job.version}" [${res.header.statusCode}]',
                                switch errorRes {
                                    case Success(body): TapeError.create(res.header+'$body');
                                    case Failure(e): e;
                                }
                            )
                        )
                    );
                return res.body.pipeTo(file).flatMap(function (res): Promise<Noise> return switch res {
                    case AllWritten: return next(); //return install(job, zip, next);
                    case SinkFailed(e): TapeError.create('Could not write to file', e);
                    case SinkEnded: TapeError.create('Could not write to file');
                    case SourceFailed(e): TapeError.create('Download interrupted', e);
                });
            }

            return http
                .request(outgoing('/p/${job.name}/${job.version}/download/'))
                .flatMap(response);
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

    var amount = 5;
    var lock: Lock;
    var downloaders: Array<Downloader>;
    var queue = new Queue<Manifest>();

    public function new(lock: Lock, reporter: Reporter) {
        this.lock = lock;
        downloaders = [
            for (i in 0 ... amount)
                {
                    reporter: reporter.task('Fetching'), 
                    worker: tink.RunLoop.current.createSlave()
                }
        ];
    }

    public function install(): Promise<Noise> {
        for (manifest in lock.allDependencies())
            queue.add(manifest);
        return download().next(function (results) {
            for (res in results) switch res {
                case Success(_):
                case Failure(e): return e;
            }
            return Noise;
        });
    }

    function download() {
        return HaxelibConfig.getGlobalRepositoryPath()
        .next(function (path) return Future.ofMany([
            for (downloader in downloaders)
                downloader.download(queue, new SecureTcpClient(false), path)
        ]));
    }

}