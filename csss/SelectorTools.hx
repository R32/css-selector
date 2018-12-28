package csss;

import csss.Selector;

class SelectorTools {

	public static function toString(s: Selector):String {
		var ret = [];
		while (s != null) {
			var snode = s.node == null ? "" : s.node;
			var sid = s.id == null ? "" : "#" + s.id;
			var sattr = s.attries.length == 0 ? "" : [for (a in s.attries) s_attr(a)].join("");
			var sclasses = s.classes.length == 0 ? "" : "." + s.classes.join(".");
			var spseudo = s.pseudes.map(p -> s_pseudo(p)).join("");
			var sep = switch (s.opt) {
				case None:     "";
				case Space:    " ";
				case Child:    " " + ">" + " ";
				case Adjoin:   " " + "+" + " ";
				case Sibling:  " " + "~" + " ";
			}
			ret.push('$sep$snode$sid$sclasses$sattr$spseudo');
			s = s.sub;
		}
		return ret.join("");
	}

	public static function s_array(a: Array<Selector>):String {
		return a.map(s -> toString(s)).join(", ");
	}

	public static function s_attr(a:Attr): String {
		var name = a.name;
		var value = a.value;
		return switch (a.type) {
		case ANone:   '[$name]';
		case AEq:     '[$name="$value"]';
		case AWave:   '[$name~="$value"]';
		case AXor:    '[$name^="$value"]';
		case ADollar: '[$name$="$value"]';
		case AMul:    '[$name*="$value"]';
		case AOr:     '[$name|="$value"]';
		}
	}

	public static function s_qitem(i:QItem):String {
		return switch (i) {
		case QNode(s):       s;
		case QId(s):         "#" + s;
		case QClass(s):      "." + s;
		case QAttr(a):       s_attr(a);
		case QPseudo(p):     s_pseudo(p);
		}
	}

	public static function s_nthtype(t: NthType):String {
		return switch (t) {
		case NthChild:       "nth-child";
		case NthLastChild:   "nth-last-child";
		case NthOfType:      "nth-of-type";
		case NthLastOfType:  "nth-last-of-type";
		}
	}

	public static function s_nm(n:Int, m:Int):String {
		var sn = switch(n) {
		case -1: "-n";
		case  0: "";
		case  1: "n";
		case  _: n + "n";
		}
		var sm = m == 0 ? "" : ( m > 0 && n != 0 ? ("+" + m) : ("" + m) );
		return sn + sm;
	}

	public static function s_pseudo(p: Pseudo):String {
		return switch (p) {
		case PSelector(s):   ":"  + s;
		case PSelectorDb(s): "::" + s;
		case PLang(s):       ":" + "lang" + "(" + '"' + s + '"' + ")";
		case PNot(i):        ":" + "not"  + "(" + s_qitem(i) + ")";
		case PNth(t, n, m):  ":" + s_nthtype(t) + "(" + s_nm(n, m) + ")";
		}
	}
}