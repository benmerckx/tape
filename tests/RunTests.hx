package ;

import tape.Manifest;

class RunTests {

  static function main() {
    Manifest.fromFile('haxelib.json').handle(function(res) trace(res));
  }
  
}