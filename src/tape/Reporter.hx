package tape;

using tink.CoreApi;

typedef Progress = {
    ?description: String,
    ?completion: Float
}

typedef Report = {
    name: String,
    progress: Progress,
    tasks: Array<Report>
}

interface ReporterInterface {
    function report(?progress: Progress): Void;
    function task(name: String): Reporter;
    function status(): Report;
}

@:forward
abstract Reporter(ReporterInterface) from ReporterInterface {

    public static function create(name: String): Reporter {
        var reporter = new TapeReporter(name);
        reporter.signal.handle(StdOutPrinter.print);
        return reporter;
    }

    public static function fail(e: Error) {
        tink.RunLoop.current.work(function() {
            //StdOutPrinter.clear();
            Sys.print('$e');
            Sys.exit(e.code);
        });
    }

    public static function success(e: String) {
        inline function round(number:Float, ?precision=2): Float {
            number *= Math.pow(10, precision);
            return Math.round(number) / Math.pow(10, precision);
        }
        tink.RunLoop.current.work(function() {
            StdOutPrinter.clear(true);
            var diff = Sys.cpuTime() - @:privateAccess StdOutPrinter.start;
            var time =
                if (diff < 1) round(diff*1000)+'ms'
                else round(diff)+'s';
            Sys.print('> $e \x1b[94m${time}\x1b[0m\n');
        });
    }
    

}

class StdOutPrinter {

    static var MOVE_UP = ofHex('1b5b3141');
    static var CLEAR_LINE = ofHex('1b5b304b');
    static var last: Report;
    static var start = Sys.cpuTime();

    static function ofHex(str: String): String
        return haxe.crypto.BaseCode.decode(str, "0123456789abcdef").toString();

    public static function print(report: Report) {
        tink.RunLoop.current.work(function() {
            if (last != null) clear(last.name != report.name);
            Sys.println(toString(report));
            last = report;
        });
    }

    public static function clear(markAsDone = false) {
        if (last == null) return;
        var representation = toString(last);
        var lines = representation.split('\n').length;
        for (i in 0 ... lines)
            Sys.print(CLEAR_LINE+MOVE_UP);
        if (markAsDone)
            Sys.println(header(last.name)+' \x1b[94mdone\x1b[0m');
    }

    static function header(name: String)
        return '> $name...';

    static function toString(report: Report) {
        function pad(amount: Int)
            return [for (_ in 0 ... amount+1) ''].join(' ');
        function progress(name: String, progress: Progress) {
            if (progress == null) return name;
            var buf = new StringBuf();
            buf.add(name);
            if (progress.completion != null)
                buf.add(' [${Std.int(progress.completion*100)}/100]');
            if (progress.description != null)
                buf.add(' (${progress.description})');
            return buf.toString();
        }
        function print(report: Report, level: Int) {
            var response = [];
            var line = progress(report.name, report.progress);
            response.push(
                if (level == 0) header(line)
                else pad(level)+'- $line'
            );
            for (task in report.tasks)
                response = response.concat(print(task, level+1));
            return response;
        }
        return print(report, 0).join('\n');
    }

}

class TapeReporter implements ReporterInterface {
    
    var name: String;
    var trigger = new SignalTrigger<Report>();
    var tasks: Array<Reporter> = [];
    var progress: Progress;
    var parent: Reporter;

    public function new(name: String, ?parent: Reporter) {
        this.name = name;
        this.parent = parent;
    }

    public var signal(get, never): Signal<Report>;
    function get_signal() return trigger.asSignal();

    public function task(name: String): Reporter {
        var task = new TapeReporter(name, this);
        tasks.push(task);
        return task;
    }

    public function status(): Report
        return {
            name: name, progress: progress,
            tasks: [for (task in tasks) task.status()]
        }

    public function report(?progress: Progress) {
        if (progress != null) this.progress = progress;
        if (parent != null) parent.report();
        trigger.trigger(status());
    }

}