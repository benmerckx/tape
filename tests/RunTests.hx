package ;

import tape.*;

class RunTests {

  static function main() {
    Manifest.fromFile('haxelib.json').handle(function(res) switch res {
      case Success(manifest):
        var lock = new Lock(manifest);
        lock.resolve().map(function(progress) trace(progress));
      case Failure(e): trace(e);
    });
  }
  
}