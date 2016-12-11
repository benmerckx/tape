package tape.registry;

import haxe.Serializer;
import haxe.Unserializer;
import tink.http.Request;
import tink.http.Header;
import tink.url.Host;
import semver.SemVer;
import tink.http.Client;
import tape.Manifest;
import tink.streams.Stream;

using tink.CoreApi;

class Haxelib implements Registry {

    public static var instance(default, null): Haxelib = new Haxelib();
    static var host = new Host('lib.haxe.org', 443);

    var http: Client;

    function new()
        http = new SecureStdClient();

    public function fetchManifest(name: String, version: SemVer): Promise<Manifest> {
        var request = new OutgoingRequest(
            new OutgoingRequestHeader(
                GET, host, 
                '/p/$name/$version/raw-files/haxelib.json'
            ), ''
        ); 
        return http.request(request).flatMap(function (response) {
            // This library doesn't contain a haxelib.json file, not at the root anyway
            // Should be okay as the examples I've seen don't list any dependencies (eg. hxcpp)
            if (response.header.statusCode == 404)
                return Future.sync(Success(new Manifest(name, version)));
            if (response.header.statusCode != 200)
                return Future.sync(Failure(new Error('Could not load manifest')));
            return response.body.all().map(function(res) return switch res {
                case Success(bytes):
                    var data: JsonSchema;
                    try
                        data = haxe.Json.parse(bytes.toString())
                    catch (e: Dynamic)
                        return Failure(new Error('Could not parse manifest body'));
                    return Manifest.fromJsonSchema(data);
                default:
                    Failure(new Error('Could not read response body'));
            });
        });
    }

    public function fetchVersions(name): Stream<SemVer> {
        var packer = new Serializer();
		packer.serialize(['api', 'infos']);
		packer.serialize([name]);
        var request = new OutgoingRequest(
            new OutgoingRequestHeader(
                GET, host, '/api/3.0/index.n?__x=$packer', 
                [new HeaderField('x-haxe-remoting', '1')]
            ), ''
        );
        return http.request(request).flatMap(function (response) {
            if (response.header.statusCode != 200)
                return Future.sync(Failure(new Error('Could not load versions')));
            return response.body.all().map(function(res) return switch res {
                case Success(bytes):
                    Error.catchExceptions(function() {
                        var buf = bytes.toString();
                        if (buf.substr(0, 3) != 'hxr')
                            throw 'Invalid response';
                        var unpacker = new Unserializer(buf.substr(3));
                        var data: {versions: Array<{name: String}>} = unpacker.unserialize();
                        return [
                            for (release in data.versions)
                                (release.name: SemVer)
                        ];
                    });
                default:
                    Failure(new Error('Could not read response body'));
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