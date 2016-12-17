package tape;

import asys.io.File;

using tink.CoreApi;

typedef Dependencies = Map<String, Manifest>;

typedef LockData = {
    dependencies: Dependencies,
    reels: Map<String, Dependencies>
}

@:forward
abstract Lock(LockData) from LockData {

    public static var FILE = 'haxelib.lock';

    public function new()
        this = {
            dependencies: new Map(),
            reels: new Map()
        }

    public function write(): Promise<Noise>
        return File.saveContent(FILE, tape.Json.stringify(toJson()));

    public function install(): Promise<Noise> {
        
        return null;
    }

    function dependenciesJson(dependencies: Dependencies)
        return [for (manifest in dependencies)
            manifest.name => '${manifest.version}'
        ];

    function toJson()
        return {
            dependencies: dependenciesJson(this.dependencies),
            reels: [
                for (reel in this.reels.keys())
                    reel => dependenciesJson(this.reels.get(reel))
            ]
        }

    @:to
    public function toString()
        return [for (manifest in this.dependencies) '$manifest']
        .concat([for (reel in this.reels)
            for (manifest in reel) '$manifest'
        ]).join('\n');

}