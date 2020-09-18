package csss;

import csss.CValid.*;
import csss.Selector;
using StringTools;

class Parser {

	public static function parse(s: String): Array<QList> {
		var list: Array<QList> = [];
		if (s != null && s != "") {
			list.push(new QList(None));
			var errno =	doParse(s, 0, s.length, list[0], list);
			var errmsg = switch (errno.type) {
			case None:             null;
			case InvalidChar:      'InvalidChar: ${s.charAt(errno.pos)}, pos: ${errno.pos}';
			case InvalidSelector:  'InvalidSelector: ${s.substr(errno.pos, errno.len)}, pos: ${errno.pos}';
			case Expected:         'Expected: ${String.fromCharCode(errno.len)}, pos: ${errno.pos}';
			case InvalidArgument:  'InvalidArgument: ${s.substr(errno.pos, errno.len)}, pos: ${errno.pos}';
			}
			if (errno.type != None) throw errmsg;
		}
		return list;
	}

	static function doParse(str: String, pos: Int, max: Int, cur: QList, list: Array<QList>): Error {
		inline function char(p) return str.fastCodeAt(p);
		var left: Int;
		var c: Int;
		var opt: Operator = None;
		var err:Error = Empty;
		pos = ignore_space(str, pos, max);

		while (pos < max) {
			c = char(pos++);
			switch (c) {
			case ".".code:
				left = pos;
				pos = ident(str, left, max, is_alpha_um, is_anum);
				if (left == pos) return Error.exit(InvalidChar, pos, 1);
				cur.add( QClass(str.substr(left, pos - left)) );
			case "#".code:
				left = pos;
				pos = ident(str, left, max, is_alpha_um, is_anum);
				if (left == pos) return Error.exit(InvalidChar, pos, 1);
				cur.add( QId(str.substr(left, pos - left)) );
			case "[".code:
				err = readAttribute(str, pos, max, cur);
				if (err.type != None) return err;
				pos = err.pos;
			case ":".code:
				err = readPseudo(str, pos, max, cur);
				if (err.type != None) return err;
				pos = err.pos;
			case ",".code:
				if (cur.empty()) return Error.exit(InvalidChar, pos - 1, 1);
				cur = new QList(None);
				list.push(cur);
				pos = ignore_space(str, pos, max);
			case " ".code, "\t".code:
				opt = Space;
				pos = ignore_space(str, pos, max);
				if (pos < max) {
					c = char(pos);
					if (!(c == ",".code || c == ">".code || c == "+".code || c == "~".code)) {
						cur.sub = new QList(opt);
						cur = cur.sub;
						opt = None;
					}
				}
			case ">".code,
				 "+".code,
				 "~".code:
				if (!(opt == None || opt == Space) || cur.empty())
					return Error.exit(InvalidChar, pos - 1, 1);
				opt = if (c == ">".code) {
					Child;
				} else if (c == "+".code) {
					Adjoin;
				} else {
					Sibling;
				}
				pos = ignore_space(str, pos, max);
				cur.sub = new QList(opt);
				cur = cur.sub;
				opt = None;
			case "*".code:
				if (!cur.empty())
					return Error.exit(InvalidChar, pos - 1, 1);
				cur.add( QNode("*") );
			default:
				if (is_alpha_u(c)) {
					left = pos - 1;
					pos = until(str, pos, max, is_anum);
					cur.add( QNode(str.substr(left, pos - left)) );
				} else {
					return Error.exit(InvalidChar, pos - 1, 1);
				}
			}
		}
		return Error.non(pos);
	}

	// str[pos-1] == ":"
	static function readPseudo(str: String, pos: Int, max: Int, cur: QList): Error {
		inline function char(p) return str.fastCodeAt(p);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		var dbColon = false;
		if (char(pos) == ":".code) {
			dbColon = true;
			++pos;
		}
		var left = pos;
		pos = until_pos(is_alpha_um);
		if (left == pos) return Error.exit(InvalidChar, pos, 1);
		var name = str.substr(left, pos - left);
		var c = char(pos);
		var err: Error = Empty;
		if (c == "(".code) {
			if (dbColon)
				return Error.exit(InvalidSelector, left - 2, pos - (left - 2));
			pos = ignore_space(str, pos + 1, max);
			switch (name) {
			case "lang":
				left = pos;
				pos = ident_pos(is_alpha_um, is_anum);
				if (pos == left) return Error.exit(InvalidChar, pos, 1);
				cur.add( QPseudo(PLang(str.substr(left, pos - left))) );
			case "not": // TODO
				var no = new QList(None);
				err = readPseudoNot(str, pos, max, no);
				if (err.type != None) return err;
				pos = err.pos;
				cur.add( QPseudo(PNot(no.h[0])) );
			case "contains":
				c = char(pos); //
				if (is_alpha_u(c)) {
					left = pos++;
					pos = until_pos(is_anum);
					cur.add( QPseudo(PContains( str.substr(left, pos - left) )) );
				} else if (c == '"'.code || c == "'".code) {
					left = pos + 1;
					err = readString(str, left, max, c == '"'.code);
					if (err.type != None) return err;
					pos = err.pos;
					cur.add( QPseudo(PContains( str.substr(left, pos - left) )) );
					pos++; // skip quotes
				} else {
					return Error.exit(InvalidChar, pos, 1);
				}
			default:
				var type = NthChild;
				switch(name) {
					case "nth-child":
					case "nth-last-child":   type = NthLastChild;
					case "nth-of-type":      type = NthOfType;
					case "nth-last-of-type": type = NthLastOfType;
					default:                 return Error.exit(InvalidSelector, left, pos - left);
				}
				err = readNM(str, pos, max, cur, type);
				if (err.type != None)
					return err;
				pos = err.pos;
			}
			pos = ignore_space(str, pos, max);
			if (char(pos) != ")".code) return Error.exit(Expected, pos, ")".code);
			++ pos;
		} else {
			cur.add( QPseudo(dbColon ? PSelectorDb(name) : PSelector(name)) );
		}
		return Error.non(pos);
	}
	static function readString( str : String, pos : Int, max : Int, dbquotes : Bool ) : Error {
		inline function char(p) return str.fastCodeAt(p);
		var endc = dbquotes ? '"'.code : "'".code;
		var i = pos;
		while (i < max) {
			var c = char(i);
			if (c == endc) {
				if (i == pos || (i > pos && char(i-1) != "\\".code)) {
					return Error.non(i);
				}
			}
			i++;
		}
		return Error.exit(Expected, i - 1, endc);
	}
	// str[pos-1] == "["
	static function readAttribute(str: String, pos: Int, max: Int, cur: QList): Error {
		inline function char(p) return str.fastCodeAt(p);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		pos = ignore_space(str, pos, max);
		var left = pos;
		pos = ident_pos(is_attr_first, is_anumx);
		if (pos == left)
			return Error.exit(InvalidChar, pos, 1);
		var key = str.substr(left, pos - left);

		var type = AExists;
		pos = ignore_space(str, pos, max);
		var c = char(pos++);
		if (c == "]".code) {
			cur.add( QAttr(new Attr(key, null, type)) );
		} else {
			switch(c) {
				case "=".code: type = AEq;
				case "~".code: type = AWave;
				case "^".code: type = AXor;
				case "$".code: type = ADollar;
				case "*".code: type = AMul;
				case "|".code: type = AOr;
				default:       return Error.exit(InvalidChar, pos - 1, 1);
			}
			if (c != "=".code) {
				if (char(pos++) != "=".code) return Error.exit(Expected, pos - 1, "=".code);
			}
			pos = ignore_space(str, pos, max);
			c = char(pos);
			if (is_alpha_um(c)) {
				left = pos++;
				pos = until_pos(is_anum);
			} else if (c == '"'.code || c == "'".code) {
				left = pos + 1;
				var err = readString(str, left, max, c == '"'.code);
				if (err.type != None)
					return err;
				pos = err.pos;
			} else {
				return Error.exit(InvalidChar, pos, 1);
			}
			cur.add( QAttr(new Attr(key, str.substr(left, pos - left), type)) );  // if pos == left then empty string("")
			c = char(pos);
			if (c == '"'.code || c == "'".code) ++pos;
			pos = ignore_space(str, pos, max);
			c = char(pos++);
			if (c != "]".code) return Error.exit(Expected, pos - 1, "]".code);
		}
		return Error.non(pos);
	}

	static function readNM(str: String, pos: Int, max: Int, cur: QList, type: NthType): Error {
		inline function char(p) return str.fastCodeAt(p);
		var n = 1, m = 0;
		if (str.substr(pos, 4).toLowerCase() == "even") {
			n = 2; // 2n + 0
			pos += 4;
		} else if (str.substr(pos, 3).toLowerCase() == "odd") {
			n = 2; // 2n + 1
			m = 1;
			pos += 3;
		} else {
			var gotN = false;
			var t: Null<Int> = null;
			var sign = 2;      // 0 == "+", 1 == "-"
			var c;
			var ep = pos;
			while (pos < max) {
				c = char(pos);
				switch (c) {
				case "n".code, "N".code:
					if (gotN) return Error.exit(InvalidChar, pos, 1);
					gotN = true;
					t = null;
					sign = 2;  // reset
				case "-".code:
					if (sign < 2) return Error.exit(InvalidChar, pos, 1);
					sign = 1;
					if (!gotN && (char(pos + 1) | 0x20) == "n".code) n = -1;
				case "+".code:
					if (sign < 2) return Error.exit(InvalidChar, pos, 1);
					sign = 0;
				case ")".code:
					if (t == null && (!gotN || sign < 2)) {
						return Error.exit(InvalidArgument, ep, pos - ep);
					}
					if (!gotN) {
						m = n;
						n = 0;
					}
					max = 0;  // break loop;
					continue;
				default:
					if (is_number(c)) {
						if (t != null)
							return Error.exit(InvalidArgument, ep, pos - ep);
						var left = pos;
						pos = until(str, pos + 1, max, is_number);
						t = Std.parseInt(str.substr(left, pos - left));
						if (sign > 1) {
							sign = 0;       // disable rec "sign"
						} else if (sign == 1 && t > 0) {
							t = -t;
						}
						if (gotN) {
							m = t;
						} else {
							n = t;
						}
						continue;
					} else if (c == " ".code || c == "\t".code) {
						if (!gotN) {       // e.g: nth-child(" 2 ")
							if (t == null) // e.g: nth-child(" + ")
								return Error.exit(InvalidArgument, ep, pos - ep);
							m = n;
							n = 0;
							t = 0;         // disalbe rec "int"
							gotN = true;   // disable rec "n"
						}
					} else {
						return Error.exit(InvalidChar, pos, 1);
					}
				}
				++ pos;
			}
		}
		cur.add( QPseudo(PNth(type, n, m)) );
		return Error.non(pos);
	}

	// for ":not( |single-selector| )".
	static function readPseudoNot(str: String, pos: Int, max: Int, cur: QList): Error {
		inline function char(p) return str.fastCodeAt(p);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		var left: Int;
		var c = char(pos++);
		var err: Error = Empty;
		switch (c) {
		case ".".code:
			left = pos;
			pos = ident_pos(is_alpha_um, is_anum);
			if (pos == left) return Error.exit(InvalidChar, pos, 1);
			cur.add( QClass(str.substr(left, pos - left)) );
		case "#".code:
			left = pos;
			pos = ident_pos(is_alpha_um, is_anum);
			if (pos == left) return Error.exit(InvalidChar, pos, 1);
			cur.add( QId(str.substr(left, pos - left)) );
		case "[".code:
			err = readAttribute(str, pos, max, cur);
			if (err.type != None) return err;
			pos = err.pos;
		case ":".code:
			err = readPseudo(str, pos, max, cur);
			if (err.type != None) return err;
			pos = err.pos;
		case "*".code:
			cur.add( QNode("*") );
		default:
			if (is_alpha_u(c)) {
				left = pos - 1;
				pos = until_pos(is_anum);
				cur.add( QNode(str.substr(left, pos - left)) );
			} else {
				return Error.exit(InvalidChar, pos - 1, 1);
			}
		}
		return Error.non(pos);
	}

	static inline function is_attr_first(c: Int) return is_alpha_u(c) || c == ":".code;
}

/**
Note: Limit to 7
*/
@:enum extern abstract ErrType(Int) to Int {
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

	var pos(get, never): Int; // [ 0-19] 20bit
	var len(get, never): Int; // [20-27]  8bit
	var type(get, never): ErrType;
	private inline function get_pos():Int return this & MAX_POS;
	private inline function get_len():Int return (this >> BIT) & MAX_LEN;
	private inline function get_type():ErrType return cast this & ERR_MASK;

	inline function new(type: ErrType, pos: Int, len: Int) this = pos | (len << BIT) | type;

	static inline var ERR_MASK = 0x70000000;
	static inline var MAX_POS = 0xFFFFF;
	static inline var MAX_LEN = 0xFF;
	static inline var BIT = 20;

	static inline function exit(t: ErrType, p: Int, l: Int):Error return cast (p | (l << BIT) | t);
	static inline function non(p: Int):Error return cast p;
}
