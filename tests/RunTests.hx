package ;

import tape.*;
import haxe.Json;

using tink.CoreApi;

class RunTests {

  static var sample: Dynamic = {
    tape: {
      dependencies: {
        tink_io: '*',
        monsoon: '>0.1'
      },
      reels: {
        embed: {
          monsoon: '>0.1',
          'ufront': ''
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
        case Failure(e): trace(e);
      });
     #if tink_runloop }); #end
  }
  
}