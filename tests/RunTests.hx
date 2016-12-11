package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      dependencies: {
        monsoon: '',
        tink_macro: '^0.10.0'
      },
      reels: {
        embed: {
          tink_tcp: '*',
          systools: '^1'
        }
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