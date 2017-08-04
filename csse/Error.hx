package csse;

class Error {
	public static var no(default, null): Int;
	static var extra: String;
	static var pos: Int;

	public static function set(n: Int, ext: String, p: Int): Void {
		no = n;
		extra = ext;
		pos = p;
	}

	public static function str(name: String): String {
		if (no >= 0) return null;
		return extra != null && extra != ""
			? '$name[${S[-no]}: "$extra", pos: $pos]'
			: '$name[${S[-no]}, pos: $pos]';
	}

	public static inline function clear() {
		no = 0;
	}

	macro public static function exit(message, extra, pos) return macro @:mergeBlock {
		csse.Error.set($message, $extra, $pos);
		return;
	}
	macro public static function exitWith(message, extra, pos, retval) return macro @:mergeBlock {
		csse.Error.set($message, $extra, $pos);
		return $retval;
	}

	static var S = [
		"",
		"Invalid Char",      // -1
		"Invalid Selector",  // -2
		"Expected",          // ...
		"Invalid Argument",
		"Unexpected Whitespace After"
	];
}

