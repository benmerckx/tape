package tape.commands;

@:access(tape.commands.Install)
class Path extends Command {

    public static function run() {
        var lock: Lock;
        return Install.getLock()
        .next(function (_) return lock = _)
        .next(Install.install)
        .next(function (_) return lock.dependencies.path())
        .next(function (path) return 'Path: \n'+path.join('\n')+'\n> Done');
    }

    public function runDefault()
        run().handle(report);

}