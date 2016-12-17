package tape.build;

import haxe.io.Path;

// Run tape as haxelib run tape
class TapeInterp {

    macro static function path()
        return macro $v{Sys.getCwd()};

    static function main() {
        //var node = new sys.io.Process('node --version').exitCode() == 0;
        var compiled = Path.join([path(), 'bin', 'tape.n']);
        //if (!sys.FileSystem.exists(compiled)) {
            var flags = ['-lib', 'tape', '-main', 'tape.Tape', '-D', 'concurrent', '-neko', compiled];
            var code = Sys.command('haxe', flags);
            if (code != 0) Sys.exit(code);
        //}
        var args = Sys.args();
        Sys.setCwd(args.pop());
        Sys.exit(Sys.command('neko', [compiled].concat(args)));
    }

    /*static function onNode() {
        var compiled = Path.join([path(), 'bin', 'tape.js']);
        //if (!sys.FileSystem.exists(compiled)) {
            var flags = ['-lib', 'tape', '-main', 'tape.Tape', '-lib', 'hxnodejs', '-node', compiled];
            var code = Sys.command('haxe', flags);
            if (code != 0) Sys.exit(code);
        //}
        var args = Sys.args();
        Sys.setCwd(args.pop());
        Sys.exit(Sys.command('node', [compiled].concat(args)));
    }*/

}