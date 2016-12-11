package tape;

typedef Dependencies = Map<String, Manifest>;

typedef LockData = {
    dependencies: Dependencies,
    reels: Map<String, Dependencies>
}

@:forward
abstract Lock(LockData) from LockData {

    public function new()
        this = {
            dependencies: new Map(),
            reels: new Map()
        }

    @:to
    public function toString()
        return [for (manifest in this.dependencies)
            manifest.name+'@'+manifest.version
        ].concat(
        [for (reel in this.reels)
            for (manifest in reel)
                manifest.name+'@'+manifest.version
        ]).join('\n');

}