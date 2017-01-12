package tape;

import asys.io.File;
import haxe.DynamicAccess;
import tape.Manifest;

using tink.CoreApi;

typedef LockData = {
    manifest: Manifest,
    dependencies: Reel,
    reels: Map<String, Reel>
}

@:forward
abstract Lock(LockData) from LockData {

    public static var FILE = 'haxelib.lock';

    public function new(manifest: Manifest)
        this = {
            manifest: manifest,
            dependencies: new Reel(),
            reels: new Map()
        }

    public function write(): Promise<Noise>
        return File.saveContent(FILE, tape.Json.stringify(toJson()));

    public function install(reporter: Reporter): Promise<Noise>
        return new Installer(this, reporter).install();

    public function allDependencies(): Array<Manifest>
        return this.dependencies.manifests().concat(
            Lambda.fold(this.reels, function(reel: Reel, prev: Array<Manifest>) 
                return prev.concat(reel.manifests()), []
        ));

    function dependenciesJson(dependencies: Reel)
        return [for (manifest in dependencies)
            manifest.name => {
                var rep = manifest.toJson(false);
                rep.remove('name');
                rep;
            }
        ];

    function toJson()
        return {
            manifest: this.manifest.hash(),
            dependencies: dependenciesJson(this.dependencies),
            reels: [
                for (reel in this.reels.keys())
                    reel => dependenciesJson(this.reels.get(reel))
            ]
        }

    public static function fromJson(data: DynamicAccess<Any>, from: Manifest): Outcome<Lock, Error> {
        function extract(input: DynamicAccess<JsonSchema>)
            return [
                for (key in input.keys()) 
                    key => Manifest.fromJsonSchema(input.get(key), key).sure()
            ];
        for (field in ['manifest', 'dependencies', 'reels'])
            if (!data.exists('manifest')) 
                return Failure(TapeError.create('Field "$field" is missing'));
        if (from.hash() != data.get('manifest'))
            return Failure(TapeError.create('Lock file is outdated'));
        var lock = new Lock(from);
        lock.dependencies = extract(data.get('dependencies'));
        var reels: DynamicAccess<DynamicAccess<JsonSchema>> = data.get('reels');
        lock.reels = [
            for(reel in reels.keys())
                reel => extract(reels.get(reel))
        ];
        return Success(lock);
    }

    public static function fromFile(path: String, from: Manifest): Promise<Lock>
        return File.getContent(path).map(function(res) return switch res {
            case Success(data):
                try
                    fromJson(haxe.Json.parse(data), from)
                catch (e: Dynamic)
                    Failure(TapeError.create('Could not parse lock file "$path"', TapeError.create('$e')));
            case Failure(e): Failure(e);
        });

    @:to
    public function toString()
        return 
        if (this == null) 'null'
        else
            [for (manifest in this.dependencies) '$manifest']
            .concat([for (reel in this.reels)
                for (manifest in reel) '$manifest'
            ]).join('\n');

}