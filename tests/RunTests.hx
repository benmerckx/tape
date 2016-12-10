package ;

import tape.*;

using tink.CoreApi;

class RunTests {

  static function main() {
    var manifest = Manifest.fromJsonSchema({
      name: 'test',
      version: '0.0.0',
      dependencies: {
        monsoon: '^1.4'
      }
    }).sure();
    manifest.resolveLock();
  }
  
}