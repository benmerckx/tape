package tape;

import tink.Url;
import tape.fetcher.*;
import tink.streams.Stream;
import tink.streams.StreamStep;
import asys.io.File;
import asys.FileSystem;
import haxe.io.Path;
import haxe.io.Bytes;

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

    public function install(name: String, path: String, reporter: Reporter): Promise<Noise> {
        var fetcher = fetch;
        return FileSystem.exists(path).flatMap(function(exists) 
            return if (!exists) 
                (FileSystem.createDirectory(path): Promise<Noise>).next(function(_) return fetcher(name, path, reporter))
            else 
                fetcher(name, path, reporter)
        );
    }

    function fetch(name: String, path: String, reporter: Reporter): Promise<Noise> {
        var failure: Error;
        return (switch this.type {
            case Remote:
                new UrlFetcher(this.url).fetch(name, path, reporter);
            case Local:
                function() return Future.sync(End);
            default:
                Stream.failure(TapeError.create('Todo ${this.url}'));
        }: Stream<FileData>)
        .forEachAsync(function(file) {
            var path = Path.join([path, file.name]);
            var isFile = !file.name.endsWith('/');
            var dir = if (isFile) Path.directory(path) else path;
            return (FileSystem.exists(dir): Promise<Bool>)
            .next(function(exists): Promise<Noise>
                return if (!exists) FileSystem.createDirectory(dir)
                else Noise
            )
            .next(function(_): Promise<Bool>
                return if (isFile)
                    File.saveBytes(path, file.body).map(function (res) return switch res {
                        case Success(_): true;
                        case Failure(e): 
                            failure = e;
                            false;
                    })
                else
                    true
            )
            .recover(function(e: Error) {
                failure = e;
                return Future.sync(false);
            });
        }).map(function(res) return switch res {
            case Success(success): 
                if (success) Success(Noise);
                else Failure(TapeError.create('Could not write files to "$path"', failure));
            case Failure(e): Failure(e);
        });
    }

    @:to
    public function toString()
        return '${this.type}${this.url}';

}