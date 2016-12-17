package tape;

using tink.CoreApi;

@:forward
abstract PreviousErrors(Array<Error>) from Array<Error> {

    @:from 
    public static function fromError(e: Error): PreviousErrors
        return [e];

}

class TapeError extends TypedError<PreviousErrors> {

    override function printPos()
        return pos.className.split('.').pop()+'.'+pos.methodName+':'+pos.lineNumber;

    override public function toString() {
        function pad(amount: Int)
            return [for (_ in 0 ... amount+1) ''].join(' ');
        function msg(e: Error)
            return '${e.message} \x1b[94m@ ${e.printPos()} \x1b[0m';
        function prev(errors: PreviousErrors, level: Int) {
            if (errors == null) return [];
            var response = [];
            for (error in errors)
                response = response.concat([pad(level)+'- '+msg(error)].concat(prev(cast error.data, level+1)));
            return response;
        }
        return 
            '> '+msg(this) + '\n' + prev(data, 1).join('\n');
    }

    public static function create(?code: Int, message: String, ?previous: PreviousErrors, ?pos: haxe.PosInfos): Error {
        var error = new TapeError(message, pos);
        error.data = previous;
        return cast error;
    }

    public static function fromError(e: Error) {
        return new TapeError(e.code, e.message, e.pos);
    }

}