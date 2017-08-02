package test;

import csse.CSSSelector;

class Test {

	static function main() {
		var c1 = "a li#uniq.btn.btn-primary:nth-child(n+1)[title][name^=hello], div > span:not(first-child)";
		var list = CSSSelector.parse(c1);
		if (list == null) return;
		var s = [for (c in list) c.toString()].join(", ");
		trace(s);
	}
}