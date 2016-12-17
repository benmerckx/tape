package tape;

import haxe.DynamicAccess;

class Json extends haxe.format.JsonPrinter {

    public static function parse(input: String): Dynamic
        return haxe.format.JsonParser.parse(input);

	public static inline function stringify(value: Dynamic): String {
		var printer = new Json(null, '  ');
		printer.write("", value);
		return printer.buf.toString();
	}

    override function fieldsString(v: Dynamic, fields: Array<String>) {
        fields.sort(function(a: String, b: String): Int {
            a = a.toLowerCase();
            b = b.toLowerCase();
            if (a < b) return -1;
            if (a > b) return 1;
            return 0;
        });
        return super.fieldsString(v, fields);
    }

}