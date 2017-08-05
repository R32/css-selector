package test;

import csss.Selector;
import csss.Xml;
import csss.xml.Parser;
import csss.Query;

class Test {

	static function main() {
		t1();
		t2();
	}
	static function t1() {
		var a = [
			"a li#uniq.btn.btn-primary[title][name^=hello]:empty",
			"a span, a li:not(:first-child) > span[title]:",
			"a.btn:nth-child( -201 )",
			":nth-child(-n+01)",
			":nth-child(-0n+20)", //
			":nth-child(+0n+003)", //
			":nth-last-child(0n - 40)",
			":nth-last-child(+210n + 50)",
			":nth-last-child(n)",
		];
		for (sel in a) {
			var list = Selector.parse(sel);
			if (list == null) return;
			var s = [for (c in list) c.toString()].join(", ");
			trace(s);
		}
	}

	macro static function t2() {
		var myxml = "bin/index.html";
		var file = sys.io.File.getContent(myxml);

		var html = Parser.parse(file, false).firstElement();

		var body = html.elementsNamed("body").next();
		var bclasses = body.get("class");
		if (bclasses.value != "xxx") {
			var pos = haxe.macro.PositionTools.make({
				min: bclasses.pos,
				max: bclasses.pos + bclasses.value.length,
				file: myxml}
			);
			haxe.macro.Context.error("click this message to location where the error occurred.", pos);
		}
		return macro null;
	}
}