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
   
    @:from
    static function fromString(str: String): Source
        return if (str.startsWith('git'))
            Pinned;
        else
            Versioned((str: RangeSet), Local.instance.concat(Haxelib.instance));

}