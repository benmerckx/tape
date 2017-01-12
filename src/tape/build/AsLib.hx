package tape.build;

import haxe.macro.Context;
import sys.io.Process;
import haxe.io.Path;

using StringTools;

// Include tape with -lib tape
class AsLib extends AsRun {

    override function path() {
        var paths = Context.getClassPath();
        for (path in paths)
            if (Path.normalize(path).endsWith('/tape/src'))
                return Path.join([path, '..']);
        return '.';
    }

    function include() {
        var dir = Sys.getCwd();
        compile();
        Sys.setCwd(dir);
        var process = new Process('neko', [bin()].concat(['path']));
        var path = [], addToPath = false;
        while (true) {
            try {
                var line = process.stdout.readLine();
                if (line == '> Path: ') {
                    addToPath = true;
                } else if (addToPath) {
                    if (!line.startsWith('>')) {
                        var space = line.indexOf(' ');
                        if (space > -1) {
                            path.push(line.substr(0, space));
                            path.push(line.substr(space+1));
                        } else {
                            path.push(line);
                        }
                    }
                } else {
                    Sys.println(line);
                }
            } catch (e: Dynamic)
                break;
        }
        var args = Sys.args();
        var i = 0;
        var final = path;
        while (i < args.length) {
			switch [args[i], args[i+1]] {
				case ['-lib', 'tape']:
                    i++;
                case ['-lib', lib] if (lib.startsWith('tape:')):
                    i++;
				//case ['--next', _]:
                    // todo
				default:
					final.push(args[i]);
			}
			i++;
		}
        Sys.exit(Sys.command('haxe', final));
    }

    static function init() {
        if (Sys.getEnv('HAXELIB_RUN') != null) return;
        new AsLib().include();
    }

}