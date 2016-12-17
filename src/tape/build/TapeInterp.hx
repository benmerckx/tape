package tape.build;

import haxe.io.Path;

// Run tape as haxelib run tape
class TapeInterp {

    macro static function path()
        return macro $v{Sys.getCwd()};

    static function main() {
        var compiled = Path.join([path(), 'bin', 'tape.n']);
        //if (!sys.FileSystem.exists(compiled)) {
            var code = Sys.command('haxe', ['-lib', 'tape', '-main', 'tape.Tape', '-neko', compiled]);
            if (code != 0) Sys.exit(code);
        //}
        var args = Sys.args();
        Sys.setCwd(args.pop());
        Sys.exit(Sys.command('neko', [compiled].concat(args)));
    }

}