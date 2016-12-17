package tape;

import mcli.CommandLine;
import mcli.Dispatch;
import tape.commands.*;
import tape.Source;

using tink.CoreApi;

/** tape@0.0.0 **/
class Tape extends CommandLine {

    /** Initialize tape in this directory **/
    public function init(d: Dispatch) {
        preventDefault();
        d.dispatch(new Init());
    }

    /** Add a library **/
    public function add(d: Dispatch) {
        preventDefault();
        d.dispatch(new Add());
    }

    public function runDefault() {
        Sys.println(showUsage());
        Sys.exit(0);
    }

    static function main() {
        var args = Sys.args();
        Dispatch.addDecoder({
            fromString: function(str: String): Option<Source>
                return 
                    if (str == null) None
                    else try Some((str: Source)) 
                    catch(e: Error)
                        throw TapeError.create('Could not parse version source "$str"', 
                            TapeError.fromError(e)
                        )
        });
        try 
            new Dispatch(args).dispatch(new Tape())
        catch (e: Error)
            Reporter.fail(e);
    }

}