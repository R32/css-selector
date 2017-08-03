package test;

import csse.CSSSelector;
import csse.Xml;
import csse.xml.Parser;

class Test {

	static function main() {
		t1();
		t2();
	}
	static function t1() {
		var c1 = "a li#uniq.btn.btn-primary:nth-child(-0n+1)[title][name^=hello], div:first-child > span:not(.abc)";
		var list = CSSSelector.parse(c1);
		if (list == null) return;
		var s = [for (c in list) c.toString()].join(", ");
		trace(s);
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