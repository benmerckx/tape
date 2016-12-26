package tape;

import semver.RangeSet;
import tape.registry.*;
import tink.Url;

using StringTools;

@:enum
abstract PinnedType(String) to String {
    var Git = 'git:';
    var Tarball = '';
    var File = 'file:';
}

enum SourceType {
    Versioned(range: RangeSet, registry: Registry);
    Pinned(type: PinnedType, url: Url);
}

abstract Source(SourceType) from SourceType {

    static var registry = new Cache(Local.instance.concat(Haxelib.instance));
   
    @:from
    static function fromString(str: String): Source
        return if (str.startsWith(Git))
            Pinned(Git, Url.parse(str.substr((Git: String).length)))
        else if (str.startsWith(File))
            Pinned(File, Url.parse(str.substr((File: String).length)))
        else
            try
                Pinned(Tarball, Url.parse(str))
            catch (e: Dynamic)
                Versioned((str: RangeSet), registry);

    @:to
    public function toString()
        return switch this {
            case Versioned(range, _): '$range';
            case Pinned(type, url): '$type$url';
        }

}