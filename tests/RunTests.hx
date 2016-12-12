package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      reels: {
        two: {
          'tink_core': '<1.4.0'
        },
        a: {
          'tink_core': '<1.2.0'
        },
        b: {
          'tink_core': '<1.2.0'
        },
        c: {
          'tink_core': '>1.5.0'
        },
        d: {
          'tink_core': '<1.2.0'
        },
        e: {
          'tink_core': '<1.2.0'
        },
        r: {
          'tink_core': '*'
        }
      }
    }
  };

  static function main() {
    #if tink_runloop @:privateAccess tink.RunLoop.create(function () { #end
      var manifest = Manifest.fromJsonSchema(sample, 'testje').sure();
      manifest.lock().handle(function (res) switch res {
        case Success(lock): 
          lock.write().handle(function(_) {
            trace('$lock');
          });
        case Failure(e): Sys.println(e);
      });
     #if tink_runloop }); #end
  }
  
}