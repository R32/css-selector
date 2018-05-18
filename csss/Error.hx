package csss;

/**
Note: Limit to 7
*/
@:enum extern abstract Type(Int) to Int {
	var None = 0;
	var InvalidChar     = 1 << 28;
	var InvalidSelector = 2 << 28;
	var Expected        = 3 << 28;
	var InvalidArgument = 4 << 28;
}

/**
  [0-19]:  pos, MAX = 1048575 Negative values are not allowed
  [20-27]: len, MAX = 255, Negative values are not allowed
  [28-30]: type, MAX = 7
*/
@:enum extern abstract Error(Int) {
	var Empty = 0;

	var pos(get, never): Int; // [ 0-19] 2bit
	var len(get, never): Int; // [20-27] 8bit
	var type(get, never): Type;
	private inline function get_pos():Int return this & MAX_POS;
	private inline function get_len():Int return (this >> BIT) & MAX_LEN;
	private inline function get_type():Type return cast this & ERR_MASK;

	inline function new(type: Type, pos: Int, len: Int) this = pos | (len << BIT) | type;

	static inline var ERR_MASK = 0x70000000;
	static inline var MAX_POS = 0xFFFFF;
	static inline var MAX_LEN = 0xFF;
	static inline var BIT = 20;

	static inline function exit(t: Type, p: Int, l: Int):Error return cast (p | (l << BIT) | t);
	static inline function non(p: Int):Error return cast p;
}
