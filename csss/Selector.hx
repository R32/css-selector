package csss;

import csss.CValid.*;
using StringTools;

@:enum extern abstract ChildType(Int) to Int {
	var None    = 0;
	var Space   = " ".code;
	var Child   = ">".code;
	var Adjoin  = "+".code;
	var Sibling = "~".code;
	@:allow(csss.Selector) private static inline function ofInt(n: Int):ChildType return cast n;
}

@:enum extern abstract AttrType(Int) to Int {
	var None   = 0;  // [title]
	var Eq     = "=".code;
	var Wave   = "~".code;
	var Xor    = "^".code;
	var Dollar = "$".code;
	var All    = "*".code;
	var Or     = "|".code;
	@:allow(csss.Selector) private static inline function ofInt(i: Int):AttrType return cast i;
}

@:enum extern abstract PClsType(Int) to Int {
	var Root        =  1;
	var FirstChild  =  2;
	var LastChild   =  3;
	var OnlyChild   =  4;
	var FirstOfType =  5;
	var LastOfType  =  6;
	var OnlyOfType  =  7;
	var Empty       =  8;
	var Checked     =  9;
	var Disabled    = 10;
	@:allow(csss.Selector) private static inline function ofInt(i: Int):PClsType return cast i;
}

@:enum extern abstract PElemType(Int) to Int {
	var NthChild       = 103;
	var NthLastChild   = 104;
	var NthOfType      = 105;
	var	NthLastOfType  = 106;
	@:allow(csss.Selector) private static inline function ofInt(i: Int):PElemType return cast i;
}

enum PElem {
	Classes(name: PClsType);
	Lang(s: String);
	Not(sc: Selector);
	Nth(name: PElemType, n: Int, m: Int);
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

enum Filter {
	Name(name: String);
	Id(s: String);
	Cls(c: String);
	Attr(a: Attrib);
	PSU(p: PElem);
}

class Selector {
	public var name: String;
	public var id: String;
	public var sub: Selector;
	public var ctype: ChildType;
	public var classes: Array<String>;
	public var pseudo: Array<PElem>;
	public var attr: Array<Attrib>;
	public var fs: Array<Filter>;

	public function new(ct) {
		name = "";
		id = null;
		sub = null;
		ctype = ct;
		classes = [];
		pseudo = [];
		attr = [];
		fs = null;
	}

	public function have() { // notEmpty
		return name != "" || classes.length > 0 || (id != null && id != "") || attr.length > 0 || pseudo.length > 0;
	}

	public inline function toString(): String {
		return SelectorTools.toString(this);
	}

	public function calcFilters(): Array<Filter> {
		while (fs == null) {
			fs = [];
			if (id != null && id != "") fs.push( Id(id) );
			if (name != "") fs.push(Name(name));
			for (p in pseudo) fs.push(PSU(p));
			for (s in classes) fs.push(Cls(s));
			for (a in attr) fs.push(Attr(a));
		}
		return fs;
	}

	public static var errno(default, null): Error;

	public static function parse(s: String): Array<Selector> {
		var list: Array<Selector> = [];
		if (s != null && s != "") {
			list.push(new Selector(None));
			errno =	doParse(s, 0, s.length, list[0], list);
			var errmsg = switch (errno.type) {
			case None: null;
			case InvalidChar: 'InvalidChar: ${s.charAt(errno.pos)}, pos: ${errno.pos}';
			case InvalidSelector: 'InvalidSelector: ${s.substr(errno.pos, errno.len)}, pos: ${errno.pos}';
			case Expected: 'Expected: ${String.fromCharCode(errno.len)}, pos: ${errno.pos}';
			case InvalidArgument: 'InvalidArgument: ${s.substr(errno.pos, errno.len)}, pos: ${errno.pos}';
			}
			if (errmsg != null) {
				list = [];
			#if sys
				Sys.println("css parse error: " + errmsg);
			#elseif js
				js.Syntax.code("console.log({0})", "css parse error: " + errmsg);
			#end
			}
		}
		return list;
	}

	static function doParse(str: String, pos: Int, max: Int, cur: Selector, list: Array<Selector>): Error {
		inline function char(p) return str.fastCodeAt(p);

		var left: Int;
		var c: Int;
		var ctype: ChildType = None;
		var err:Error = Empty;
		pos = ignore_space(str, pos, max);

		if (char(pos) == "*".code) {
			cur.name = "*";
			++ pos;
		}

		while (pos < max) {
			c = char(pos++);
			switch (c) {
			case ".".code:
				left = pos;
				pos = ident(str, left, max, is_alpha_um, is_anum);
				if (left == pos) return Error.exit(InvalidChar, pos, 1);
				cur.classes.push(str.substr(left, pos - left));
			case "#".code:
				left = pos;
				pos = ident(str, left, max, is_alpha_um, is_anum);
				if (left == pos) return Error.exit(InvalidChar, pos, 1);
				cur.id = str.substr(left, pos - left);
			case "[".code:
				err = on_attr(str, pos, max, cur);
				if (err.type != None) return err;
				pos = err.pos;
			case ":".code:
				err = on_pseudo(str, pos, max, cur);
				if (err.type != None) return err;
				pos = err.pos;
			case ",".code:
				if (!cur.have()) return Error.exit(InvalidChar, pos - 1, 1);
				cur = new Selector(None);
				list.push(cur);
				pos = ignore_space(str, pos, max);
			case " ".code, "\t".code:
				ctype = Space;
				pos = ignore_space(str, pos, max);
				if (pos < max) {
					c = char(pos);
					if (!(c == ",".code || c == ">".code || c == "+".code || c == "~".code)) {
						cur.sub = new Selector(ctype);
						cur = cur.sub;
						ctype = None;
					}
				}
			case ">".code,
				 "+".code,
				 "~".code:
				if (!(ctype == None || ctype == Space) || !cur.have())
					return Error.exit(InvalidChar, pos - 1, 1);
				ctype = ChildType.ofInt(c);
				pos = ignore_space(str, pos, max);
				cur.sub = new Selector(ctype);
				cur = cur.sub;
				ctype = None;
			default:
				if (is_alpha_u(c) && cur.name != "*") {
					left = pos - 1;
					pos = until(str, pos, max, is_anum);
				#if NO_UPPER
					cur.name = str.substr(left, pos - left);
				#else
					cur.name = str.substr(left, pos - left).toUpperCase();
				#end
				} else {
					return Error.exit(InvalidChar, pos - 1, 1);
				}
			}
		}
		return Error.non(pos);
	}

	// str[pos-1] == ":"
	static function on_pseudo(str: String, pos: Int, max: Int, cur: Selector): Error {
		inline function char(p) return str.fastCodeAt(p);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		if (char(pos) == ":".code) ++pos; // skip ::
		var left = pos;
		pos = until_pos(is_alpha_um);
		if (left == pos) return Error.exit(InvalidChar, pos, 1);
		var name = str.substr(left, pos - left);
		var type = mpsu.get(name);
		if (type == null) return Error.exit(InvalidSelector, left, pos - left);  // name exists
		var c = char(pos);
		var err: Error = Empty;
		if (c == "(".code) {
			pos = ignore_space(str, pos + 1, max);
			switch (name) {
			case "lang":
				left = pos;
				pos = ident_pos(is_alpha_um, is_anum);
				if (pos == left) return Error.exit(InvalidChar, pos, 1);
				cur.pseudo.push(Lang(str.substr(left, pos - left)));
			case "not": // TODO
				var no = new Selector(None);
				err = psnot(str, pos, max, no);
				if (err.type != None) return err;
				pos = err.pos;
				cur.pseudo.push(Not(no));
			default:
				if (name.substr(0, 3) == "nth") {
					err = nth(str, pos, max, cur, PElemType.ofInt(type));
					if (err.type != None) return err;
					pos = err.pos;
				} else {
					return Error.exit(InvalidSelector, left, pos - left);
				}
			}
			pos = ignore_space(str, pos, max);
			if (char(pos) != ")".code) return Error.exit(Expected, pos, ")".code);
			++ pos;
		} else {
			cur.pseudo.push(Classes( PClsType.ofInt(type)));
		}
		return Error.non(pos);
	}
	// str[pos-1] == "["
	static function on_attr(str: String, pos: Int, max: Int, cur: Selector): Error {
		inline function char(p) return str.fastCodeAt(p);
		inline function ident_pos(first, rest) return ident(str, pos, max, first, rest);
		inline function until_pos(callb) return until(str, pos, max, callb);

		pos = ignore_space(str, pos, max);
		var left = pos;
		pos = ident_pos(is_attr_first, is_anumx);
		if (pos == left) return Error.exit(InvalidChar, pos, 1);
		var key = str.substr(left, pos - left);
		pos = ignore_space(str, pos, max);
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
				if (char(pos++) != "=".code) return Error.exit(Expected, pos - 1, "=".code);
			}
			var type = AttrType.ofInt(c);
			pos = ignore_space(str, pos, max);
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
					return Error.exit(InvalidChar, pos - 1, 1);
				}
			}
			cur.attr.push(new Attrib(key, str.substr(left, pos - left), type)); // if pos == left then empty string("")
			c = char(pos);
			if (c == '"'.code || c == "'".code) ++pos;
			pos = ignore_space(str, pos, max);
			c = char(pos++);
			if (c != "]".code) return Error.exit(Expected, pos - 1, "]".code);
		default:
			return Error.exit(InvalidChar, pos - 1, 1);
		}
		return Error.non(pos);
	}

	static function nth(str: String, pos: Int, max: Int, cur: Selector, type: PElemType): Error {
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
						t = int(str.substr(left, pos - left));
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
		cur.pseudo.push(Nth(type, n, m));
		return Error.non(pos);
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
	static function psnot(str: String, pos: Int, max: Int, cur: Selector): Error {
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
			cur.classes.push(str.substr(left, pos - left));
		case "#".code:
			left = pos;
			pos = ident_pos(is_alpha_um, is_anum);
			if (pos == left) return Error.exit(InvalidChar, pos, 1);
			cur.id = str.substr(left, pos - left);
		case "[".code:
			err = on_attr(str, pos, max, cur);
			if (err.type != None) return err;
			pos = err.pos;
		case ":".code:
			err = on_pseudo(str, pos, max, cur);
			if (err.type != None) return err;
			pos = err.pos;
		default:
			if (is_alpha_u(c)) {
				left = pos - 1;
				pos = until_pos(is_anum);
			#if NO_UPPER
				cur.name = str.substr(left, pos - left);
			#else
				cur.name = str.substr(left, pos - left).toUpperCase();
			#end
			} else {
				return Error.exit(InvalidChar, pos - 1, 1);
			}
		}
		return Error.non(pos);
	}

	public static inline function is_attr_first(c: Int) {
		return is_alpha_u(c) || c == ":".code;
	}

	public static inline function un_double_quote(c) { return c != '"'.code; }
	public static inline function un_single_quote(c) { return c != "'".code; }

	public static var mpsu: haxe.DynamicAccess<Int> = {
		// psuedo classes
		"root"          :  1,
		"first-child"   :  2,
		"last-child"    :  3,
		//"only-child"    :  4,
		//"first-of-type" :  5,
		//"last-of-type"  :  6,
		//"only-of-type"  :  7,
		"empty"         :  8,
		"checked"       :  9,
		"disabled"      : 10,
		// psuedo elements
		"lang"             : 101,
		"not"              : 102,
		"nth-child"        : 103,
		//"nth-last-child"   : 104,
		//"nth-of-type"      : 105,
		//"nth-last-of-type" : 106,
	}
}
