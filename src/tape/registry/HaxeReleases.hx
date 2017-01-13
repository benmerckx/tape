package tape.registry;

import tink.http.Request;
import tink.url.Host;
import semver.SemVer;
import tink.http.Client;
import tink.http.Header;
import tape.Manifest;
import tink.streams.Stream;
import tape.registry.Registry;
import tink.io.IdealSource;

using tink.CoreApi;

class HaxeReleases implements RegistryBase {

    public static var DOWNLOAD_URL = 'https://haxe.org/website-content/downloads/';
    public static var instance(default, null): Registry = new HaxeReleases();
    public static var host = new Host('haxe.org', 443);

    var http: Client;

    function new()
        http = new SecureStdClient();

    public function manifest(name: String, version: SemVer): Promise<Manifest>
        return new Manifest('haxe', version, '$DOWNLOAD_URL$version/');

    public function versions(name): Stream<SemVer> {
        if (name != 'haxe') 
            return Stream.failure(TapeError.create('Only for haxe releases'));
        return (Future.lazy(fetchVersions): Promise<Stream<SemVer>>); 
    }
    
    function fetchVersions(): Stream<SemVer> {
        var request = new OutgoingRequest(
            new OutgoingRequestHeader(
                GET, host, '/download/list/',
                [
                    new HeaderField('connection', 'close'), 
                    new HeaderField('content-length', '0')
                ]
            ), Empty.instance
        );
        return http.request(request).flatMap(function (response) {
            return response.body.all().map(function(res) return switch res {
                case Success(bytes):
                    if (response.header.statusCode != 200)
                        return Failure(TapeError.create(response.header.statusCode, 
                            'Failed to get haxe release versions'//+bytes.toString()
                        ));
                    Error.catchExceptions(function() {
                        var buf = bytes.toString();
                        var test: EReg = ~/\/download\/version\/(.*)\//i;
                        var set: Map<String, SemVer> = new Map();
                        while (test.match(buf)) {
                            var key = test.matched(1);
                            set.set(key, (key: SemVer));
                            buf = test.matchedRight();
                        }
                        return [for (version in set) version];
                    }, function (e) return TapeError.create('$e'));
                default:
                    Failure(TapeError.create('Could not read response body ${response.header}'));
            });
        }).map(function(res) return switch res {
            case Success(versions):
                versions.sort(SemVer.compare);
                versions.reverse();
                Success(Stream.ofIterator(versions.iterator()));
            case Failure(e): 
                Failure(e);
        });
    }

}