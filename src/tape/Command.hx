package tape;

import mcli.CommandLine;

using tink.CoreApi;

class Command extends CommandLine {

    function report(status: Outcome<String, Error>)
        switch status {
            case Success(done): Reporter.success(done);
            case Failure(e): Reporter.fail(e);
        }

}