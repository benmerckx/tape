package tape;

import semver.RangeSet;
import tape.registry.*;

using StringTools;

enum SourceType {
    Root(manifest: Manifest);
    Versioned(range: RangeSet, registry: Registry);
    Pinned;
}

abstract Source(SourceType) from SourceType {

    static var registry = new Cache(Local.instance.concat(Haxelib.instance));
   
    @:from
    static function fromString(str: String): Source
        return if (str.startsWith('git'))
            Pinned;
        else
            Versioned((str: RangeSet), registry);

    @:to
    public function toString()
        return switch this {
            case Root(manifest): manifest.name+'@'+manifest.version;
            case Versioned(range, _): '$range';
            case Pinned: 'pinned';
        }

}