package csss;

import csss.Selector;

class SelectorTools {

	public static function toString(sel: Selector) {
		var name = sel.name;
		var id = sel.id;
		var sid = id == null || id == "" ? "" : '#$id';
		var sattr = sel.attr.length == 0 ? "" : [for (a in sel.attr) a.toString()].join("");
		var sclasses = sel.classes.length == 0 ? "" : '.${sel.classes.join(".")}';
		var spse = pse2str(sel);

		if (sel.sub != null) {
			var sctype = sel.sub.ctype == Space ? " " : (" " + String.fromCharCode(sel.sub.ctype) + " ");
			return '$name$sattr$sid$sclasses$spse$sctype${sel.sub.toString()}';
		} else {
			return '$name$sattr$sid$sclasses$spse';
		}
	}

	static function pse2str(sel: Selector): String {
		if (sel.pseudo.length == 0) return "";
		var sa = [""];
		var mpsu = Selector.mpsu;
		for (pe in sel.pseudo) {
			switch (pe) {
			case Classes(t):
				for (k in mpsu.keys()) {
					if (mpsu.get(k) == t) {
						sa.push(k);
						break;
					}
				}
			case Lang(s):
				sa.push('lang($s)');
			case Not(sc):
				sa.push('not(${sc.toString()})');
			case Nth(t, n, m):
				var s = switch (t) {
				case NthChild     : "nth-child";
				case NthLastChild : "nth-Last-child";
				case NthOfType    : "nth-of-type";
				case NthLastOfType: "nth-last-of-type";
				}
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
}