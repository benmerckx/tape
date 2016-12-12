package tape;

using tink.CoreApi;

@:forward
abstract PreviousErrors(Array<Error>) from Array<Error> {

    @:from 
    public static function fromError(e: Error): PreviousErrors
        return [e];

}

class TapeError extends TypedError<PreviousErrors> {

    override public function toString() {
        return 
            '\n> $message' + 
            '\n@ '+printPos() +
            if (data != null) [
                for (err in data)
                    err.toString()
            ].join('\n') 
            else '';
    }

    public static function create(?code: Int, message: String, ?previous: PreviousErrors, ?pos: haxe.PosInfos): Error {
        var error = new TapeError(message, pos);
        error.data = previous;
        return cast error;
    }

}