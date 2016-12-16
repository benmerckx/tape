package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      reels: {
        two: {
          'ufront': ''
        },
        a: {
          'ufront': ''
        },
        b: {
          'ufront': ''
        },
        c: {
          'ufront': ''
        },
        d: {
          'ufront': ''
        },
        e: {
          'ufront': ''
        },
        r: {
          'ufront': ''
        }
      }
    }
  };

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