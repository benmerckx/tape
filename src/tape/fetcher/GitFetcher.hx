package tape.fetcher;

import tink.Url;
import tink.streams.Stream;
import tink.streams.StreamStep;
import tape.Location;
import haxe.io.Path;
import sys.io.Process;
import asys.FileSystem;
import asys.io.File;

using tink.CoreApi;
using StringTools;

class GitFetcher {

    public static var DIR_PREFIX = 'git-';

    var url: Url;
    var path: String;

    public function new(url) {
        this.url = url;
    }

    public function fetch(ctx: FetchContext): Promise<String> {
        ctx.reporter.report({description: 'Cloning "${url}"'});
        path = Path.join([ctx.dir, ctx.name, 'git']);
        exec(['clone', url, path]);
        return switch exec(['--git-dir', Path.join([path, '.git']), 'rev-parse', '--short', 'HEAD']) {
            case Success(commit):
                @:privateAccess url.hash = commit;
                commit;
            case Failure(e): e;
        }
    }

    public function files(): Stream<FileData> {
        var todo = ['/'];
        return function(): Future<StreamStep<FileData>> {
            var file = todo.pop();
            if (file == null) return Future.sync(End);
            var location = Path.join([path, file]);
            return FileSystem.isDirectory(location).flatMap(function(isDir) {
                return if (isDir)
                    FileSystem.readDirectory(location).map(function(res) return switch res {
                        case Success(files):
                            todo = todo.concat(
                                files
                                .filter(function(f) return f != '.git')
                                .map(function(f) return Path.join([file, f]))
                            );
                            Data(({name: file, body: null}: FileData));
                        case Failure(e):
                            Fail(e);
                    })
                else
                    File.getBytes(location).map(function(res) return switch res {
                        case Success(bytes):
                            Data(({name: file, body: bytes}: FileData));
                        case Failure(e):
                            Fail(e);
                    });
            });
        }
    }

    function exec(args: Array<String>): Outcome<String, Error> {
        var process = new Process('git', args);
        var out = process.stdout.readAll().toString();
        var err = process.stderr.readAll().toString();
        return if (process.exitCode() == 0) 
            Success(out.trim())
        else
            Failure(TapeError.create(err));
    }

}