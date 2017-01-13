package tape;

import semver.RangeSet;
import tape.registry.*;

using tink.CoreApi;

enum SourceType {
    Versioned(range: RangeSet, registry: Registry);
    Pinned(location: Location);
}

abstract Source(SourceType) from SourceType {

    static var registry = new Cache(Local.instance.concat(HaxeReleases.instance).concat(Haxelib.instance));
   
    @:from
    static function fromString(str: String): Source
        return try
            Pinned(str)
        catch (e1: Any)
            try
                Versioned(str, registry)
            catch (e2: Error)
                throw TapeError.create('Could not parse source "$str"', [TapeError.fromAny(e1), e2]);

    @:to
    public function toString()
        return switch this {
            case Versioned(range, _): '$range';
            case Pinned(location): '$location';
        }

}