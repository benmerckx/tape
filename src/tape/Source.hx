package tape;

import semver.RangeSet;
import tape.registry.Haxelib;

using StringTools;

enum SourceType {
    Versioned(range: RangeSet, registry: Registry);
    Pinned;
}

abstract Source(SourceType) from SourceType {
   
    @:from
    static function fromString(str: String): Source
        return if (str.startsWith('git'))
            Pinned;
        else
            Versioned((str: RangeSet), Haxelib.instance);

}