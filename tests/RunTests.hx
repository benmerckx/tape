package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      dependencies: {
        ufront: "*"
      }
    }
  }

  static function main() {
      var manifest = Manifest.fromJsonSchema(sample, 'testje').sure();
      manifest.lock().handle(function (res) switch res {
        case Success(lock): 
          lock.write().handle(function(_) {
            trace('$lock');
          });
        case Failure(e): Sys.println(e);
      });
  }
  
}