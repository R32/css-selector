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
		case None:   '[name]';
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
				var sn = n == 0 ? "n" : n + "n";
				var sm = m == 0 ? "" : (m > 0 ? "+" + m : "" + m);
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
		doParse(s, 0, s.length, list[0], list);
		if (Error.no < 0) {
		#if sys
			Sys.println(Error.str("CSSSelectorParse"));
		#else
			trace(Error.str("CSSSelectorParse"));
		#end
			Error.clear();
			return null;
		}
		return list;
	}

	static function doParse(str: String, pos: Int, max: Int, cur: CSSSelector, list: Array<CSSSelector>): Void {
		var aname = null;
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
						pos = until(str, pos + 1, max, is_anu);
						cur.name = str.substr(left, pos - left);
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
					var sub = new CSSSelector(rel);
					cur.sub = sub;
					doParse(str, pos, max, sub, list);
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
				if (pos == -1) return;
				state = RACE;
				continue;
			case ATTRIB:
				pos = on_attr(str, pos, max, cur);
				if (pos == -1) return;
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
		if (left == pos) Error.exit(InvalidChar, charAt(pos), pos, -1);
		var name = substr();
		if (!mp.exists(name)) Error.exit(InvalidSelector, name, left, -1);
		var c = char(pos);
		if (c == "(".code) {
			pos = ignore_space(str, pos + 1, max);
			switch (name) {
			case "lang":
				left = pos;
				pos = ident_pos(is_alpha_um, is_anum);
				if (pos == left) Error.exit(InvalidChar, charAt(pos), pos, -1);
				cur.pseudo.push(Lang(substr()));
			case "not": // TODO
				var no = new CSSSelector(None);
				pos = not(str, pos, max, no);
				if (pos == -1) return -1;
				cur.pseudo.push(Not(no));
			case "nth-child",
				 "nth-last-child",
				 "nth-of-type",
				 "nth-last-of-type":
				pos = nth(str, pos, max, cur, name);
				if (pos == -1) return -1;
			default:
				Error.exit(InvalidSelector, name, left, -1);
			}
			IGNORE_SPACES();
			if (char(pos++) != ")".code) Error.exit(InvalidChar, charAt(pos - 1), pos - 1, -1);
		} else {
			cur.pseudo.push(Classes(name));
		}
		return pos;
	}
	// str[pos-1] == "["
	static function on_attr(str: String, pos: Int, max: Int, cur: CSSSelector): Int {

		inline function IGNORE_SPACES() pos = ignore_space(str, pos, max);
		inline function char(p) return str.fastCodeAt(p);
		inline function charAt(p) return str.charAt(p);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		IGNORE_SPACES();
		var left = pos;
		pos = ident_pos(is_attr_first, is_anumx);
		if (pos == left) Error.exit(InvalidChar, charAt(pos), pos, -1);
		var key = str.substr(left, pos - left);
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
				if (char(pos++) != "=".code) Error.exit(Expected, "=", pos - 1, -1);
			}
			var type = AttrType.ofInt(c);
			IGNORE_SPACES();
			c = char(pos++);
			left = pos;  // skip `'`, `"`
			switch (c) {
			case '"'.code:
				pos = until_pos(function(c) { return c != '"'.code; } );
			case "'".code:
				pos = until_pos(function(c) { return c != "'".code; } );
			default:
				if (is_alpha_um(c)) {
					left = pos - 1;
					pos = until_pos(is_anum);
				} else {
					Error.exit(InvalidChar,charAt(pos - 1), pos - 1, -1);
				}
			}
			cur.attr.push(new Attrib(key, str.substr(left, pos - left), type)); // if pos == left then empty string("")
			c = char(pos);
			if (c == '"'.code || c == "'".code) ++pos;
			IGNORE_SPACES();
			c = char(pos++);
			if (c != "]".code) Error.exit(Expected, "]", pos - 1, -1);
		default:
			Error.exit(InvalidChar, charAt(pos - 1), pos - 1, -1);
		}
		return pos;
	}

	static function nth(str: String, pos: Int, max: Int, cur: CSSSelector, name: String): Int {
		var left = pos;

		inline function IGNORE_SPACES() pos = ignore_space(str, pos, max);
		inline function char(p) return str.fastCodeAt(p);
		inline function charAt(p) return str.charAt(p);
		inline function substr() return str.substr(left, pos - left);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		var n = 2, m = 1; // 2n + 1
		var c: Int;
		if (str.substr(pos, pos + 4).toLowerCase() == "even") {
			m = 0;        // 2n + 0
			pos += 4;
		} else if (str.substr(pos, pos + 3).toLowerCase() == "odd") {
			pos += 3;
		} else {          // .split("n") => [n, m]
			var plus = true;
			var x = 0;
			while (pos < max) {
				c = char(pos);
				switch (x) {
				case 0:  // BEGIN
					switch (c) {
					case "n".code, "N".code:
						if (pos == left) {
							n = 0;
						} else if (pos - 1 == left) {
							c = char(pos - 1);
							if (is_number(c)) {
								n = c - "0".code;
							} else if(c == "+".code || c == "-".code) {
								n = 0;
							} else {
								Error.exit(InvalidChar, charAt(pos - 1), pos - 1, -1);
							}
						} else {
							n = Std.parseInt(substr());
							if (n == null) Error.exit(InvalidArgument, substr(), left, -1);
						}
						x = 1;
					case ")".code:
						n = 0;
						if (pos == left) {
							Error.exit(InvalidChar, charAt(pos), pos, -1);
						} else if (pos - left == 1) {
							c = char(pos - 1);
							if (is_number(c)) {
								m = c - "0".code;
							} else {
								Error.exit(InvalidChar, charAt(pos - 1), pos - 1, -1);
							}
						} else {
							m = Std.parseInt(substr());
							if (m == null) Error.exit(InvalidArgument, substr(), left, -1);
						}
						break;
					default:
						if (is_space(c)) Error.exit(UnexpectedWhitespace, charAt(pos), pos, -1);
					}
				case 1: // str[pos - 1] = 'n';
					IGNORE_SPACES();
					c = char(pos);
					switch (c) {
					case "+".code,
						 "-".code:
						plus = c == "+".code;
						x = 2;
					case ")".code:
						m = 0;
						break;
					default:
						Error.exit(InvalidChar, charAt(pos), pos, -1);
					}
				case 2: // str[pos - 1] = '+' | '-';
					IGNORE_SPACES();
					left = pos;
					pos = until_pos(is_number);
					if (pos == left) Error.exit(InvalidChar, charAt(pos), pos, -1);
					if (pos - 1 == left) {
						c = char(pos - 1);
						m = c - "0".code;
					} else {
						m = Std.parseInt(substr());
					}
					if (!plus) m = -m;
					break;
				default:
				} // end switch(state)
			++ pos;
			}     // end white
		}
		cur.pseudo.push(Nth(name, n, m));
		return pos;
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
			if (pos == left) Error.exit(InvalidChar, charAt(pos), pos, -1);
			cur.classes.push(substr());
		case "#".code:
			left = pos;
			pos = ident_pos(is_alpha_um, is_anum);
			if (pos == left) Error.exit(InvalidChar, charAt(pos), pos, -1);
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
				cur.name = substr();
			} else {
				Error.exit(InvalidChar,charAt(pos - 1), pos - 1, -1);
			}
		}
		return pos;
	}

	public static inline function is_attr_first(c: Int) {
		return is_alpha_u(c) || c == ":".code;
	}

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
		"enabled"       : 1,
		"disabled"      : 1,
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

@:dce @:enum abstract PElemType(Int) to Int {
	var NOEffect  = 0;
	var Effect    = 1;
	var Elements  = 1 << 1;
}
