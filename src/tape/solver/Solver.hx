package tape.solver;

import tape.Dependency;
import tink.streams.StreamStep;
import tink.streams.Stream;

using tink.CoreApi;

// To be replaced by a backtracking depth-first search
// Check https://github.com/CocoaPods/Molinillo for an example in ruby
class Solver {

    var remaining: Array<Dependency> = [];
    var selected: Map<String, Manifest> = new Map();

    public function new(dependencies: Array<Dependency>)
        remaining = dependencies.copy();
    
    public function solve(reporter: Reporter, previous: Option<Lock>): Promise<Map<String, Manifest>> {
        return advance(reporter, previous)
            .forEach(function (manifest) {
                reporter.report({
                    description: 'Resolved "${manifest.key()}"'
                });
                return true;
            }).map(function (res) return switch res {
                case Success(_):
                    Success(selected);
                case Failure(e):
                    Failure(e);
            });
    }

    function advance(reporter: Reporter, previous: Option<Lock>): Stream<Manifest> return function(): Future<StreamStep<Manifest>> {
        var dependency = null;
        while (remaining.length > 0) {
            dependency = remaining.shift();
            if (!selected.exists(dependency.name))
                break;
        }
        if (dependency == null)
            return Future.sync(End);
        return dependency.candidates(reporter, previous)
        .next().map(function(step) return switch step {
            case Data(manifest):
                remaining = remaining.concat(manifest.dependencies);
                selected.set(manifest.name, manifest);
                Data(manifest);
            case Fail(e):
                Fail(TapeError.create('Could not load library "$dependency"', e));
            case End: 
                Fail(TapeError.create('No suitable version found for "$dependency"'));
        });
    }

}