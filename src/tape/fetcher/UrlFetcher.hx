package tape.fetcher;

import tink.Url;
import tink.streams.Stream;
import tink.streams.StreamStep;
import tape.Location;
import tink.http.Client;
import haxe.io.Path;
import asys.io.File;
import tink.http.Request;
import tink.http.Response;
import tink.url.Host;
import tink.http.Header;
import asys.io.FileInput;
import haxe.zip.Reader;
import haxe.zip.Entry;
import asys.FileSystem;
import tape.registry.HaxeReleases;

using tink.CoreApi;
using Lambda;
using StringTools;

class UrlFetcher {

    var url: Url;
    var http: Client;

    public function new(url) {
        this.url = url;
        http = new SecureTcpClient(false);
    }

    public function fetch(ctx: FetchContext): Stream<FileData> {
        var path: String;
        switch ctx.version {
            case Some(version): 
                path = Path.join([ctx.dir, ctx.name, version]);
                if (url.toString().startsWith(HaxeReleases.DOWNLOAD_URL))
                    url = url.resolve('downloads/haxe-$version-win.zip');
            case None: return Stream.failure(TapeError.create('No version for "${ctx.name}"'));
        }
        var archive = Path.join([path, 'download.tmp']);
        ctx.reporter.report({description: 'Downloading "${ctx.name}"'});
        return download(archive).next(function(_): Stream<FileData> {
            return (File.read(archive): Promise<FileInput>)
            .next(function(file): Stream<FileData> {
                ctx.reporter.report({description: 'Installing "${ctx.name}"'});
                var entries;
                try entries = Reader.readZip(file)
                catch (e: Dynamic)
                    return TapeError.create('Could not unzip "$archive"', TapeError.create('$e'));
                entries = normalize(entries);
                return Stream.generate(function () {
                    var entry = entries.pop();
                    return if (entry == null) {
                        file.close();
                        FileSystem.deleteFile(archive)
                        .map(function(res) return switch res {
                            case Success(_): End;
                            case Failure(e): 
                                Fail(TapeError.create('Could not remove temporary file "$archive"', e));
                        });
                    } else {
                        Future.sync(Data(({
                            name: entry.fileName, 
                            body: Reader.unzip(entry)
                        }: FileData)));
                    }
                });
            });
        });
    }

    function normalize(entries: List<Entry>): List<Entry> {
        var location = 
            entries.filter(function(entry) return entry.fileName.endsWith(Manifest.FILE))
            .map(function(entry) return Path.normalize(entry.fileName))
            .fold(function(path: String, prev: String)
                return if (prev == null) path
                else if (path.split('/').length > prev.split('/').length) prev
                else path
            , null);
        if (location == null) 
            return entries;
        var base = 
            Path.addTrailingSlash(location.substr(0, location.length - Manifest.FILE.length));
        return
            if (base != '/' && base.split('/').length > 1)
                entries
                .filter(function(entry)
                    return entry.fileName.startsWith(base) && entry.fileName != base
                )
                .map(function (entry) {
                    entry.fileName = entry.fileName.substr(base.length);
                    return entry;
                });
            else
                entries;
    }

    function outgoing(url: Url) {
        var host = if (url.host == null) this.url.host else url.host;
        return new OutgoingRequest(
            new OutgoingRequestHeader(GET, new Host(host.name, 443), url.path,
                [
                    new HeaderField('connection', 'close'),
                    new HeaderField('content-length', '0')
                ]
            ), ''
        );
    }

    function download(zip): Promise<Noise> {
        var file = File.writeStream(zip);
        function response(res: IncomingResponse): Promise<Noise> {
            if (res.header.statusCode == 301 || res.header.statusCode == 302) {
                var location = res.header.byName('location').sure();
                return http
                    .request(outgoing('$location'))
                    .flatMap(response);
            }
            if (res.header.statusCode != 200)
                return res.body.all().map(function(errorRes) 
                    return Failure(
                        TapeError.create(res.header.statusCode, 
                            'Could not download [$url]',
                            switch errorRes {
                                case Success(body): TapeError.create(res.header+'$body');
                                case Failure(e): e;
                            }
                        )
                    )
                );
            return res.body.pipeTo(file).flatMap(function (res): Promise<Noise> return switch res {
                case AllWritten: 
                    file.close();
                    return Noise;
                case SinkFailed(e): TapeError.create('Could not write to file', e);
                case SinkEnded: TapeError.create('Could not write to file');
                case SourceFailed(e): TapeError.create('Download interrupted', e);
            });
        }
        return http
            .request(outgoing(url))
            .flatMap(response);
    }

}