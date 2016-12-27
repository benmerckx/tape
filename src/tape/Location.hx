package tape;

import tink.Url;
import tape.fetcher.*;
import tink.streams.Stream;
import tink.streams.StreamStep;
import asys.io.File;
import asys.FileSystem;
import haxe.io.Path;
import haxe.io.Bytes;
import semver.SemVer;

using tink.CoreApi;
using StringTools;

@:enum
abstract LocationType(String) to String {
    var Git = 'git:';
    var Local = 'file:';
    var Remote = '';
}

typedef LocationData = {
    type: LocationType,
    url: Url
}

typedef FileData = {
    name: String,
    body: Bytes
}

typedef FetchContext = {
    reporter: Reporter,
    dir: String,
    name: String,
    version: Option<SemVer>
}

@:forward
abstract Location(LocationData) from LocationData {

    @:from
    static function fromString(str: String): Location
        return if (str.startsWith(Git))
            {type: Git, url: Url.parse(str.substr((Git: String).length))}
        else if (str.startsWith(Local))
            {type: Local, url: Url.parse(str.substr((Local: String).length))}
        else if (str.startsWith('http'))
            {type: Remote, url: Url.parse(str)}
        else
            throw TapeError.create('No location found in "$str"');

    public function install(ctx: FetchContext): Promise<String> {
        var failure: Error;
        var path: String;
        return (switch this.type {
            case Remote:
               switch ctx.version {
                    case Some(v):
                        path = Path.join([ctx.dir, ctx.name, v]);
                        FileSystem.createDirectory(path)
                        .map(function(_) 
                            return Success(new UrlFetcher(this.url).fetch(ctx))
                        );
                    case None:
                        // This should be unreachable
                        Stream.failure(TapeError.create('No version for "${ctx.name}"'));
                }
            case Local:
                function() return Future.sync(End);
            case Git:
                var fetcher = new GitFetcher(this.url);
                fetcher.fetch(ctx)
                .next(function(commit) {
                    this.url = this.url.resolve('#'+commit);
                    path = Path.join([ctx.dir, ctx.name, GitFetcher.DIR_PREFIX+commit]);
                    return fetcher.files();
                });
        }: Stream<FileData>)
        .forEachAsync(function(file) {
            var path = Path.join([path, file.name]);
            var isFile = !file.name.endsWith('/') && file.body != null;
            var dir = if (isFile) Path.directory(path) else path;
            return (FileSystem.exists(dir): Promise<Bool>)
            .next(function(exists): Promise<Noise>
                return if (!exists) {
                    ctx.reporter.report({description: '$dir'});
                    FileSystem.createDirectory(dir);
                } else Noise
            )
            .next(function(_): Promise<Bool>
                return if (isFile) {
                    // Put the location in the final manifest, because we might need it later
                    if (file.name.endsWith(Manifest.FILE))
                        switch Manifest.fromJsonSchema(Json.parse(file.body.toString())) {
                            case Success(manifest):
                                manifest.location = Some(this);
                                var body = Json.stringify(manifest.toJson());
                                file.body = haxe.io.Bytes.ofString(body);
                            case Failure(e):
                        }
                    File.saveBytes(path, file.body).map(function (res) return switch res {
                        case Success(_): true;
                        case Failure(e): 
                            failure = TapeError.create('Failed to create file "$path"', e);
                            false;
                    });
                } else {
                    true;
                }
            )
            .recover(function(e: Error) {
                failure = e;
                return Future.sync(false);
            });
        }).map(function(res) return switch res {
            case Success(success): 
                if (success) Success(path);
                else Failure(TapeError.create('Could not write files to "$path"', failure));
            case Failure(e): Failure(e);
        });
    }

    @:to
    public function toString()
        return '${this.type}${this.url}';

}