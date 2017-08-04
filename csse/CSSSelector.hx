package csse;

import csse.CValid.*;
using StringTools;

@:dce @:enum abstract Relation(Int) to Int {
	var None    = 0;
	var Space   = " ".code;
	var Child   = ">".code;
	var Adjoin  = "+".code;
	var Sibling = "~".code;
	@:allow(csse.CSSSelector) private static inline function ofInt(n: Int):Relation return cast n;
}

@:dce @:enum abstract AttrType(Int) to Int {
	var None   = 0;  // [title]
	var Eq     = "=".code;
	var Wave   = "~".code;
	var Xor    = "^".code;
	var Dollar = "$".code;
	var All    = "*".code;
	var Or     = "|".code;
	@:allow(csse.CSSSelector) private static inline function ofInt(i: Int):AttrType return cast i;
}

@:dce @:enum private abstract State(Int) to Int {
	var NEW		= 0;
	var RACE	= 1;
	var ID		= 2;
	var CLASS	= 3;
	var ATTRIB  = 4;
	var PSEUDO	= 5;
}

enum PElem {
	Classes(name: String);
	Lang(s: String);
	Not(sc: CSSSelector);
	Nth(name: String, n: Int, m: Int);
}

class Attrib {
	public var name: String;
	public var value: String;
	public var type: AttrType;
	public function new(n, v, t) {
		name = n;
		value = v;
		type = t;
	}
	public function toString(): String {
		return switch (type) {
		case None:   '[$name]';
		case Eq:     '[$name=$value]';
		case Wave:   '[$name~=$value]';
		case Xor:    '[$name^=$value]';
		case Dollar: '[$name$=$value]';
		case All:    '[$name*=$value]';
		case Or:     '[$name|=$value]';
		}
	}
}

@:dce @:enum abstract ParseError(Int) to Int {
	var None = 0;
	var InvalidChar     = -1;
	var InvalidSelector = -2;
	var Expected        = -3;
	var InvalidArgument = -4;
	var UnexpectedWhitespace = -5;
}

class CSSSelector {
	public var name: String;
	public var id: String;
	public var sub: CSSSelector;
	public var rela: Relation;
	public var classes: Array<String>;
	public var pseudo: Array<PElem>;
	public var attr: Array<Attrib>;

	public function new(rel) {
		name = "";
		id = null;
		sub = null;
		rela = rel;
		classes = [];
		pseudo = [];
		attr = [];
	}

	function pse2str(): String {
		if (pseudo.length == 0) return "";
		var sa = [""];
		for (pe in pseudo) {
			switch (pe) {
			case Classes(s):
				sa.push(s);
			case Lang(s):
				sa.push('lang($s)');
			case Not(sc):
				sa.push('not(${sc.toString()})');
			case Nth(s, n, m):
				var sn = switch (n) {
				case  0: "";
				case  1: "n";
				case -1: "-n";
				default:
					n + "n";
				}
				var sm = m == 0 ? "" : (m > 0 && n != 0 ? "+" + m : "" + m);
				sa.push('$s($sn$sm)');
			}
		}
		return sa.join(":"); // TODO: use :: for pseudo-element
	}

	public function toString() {
		var sid = id == null || id == "" ? "" : '#$id';
		var sattr = attr.length == 0 ? "" : [for (a in attr) a.toString()].join("");
		var sclasses = classes.length == 0 ? "" : '.${classes.join(".")}';
		var spse = pse2str();
		if (sub != null) {
			var srela = sub.rela == Space ? " " : (" " + String.fromCharCode(sub.rela) + " ");
			return '$name$sattr$sid$sclasses$spse$srela${sub.toString()}';
		} else {
			return '$name$sattr$sid$sclasses$spse';
		}
	}

	public static function parse(s: String) {
		var list = [new CSSSelector(None)];
		Error.clear();
		doParse(s, 0, s.length, list[0], list);
		if (Error.no < 0) {
		#if sys
			Sys.println(Error.str("CSSSelectorParse"));
		#else
			trace(Error.str("CSSSelectorParse"));
		#end
			return null;
		}
		return list;
	}

	static function doParse(str: String, pos: Int, max: Int, cur: CSSSelector, list: Array<CSSSelector>): Void {
		var state = NEW;
		var next = NEW;
		var left: Int;
		var c: Int;

		inline function char(p) return str.fastCodeAt(p);

		pos = ignore_space(str, pos, max);

		while (pos < max) {
			c = char(pos);
			switch (state) {
			case NEW:
				switch (c) {
				case ".".code:
					state = CLASS;
				case "#".code:
					state = ID;
				case "[".code:
					state = ATTRIB;
				case ":".code:
					state = PSEUDO;
				default:
					if (is_alpha_u(c)) {
						left = pos;
						pos = until(str, pos + 1, max, is_anum);
						cur.name = str.substr(left, pos - left).toUpperCase();
						state = RACE;
						continue;
					} else if (c == "*".code) {
						state = RACE;
					} else {
						Error.exit(InvalidChar, str.charAt(pos), pos);
					}
				}
			case RACE:
				switch (c) {
				case ".".code:
					state = CLASS;
				case "[".code:
					state = ATTRIB;
				case "#".code:
					state = ID;
				case ":".code:
					state = PSEUDO;
				case ",".code: // group
					var sib = new CSSSelector(None);
					list.push(sib);
					doParse(str, pos + 1, max, sib, list);
					return;
				case " ".code,
					 ">".code,
					 "+".code,
					 "~".code:
					var rel = Relation.ofInt(c);
					pos = ignore_space(str, pos + 1, max);
					c = char(pos);
					if (c == ">".code || c == "+".code || c == "~".code) {
						pos = ignore_space(str, pos + 1, max);
						rel = Relation.ofInt(c);
					}
					cur.sub = new CSSSelector(rel);
					doParse(str, pos, max, cur.sub, list);
					return;
				default:
				}
			case ID:
				left = pos;
				pos = ident(str, pos, max, is_alpha_um, is_anum);
				if (left == pos) Error.exit(InvalidChar, str.charAt(pos), pos);
				cur.id = str.substr(left, pos - left);
				state = RACE;
				continue;
			case CLASS:
				left = pos;
				pos = ident(str, pos, max, is_alpha_um, is_anum);
				if (left == pos) Error.exit(InvalidChar, str.charAt(pos), pos);
				cur.classes.push(str.substr(left, pos - left));
				state = RACE;
				continue;
			case PSEUDO:
				pos = on_pseudo(str, pos, max, cur);
				if (pos == ERR_POS) return;
				state = RACE;
				continue;
			case ATTRIB:
				pos = on_attr(str, pos, max, cur);
				if (pos == ERR_POS) return;
				state = RACE;
				continue;
			default:
			}
			++ pos;
		}
	}

	// str[pos-1] == ":"
	static function on_pseudo(str: String, pos: Int, max: Int, cur: CSSSelector): Int {
		var left = pos;

		inline function IGNORE_SPACES() pos = ignore_space(str, pos, max);
		inline function char(p) return str.fastCodeAt(p);
		inline function charAt(p) return str.charAt(p);
		inline function substr() return str.substr(left, pos - left);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		if (char(pos + 1) == ":".code) ++pos; // skip ::

		pos = until_pos(is_alpha_um);
		if (left == pos) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
		var name = substr();
		if (!mp.exists(name)) Error.exitWith(InvalidSelector, name, left, ERR_POS);
		var c = char(pos);
		if (c == "(".code) {
			pos = ignore_space(str, pos + 1, max);
			switch (name) {
			case "lang":
				left = pos;
				pos = ident_pos(is_alpha_um, is_anum);
				if (pos == left) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
				cur.pseudo.push(Lang(substr()));
			case "not": // TODO
				var no = new CSSSelector(None);
				pos = not(str, pos, max, no);
				if (pos == ERR_POS) return -1;
				cur.pseudo.push(Not(no));
			default:
				if (name.substr(0, 3) == "nth") {
					pos = nth(str, pos, max, cur, name);
					if (pos == ERR_POS) return -1;
				} else {
					Error.exitWith(InvalidSelector, name, left, ERR_POS);
				}
			}
			IGNORE_SPACES();
			if (char(pos++) != ")".code) Error.exitWith(InvalidChar, charAt(pos - 1), pos - 1, ERR_POS);
		} else {
			cur.pseudo.push(Classes(name));
		}
		return pos;
	}
	// str[pos-1] == "["
	static function on_attr(str: String, pos: Int, max: Int, cur: CSSSelector): Int {
		var left: Int;

		inline function IGNORE_SPACES() pos = ignore_space(str, pos, max);
		inline function char(p) return str.fastCodeAt(p);
		inline function charAt(p) return str.charAt(p);
		inline function substr() return str.substr(left, pos - left);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		IGNORE_SPACES();
		left = pos;
		pos = ident_pos(is_attr_first, is_anumx);
		if (pos == left) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
		var key = substr();
		IGNORE_SPACES();
		var c = char(pos++);
		switch (c) {
		case "]".code:
			cur.attr.push(new Attrib(key, null, None));
		case "=".code,
			 "~".code,
			 "^".code,
			 "$".code,
			 "*".code,
			 "|".code:
			if (c != "=".code) {
				if (char(pos++) != "=".code) Error.exitWith(Expected, "=", pos - 1, ERR_POS);
			}
			var type = AttrType.ofInt(c);
			IGNORE_SPACES();
			c = char(pos++);
			left = pos;  // skip `'`, `"`
			switch (c) {
			case '"'.code:
				pos = until_pos(un_double_quote);
			case "'".code:
				pos = until_pos(un_single_quote);
			default:
				if (is_alpha_um(c)) {
					left = pos - 1;
					pos = until_pos(is_anum);
				} else {
					Error.exitWith(InvalidChar,charAt(pos - 1), pos - 1, ERR_POS);
				}
			}
			cur.attr.push(new Attrib(key, substr(), type)); // if pos == left then empty string("")
			c = char(pos);
			if (c == '"'.code || c == "'".code) ++pos;
			IGNORE_SPACES();
			c = char(pos++);
			if (c != "]".code) Error.exitWith(Expected, "]", pos - 1, ERR_POS);
		default:
			Error.exitWith(InvalidChar, charAt(pos - 1), pos - 1, ERR_POS);
		}
		return pos;
	}

	static function nth(str: String, pos: Int, max: Int, cur: CSSSelector, name: String): Int {
		var left = pos;

		inline function IGNORE_SPACES() pos = ignore_space(str, pos, max);
		inline function char(p) return str.fastCodeAt(p);
		inline function charAt(p) return str.charAt(p);
		inline function substr() return str.substr(left, pos - left);

		var n = 2, m = 1; // 2n + 1
		if (str.substr(pos, pos + 4).toLowerCase() == "even") {
			m = 0;        // 2n + 0
			pos += 4;
		} else if (str.substr(pos, pos + 3).toLowerCase() == "odd") {
			pos += 3;
		} else {          // .split("n") => [n, m]
			var x = 0;
			var minus = false;
			var c = char(pos);
			while (pos < max) {
				switch (x) {
				case 0:  // BEGIN
					switch (c) {
					case "n".code, "N".code:
						if (pos == left) {
							n = 1;
						} else {
							c = char(left);
							if (c == "-".code) {
								minus = true;
								++ left;
							} else if (c == "+".code) {
								minus = false;
								++ left;
							}
							if (pos == left) { // c == "-" || c == "+"
								n = 1;
							} else if (until(str, left, pos, is_number) == pos) {
								n = int(substr());
							} else {
								Error.exitWith(InvalidArgument, substr(), left, ERR_POS);
							}
							if (minus) n = -n;
						}
						x = 1;   // Go Next
					case ")".code:
						if (pos == left) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
						n = 0;
						c = char(left);
						if (c == "-".code) {
							minus = true;
							++left;
						} else if (c == "+".code) {
							minus = false;
							++left;
						}
						if (pos > left) {
							pos = until(str, left, pos, is_number);
							m = int(substr());
							if (minus) m = -m;
						} else {
							Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
						}
						max = 0;  // break loop
						continue;
					default:
						if (is_space(c) && char(ignore_space(str, pos, max)) != ")".code)
							Error.exitWith(UnexpectedWhitespace, charAt(pos - 1), pos - 1, ERR_POS);
					}
				case 1: // str[pos - 1] = 'n';
					IGNORE_SPACES();
					c = char(pos);
					if (c == ")".code) {
						m = 0;
					} else {
						if (c == "+".code) {
							minus = false;
						} else if (c == "-".code) {
							minus = true;
						} else {
							Error.exitWith(Expected, "+/-", pos, ERR_POS);
						}
						++ pos;
						IGNORE_SPACES();
						left = pos;
						pos = until(str, pos, max, is_number);
						if (pos == left) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
						m = int(substr()); // all is number
						if (minus) m = -m;
					}
					max = 0;  // break loop
					continue;
				default:
				}
				c = char(++pos);
			}
		}
		cur.pseudo.push(Nth(name, n, m));
		return pos;
	}

	// make sure all char is number and s != null and s != ""
	static function int(s: String): Int {
		var last = s.length;
		var r = 0;
		var mul = 1;
		while (last-- > 0) {
			r += (s.fastCodeAt(last) - "0".code) * mul;
			mul *= 10;
		}
		return r;
	}

	// for ":not( |single-selector| )".
	static function not(str: String, pos: Int, max: Int, cur: CSSSelector): Int {
		var left: Int;

		inline function char(p) return str.fastCodeAt(p);
		inline function charAt(p) return str.charAt(p);
		inline function substr() return str.substr(left, pos - left);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		var c = char(pos++);
		switch (c) {
		case ".".code:
			left = pos;
			pos = ident_pos(is_alpha_um, is_anum);
			if (pos == left) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
			cur.classes.push(substr());
		case "#".code:
			left = pos;
			pos = ident_pos(is_alpha_um, is_anum);
			if (pos == left) Error.exitWith(InvalidChar, charAt(pos), pos, ERR_POS);
			cur.id = substr();
		case "[".code:
			pos = on_attr(str, pos, max, cur);
			if (pos == -1) return -1;
		case ":".code:
			pos = on_pseudo(str, pos, max, cur);
			if (pos == -1) return -1;
		default:
			if (is_alpha_u(c)) {
				left = pos - 1;
				pos = until_pos(is_anum);
				cur.name = substr().toUpperCase();
			} else {
				Error.exitWith(InvalidChar,charAt(pos - 1), pos - 1, ERR_POS);
			}
		}
		return pos;
	}

	public static inline function is_attr_first(c: Int) {
		return is_alpha_u(c) || c == ":".code;
	}

	public static inline function un_double_quote(c) { return c != '"'.code; }
	public static inline function un_single_quote(c) { return c != "'".code; }

	public static var mp: haxe.DynamicAccess<Int> = {
		// psuedo classes
		"root"          : 1,
		"first-child"   : 1,
		"last-child"    : 1,
		"only-child"    : 1,
		"first-of-type" : 1,
		"last-of-type"  : 1,
		"only-of-type"  : 1,
		"empty"         : 1,
		"checked"       : 1,
		"disabled"      : 1,

		"enabled"       : 0,
		"link"          : 0,    // NOEffect
		"visited"       : 0,
		"hover"         : 0,
		"active"        : 0,
		"focus"         : 0,
		"target"        : 0,
		"first-letter"  : 0,
		"first-line"    : 0,
		"before"        : 0,
		"after"         : 0,
		"selection"     : 0,

		// psuedo elements
		"lang"             : 3, // Effect | Elements
		"not"              : 3,
		"nth-child"        : 3,
		"nth-last-child"   : 3,
		"nth-of-type"      : 3,
		"nth-last-of-type" : 3,
	}
}
