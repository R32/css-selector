package csss;

import csss.Selector;

#if !macro
enum abstract Token(Int) to Int {
	var Eof = 0;

	var TClass;          // .abc
	var TId;             // #abc
	var TSelector;       // :first-child
	var TSelectorDb;     // ::first-child

	var CIdent;
	var CInt;
	var CString;

	var OpGt;            // >   Child
	var OpAdd;           // +   Adjoin
	var OpBits;          // ~   Sibling
	var OpSub;           // -

	var OpMul;           // * (for tagName)
	var Comma;           // ,
	var LBracket;        // [   AttributeStart
	var RBracket;        // ]
	var LParen;          // (
	var RParen;          // )

	var OpAssign;        // = https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors
	var OpAssignBits;    // ~= split by space
	var OpAssignXor;     // ^= startWith
	var OpAssignDollar;  // $= endWith
	var OpAssignMul;     // *= if contain
	var OpAssignOr;      // |= eq or can begin with value immediately followed by "-"

	var TLang;           // :lang("zh-cn")
	var TNot;            // :not(selector)
	var Char_N;          // 2n, +2n, n,
	var TNthChild;       // :nth-child
	var TNthLastChild;   // :nth-last-child
	var TNthOfType;      // :nth-last-of-type
	var TNthLastOfType;  // :nth-of-type
}

@:rule(Eof, 127) class Lexer implements lm.Lexer<Token> {
	static var ident = "-?[a-zA-Z_][-a-zA-Z0-9_]*";
	static var integer = "[0-9]+";

	static var tok = [
		"[ \t\r\n]+" => lex.token(),
		"[-+]?[nN]"  => Char_N,
		"."     => lex.expect(TClass),
		"#"     => lex.expect(TId),
		":"     => lex.expect(TSelector),
		"::"    => lex.expect(TSelectorDb),
		ident   => CIdent,
		integer => CInt,

		">"     => OpGt,
		"+"     => OpAdd,
		"~"     => OpBits,
		"-"     => OpSub,

		"*"     => OpMul,
		","     => Comma,
		"["     => LBracket,
		"]"     => RBracket,
		"("     => LParen,
		")"     => RParen,

		"="     => OpAssign,
		"~="    => OpAssignBits,
		"^="    => OpAssignXor,
		"$="    => OpAssignDollar,
		"*="    => OpAssignMul,
		"|="    => OpAssignOr,

		'"' => {              // escape char are not supported
			var pmin = lex.pmin;
			var t = lex.str();
			if (t == Eof)
				throw lm.Utils.error("Unclosed " + "string" + lex.strpos(pmin));
			lex.pmin = pmin;  // union
			t;
		},
		"'" => {              // escape char are not supported
			var pmin = lex.pmin;
			var t = lex.qstr();
			if (t == Eof)
				throw lm.Utils.error("Unclosed " + "string" + lex.strpos(pmin));
			lex.pmin = pmin;  // union
			t;
		},
	];
	static var str = [
		'[^"]+' => lex.str(),
		'"'     => CString,
	];
	static var qstr = [
		"[^']+" => lex.qstr(),
		"'"     => CString,
	];

	public function expect(t: Token) {
		var prevPmin = this.pmin;
		var prevPmax = this.pmax;
		var next = this.token();
		if (next != CIdent || prevPmax != this.pmin)
			throw lm.Utils.error("Unexpected: " + this.current + lm.Utils.posString(this.pmin, this.input));
		if (t == TSelector)	{
			switch(this.current) {
			case "lang":                t = TLang;
			case "not":                 t = TNot;
			case "nth-child":           t = TNthChild;
			case "nth-last-child":      t = TNthLastChild;
			case "nth-of-type":         t = TNthLastOfType;
			case "nth-last-of-type":    t = TNthOfType;
			default:
			}
		}
		this.pmin = prevPmin;
		return t;
	}

	function strpos(p:Int):String {
		var line = 1;
		var char = 0;
		var i = 0;
		while (i < p) {
			var c = input.readByte(i++);
			if (c == "\n".code) {
				char = 0;
				++ line;
			} else {
				++ char;
			}
		}
		return " at line: " + line + ", char: " + char;
	}
}

class LRParser implements lm.LR0<Lexer, Array<QList>> {

	public static function parse(s: String) {
		var lex = new Lexer( lms.ByteData.ofString(s) );
		var par = new LRParser( lex );
		return par.begin();
	}

	static function combine(a: Array<QList>): QList {
		var s1 = a[0];
		for (i in 1...a.length) {
			s1.sub = a[i];
			s1 = a[i];
		}
		return a[0];
	}

	static function ntype(s, t, tk: Token):NthType {
		return switch(tk){
		case TNthChild:      NthChild;
		case TNthLastChild:  NthLastChild;
		case TNthOfType:     NthOfType;
		case TNthLastOfType: NthLastOfType;
		case _:              throw s.UnExpected(t);
		}
	}

	static function getNM(s, t, str: String, single:Bool): {n:Int, m:Int} {
		if (single) {
			if (str == "even")
				return {n: 2, m: 0}; // 2n + 0
			else if (str == "odd")
				return {n: 2, m: 1}; // 2n + 1
		}
		// HACK 1, since "-n-2, n-2, -n-, n-" will be parsed as CIdent
		var ret = {n: 1, m: 0};
		var i = 0;
		var c = StringTools.fastCodeAt(str, i);
		if (c == "-".code) {
			ret.n = -1;
			c = StringTools.fastCodeAt(str, ++i);
		}
		if (c == "n".code || c == "N".code) {
			c = StringTools.fastCodeAt(str, ++i);
			if (c == "-".code) {
				++i;
				if (single) {
					if (str.length > i) {
						var x:Null<Int> = Std.parseInt(str.substr(i, str.length - i));
						if (x != null) {
							ret.m = -x;
							return ret;
						}
					}
				} else if (i == str.length) {
					return ret;
				}
			}
		}
		throw s.UnExpected(t);
	}

	static inline function valid(s, t, fail) if (fail) throw s.UnExpected(t);

	// ofString definetions
	@:rule(CIdent)      static inline function _s1(s       ):String return s;
	@:rule(CInt)        static inline function _s2(s       ):Int    return Std.parseInt(s);
	@:rule(CString)     static inline function _s3(input, t):String return input.readString(t.pmin + 1, t.pmax - t.pmin - 2);
	@:rule(TClass, TId, TNth, TSelector
	)                   static inline function _s4(input, t):String return input.readString(t.pmin + 1, t.pmax - t.pmin - 1);
	@:rule(TSelectorDb) static inline function _s5(input, t):String return input.readString(t.pmin + 2, t.pmax - t.pmin - 2);
	@:rule(Char_N)      static inline function _s6(s       ):Int    return StringTools.fastCodeAt(s, 0) == "-".code ? -1 : 1;

	// %start begin
	static var begin = switch(s) {
		case [l = list, Eof]:                       l;
		case [Eof]:                                 [];
	}

	static var list = switch (s) {
		case [l = list, Comma, a = aque]:           l.push( combine(a) ); l;
		case [a = aque]:                            [ combine(a) ];
	}

	// NOTE: need to combine
	static var aque = switch(s) {
		case [a = aque, i = item]:
			if (_t1.pmax == _t2.pmin) {
				a[a.length - 1].add(i);
			} else {
				a.push( QList.one(Space, i) );
			}
			a;
		case [a = aque, op = [">", "+", "~"], i = item]:
			var opt = switch(op) {
				case OpGt:   Child;
				case OpAdd:  Adjoin;
				case _:      Sibling;
			}
			a.push(QList.one(opt, i)); a;
		case [i = item]:
			[QList.one(None, i)];
	}

	static var item: QItem = switch(s) {
		case [CIdent(i)]:                           QNode(i);
		case [TClass(c)]:                           QClass(c);
		case [TId(i)]:                              QId(i);
		case ["[", CIdent(i), "]"]:                 QAttr(new Attr(i, null, ANone));
		case [TSelector(p)]:                        QPseudo( PSelector(p) );
		case [TSelectorDb(p)]:                      QPseudo( PSelectorDb(p) );
		case [TLang, "(", CIdent(i) ,")"]:          QPseudo( PLang(i) );
		case [TNot, "(", i = item ,")"]:            QPseudo( PNot(i) );
		case [tk = [TNthChild, TNthLastChild, TNthOfType, TNthLastOfType], "(", x = nth_nm , ")"]:
			QPseudo( PNth(ntype(s, _t1, tk), x.n, x.m));
		case ["[", CIdent(i), op = ["=", "~=", "^=", "$=", "*=", "|="], v = value, "]"]:
			var t = switch(op) {
				case OpAssign:       AEq;
				case OpAssignBits:   AWave;
				case OpAssignXor:    AXor;
				case OpAssignDollar: ADollar;
				case OpAssignMul:    AMul;
				case _:              AOr;
			}
			QAttr(new Attr(i, v, t));
	}
	static var value: String = switch(s) {
		case [CIdent(i)]:                           i;
		case [CString(x)]:                          x;
	}
	// e.g: (2n + 1), (2n), (1)
	static var nth_nm: {n:Int, m:Int} = switch(s) {
		case [n = nth_n]:                           {n: n, m: 0};
		case [CInt(m)]:                             {n: 0, m: m};
		case [n = nth_n, op = ["+", "-"], CInt(m)]: valid(s, _t3, m < 0); {n: n, m: op == OpAdd ? m : -m};
		case [CIdent(i)]:                           getNM(s, _t1, i, true);   // HACK 1, "-n-2" , "n-2"
		case [CIdent(_), CIdent(_)]:                throw s.UnExpected(_t2);  // HACK 1, "-n- x" , "n- x"
		case [CIdent(i), CInt(m)]:                                            // HACK 1, "-n- 2", "n- 2"
			var x = getNM(s, _t1, i, false);
			x.m = -m;
			x;
	}

	static var nth_n: Int = switch(s) {
		case [CInt(n), Char_N(_)]:                  valid(s, _t2, s.str(_t2).length > 1); n;
		case [Char_N(n)]:                           n;
		case [op = ["+", "-"], CInt(n), Char_N(_)]:
			valid(s, _t2, _t1.pmax != _t2.pmin);
			valid(s, _t3, _t2.pmax != _t3.pmin || s.str(_t3).length > 1);
			op == OpAdd ? n : -n;
	}
}
#else
@:dce class Parser{}
#end