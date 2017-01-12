package tape.build;

import haxe.io.Path;

// Run tape as haxelib run tape
class AsRun {

    public function new() {}

    function path()
        return compilePath();

    function bin()
        return Path.join([path(), 'bin', 'tape.n']);

    function run(dir: String, args: Array<String>) {
        compile();
        Sys.setCwd(dir);
        Sys.exit(Sys.command('neko', [bin()].concat(args)));
    }

    function compile() {
        if (!sys.FileSystem.exists(bin())) return;
        Sys.setCwd(path());
        var flags = ['-cp', Path.join([path(), 'src']), Path.join([path(), 'lib', 'vendor.hxml']), '-main', 'tape.Tape', '-neko', bin()];
        var code = Sys.command('haxe', flags);
        if (code != 0) Sys.exit(code);
    }

    static function main() {
        var args = Sys.args();
        new AsRun().run(args.pop(), args);
    }

    macro static function compilePath()
        return macro $v{Sys.getCwd()};

}