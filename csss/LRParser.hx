package csss;

import csss.Selector;

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

	var Nth_N;           //    [+-](INT)?[nN]?
	var Nth_M;           //    [+-] INT

	var OpAssign;        // = https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors
	var OpAssignBits;    // ~= split by space
	var OpAssignXor;     // ^= startWith
	var OpAssignDollar;  // $= endWith
	var OpAssignMul;     // *= if contain
	var OpAssignOr;      // |= eq or can begin with value immediately followed by "-"

	var TLang;           // :lang("zh-cn")
	var TNot;            // :not(selector)
	var TNthChild;       // :nth-child
	var TNthLastChild;   // :nth-last-child
	var TNthOfType;      // :nth-last-of-type
	var TNthLastOfType;  // :nth-of-type
	var TContains;       //
}

@:rule(Eof, 127) class Lexer implements lm.Lexer<Token> {
	static var ident = "[-a-zA-Z_][-a-zA-Z0-9_]*";
	static var integer = "[1-9][0-9]*";

	static var tok = [
		"[ \t\r\n]+" => lex.token(),
//		"[-+]?[nN]"  => Char_N,
		"."     => lex.expect(TClass),
		"#"     => lex.expect(TId),
		":"     => lex.expect(TSelector),
		"::"    => lex.expect(TSelectorDb),
		ident   => CIdent,
		integer => CInt,
		"0"     => CInt,

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
				throw("Unclosed " + "string" + lex.strpos(pmin));
			lex.pmin = pmin;  // union
			t;
		},
		"'" => {              // the escape chars are not supported
			var pmin = lex.pmin;
			var t = lex.qstr();
			if (t == Eof)
				throw("Unclosed " + "string" + lex.strpos(pmin));
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

	// used for :nth-child-xxxx(2n+1)
	static var nm_token = [
		"[ \t]+"           => lex.nm_token(),
		")"                => RParen,
		"[+-][ \t]+[0-9]+" => Nth_M,
		"[+-]?[0-9]+"      => CInt,
		"[+-]?[0-9]*[nN]"  => Nth_N,
		"[a-zA-Z]+"        => CIdent,  // even, odd
	];

	public function expect(t: Token) {
		var ppmin = this.pmin;
		var ppmax = this.pmax;
		var nxt = this.token();
		var success = false;
		if (nxt == CIdent && ppmax == this.pmin) {
			success = true;
			if (t == TSelector)	{
				switch(this.current) {
				case "lang":t = TLang;
				case "not": t = TNot;
				case "contains": t = TContains;
				case s: switch(s) {
					case "nth-child":        t = TNthChild;
					case "nth-last-child":   t = TNthLastChild;
					case "nth-of-type":      t = TNthLastOfType;
					case "nth-last-of-type": t = TNthOfType;
					default:
					}
					if (t != TSelector)
						success = getNM(this.pmax);
				}
			}
		}
		if (!success) throw("Unexpected: " + this.current + strpos(this.pmin));
		this.pmin = ppmin; // punion
		return t;
	}

	public var tmpNM: {n:Int, m:Int};

	function getNM(pmax) {
		var success = false;
		if (this.token() == LParen && this.pmin == pmax) {
			inline function next_token() { return this.nm_token(); }
			var t = next_token();
			var s = this.current;
			if (t == Nth_N) {
				this.tmpNM = {n: 1, m: 0};
				var left = 0;
				var c = s.charCodeAt(left);
				if (c == "-".code || c == "+".code) {
					if (c == "-".code) this.tmpNM.n = -1;
					++ left;
				}
				var right = s.length - 1;
				c = s.charCodeAt(right);
				if (c == "n".code || c == "N".code) --right;
				if (right >= left) {
					this.tmpNM.n *= Std.parseInt( s.substr(left, right - left + 1));
				}
				t = next_token();
				s = this.current;
				if (t == CInt && (s.charCodeAt(0) == "-".code || s.charCodeAt(0) == "+".code)) {
					t = Nth_M;
				}
				if (t == Nth_M) {
					this.tmpNM.m = s.charCodeAt(0) == "-".code ? -1 : 1;
					this.tmpNM.m *= Std.parseInt( s.substr(1, s.length - 1) );
					t = next_token();
				}
			} else if (t == CIdent && (s == "even" || s == "odd")) {
				this.tmpNM = s == "even" ? {n:2, m: 0} : {n:2, m: 1};
				t = next_token();
			} else if (t == CInt) {
				this.tmpNM = {n: 0, m: Std.parseInt( this.current )};
				t = next_token();
			} else {
				t = LParen; // let it fail
			}
			success = t == RParen;
		}
		return success;
	}

	inline function strpos(p:Int):String return lm.Utils.posString(p, this.input);
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

	static function singleQList(opt: Operator, i:QItem):QList {
		var q = new QList(opt);
		q.add(i);
		return q;
	}

	static inline function valid(s, t, fail) if (fail) throw s.UnExpected(t);

	// ofString definetions
	@:rule(CIdent)      static inline function _s1(s       ):String return s;
	@:rule(CInt)        static inline function _s2(s       ):Int    return Std.parseInt(s);
	@:rule(CString)     static inline function _s3(input, t):String return input.readString(t.pmin + 1, t.pmax - t.pmin - 2);
	@:rule(TClass, TId, TNth, TSelector
	)                   static inline function _s4(input, t):String return input.readString(t.pmin + 1, t.pmax - t.pmin - 1);
	@:rule(TSelectorDb) static inline function _s5(input, t):String return input.readString(t.pmin + 2, t.pmax - t.pmin - 2);

	// %start begin
	static var begin = switch(s) {
		case [l = list, Eof]:                       l;
		case [Eof]:                                 [];
	}

	static var list = switch (s) {
		case [l = list, Comma, a = aque]:           l.push( combine(a) ); l;
		case [a = aque]:                            [ combine(a) ];
	}

	static var aque = switch(s) {
		case [a = aque, i = item]:
			if (_t1.pmax == _t2.pmin) {
				a[a.length - 1].add(i);
			} else {
				a.push( singleQList(Space, i) );
			}
			a;
		case [a = aque, op = [">", "+", "~"], i = item]:
			var opt = switch(op) {
				case OpGt:   Child;
				case OpAdd:  Adjoin;
				case _:      Sibling;
			}
			a.push(singleQList(opt, i)); a;
		case [i = item]:
			[singleQList(None, i)];
	}

	static var attrval: String = switch(s) {
		case [CIdent(i)]:                           i;
		case [CString(x)]:                          x;
	}

	static var item: QItem = switch(s) {
		case ["*"]:                                 QNode("*");
		case [CIdent(i)]:                           QNode(i);
		case [TClass(c)]:                           QClass(c);
		case [TId(i)]:                              QId(i);
		case ["[", CIdent(i), "]"]:                 QAttr(new Attr(i, null, AExists));
		case [TSelector(p)]:                        QPseudo( PSelector(p) );
		case [TSelectorDb(p)]:                      QPseudo( PSelectorDb(p) );
		case [TLang, "(", v = attrval ,")"]:        QPseudo( PLang(v) );
		case [TNot, "(", i = item ,")"]:            QPseudo( PNot(i) );
		case [TContains, "(", v = attrval ,")"]:    QPseudo( PContains(v) );
		case [tk = [TNthChild, TNthLastChild, TNthOfType, TNthLastOfType]]:
			var v = switch(tk){
				case TNthChild:      NthChild;
				case TNthLastChild:  NthLastChild;
				case TNthOfType:     NthOfType;
				case _:              NthLastOfType;
			}
			var x = (cast @:privateAccess s.lex: Lexer).tmpNM; // HACK 0
			QPseudo( PNth(v, x.n, x.m ));
		case ["[", CIdent(i), op = ["=", "~=", "^=", "$=", "*=", "|="], v = attrval, "]"]:
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
}
