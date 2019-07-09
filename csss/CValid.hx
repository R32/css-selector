package csss;

using StringTools;

class CValid {

	public static inline var ERR_POS = -1;

#if (utf16 || eval)
	public static function bytePosition(str: String, cpos: Int): Int {
		var i = 0;
		var bytes = 0;
		while (i < cpos) {
			var c = StringTools.fastCodeAt(str, i);
			if (c < 0x80) {
				++ bytes;
			} else if (c < 0x800) {
				bytes += 2;
			} else if (c >= 0xD800 && c <= 0xDFFF) {
				bytes += 4;
			} else {
				bytes += 3;
			}
			++ i;
		}
		return bytes;
	}
#else
	public static inline function bytePosition(str: String, cpos: Int): Int return cpos;
#end

	public static inline function mbsLength(str: String):Int return bytePosition(str, str.length);

	public static function ignore_space(str: String, i: Int, max: Int): Int {
		while (i < max) {
			if (!is_space(str.fastCodeAt(i))) return i;
			++ i;
		}
		return max;
	}

	public static function until(str: String, i: Int, max: Int, callb: Int -> Bool): Int {
		while (i < max) {
			if (!callb(str.fastCodeAt(i))) return i;
			++ i;
		}
		return max;
	}

	public static function ident(str: String, i: Int, max: Int, first: Int->Bool, rest: Int->Bool): Int {
		if (!first(str.fastCodeAt(i))) return i; // TODO: the i may greater than max.
		while (++i < max) {
			if (!rest(str.fastCodeAt(i))) return i;
		}
		return max;
	}

	public static inline function is_alpha(c: Int) {
		return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code);
	}

	public static inline function is_number(c: Int) {
		return c >= "0".code && c <= "9".code;
	}

	public static inline function is_space(c: Int) {
		return c == " ".code || (c > 8 && c < 14);// || c == 0x3000 || c == 0xA0;
	}

	/**
	 alpha + "_"
	*/
	public static inline function is_alpha_u(c: Int) {
		return is_alpha(c) || c == "_".code;
	}

	/**
	 alpha + "_" + "-"
	*/
	public static inline function is_alpha_um(c: Int) {
		return is_alpha_u(c) || c == "-".code;
	}
	/**
	 alpha + number + "_"
	*/
	public static inline function is_anu(c: Int) {
		return is_alpha_u(c) || is_number(c);
	}

	/**
	 alpha + number + "_" + "-"
	*/
	public static inline function is_anum(c: Int) {
		return is_anu(c) || c == "-".code;
	}

	/**
	 alpha + number + "_" + "-" + ":" + "." that used for Xml's nodeName
	*/
	public static inline function is_anumx(c: Int) {
		return is_anum(c) || c == ":".code || c == ".".code;
	}
}