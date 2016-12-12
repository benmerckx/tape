package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      dependencies: {
        tink_core: '*'
      }
    }
  };

  static function main() {
    @:privateAccess tink.RunLoop.create(function () {
      var manifest = Manifest.fromJsonSchema(sample, 'testje').sure();
      manifest.resolveLock().handle(function (res) switch res {
        case Success(lock): 
          trace('$lock');
        case Failure(e): trace(e);
      });
    });
  }
  
}