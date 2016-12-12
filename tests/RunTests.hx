package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      dependencies: {
        tink_io: '*'
      }
    }
  };

  static function main() {
    #if tink_runloop @:privateAccess tink.RunLoop.create(function () { #end
      var manifest = Manifest.fromJsonSchema(sample, 'testje').sure();
      manifest.resolveLock().handle(function (res) switch res {
        case Success(lock): 
          trace('$lock');
        case Failure(e): trace(e);
      });
     #if tink_runloop }); #end
  }
  
}