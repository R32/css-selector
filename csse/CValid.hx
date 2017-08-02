package csse;

using StringTools;

class CValid {

	public static function ignore_space(str: String, i: Int, max: Int): Int {
		while (i < max) {
			if (!is_space(str.fastCodeAt(i))) break;
			++ i;
		}
		return i;
	}

	public static function until(str: String, i: Int, max: Int, callb: Int -> Bool): Int {
		while (i < max) {
			if (!callb(str.fastCodeAt(i))) break;
			++ i;
		}
		return i;
	}

	public static function ident(str: String, i: Int, max: Int, first: Int->Bool, rest: Int->Bool): Int {
		if (!first(str.fastCodeAt(i))) return i;
		while (++i < max) {
			if (!rest(str.fastCodeAt(i))) break;
		}
		return i;
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