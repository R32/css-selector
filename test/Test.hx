package test;

import csss.xml.Parser;
import csss.xml.Xml;
import csss.Selector;
import csss.NM;
import csss.Path;
using csss.Query;

class Test {

	static function union(a: Array<Int>, b: Array<Int>): String {
		var x = NM.union(new NM(a[0], a[1]), new NM(b[0], b[1]));
		return '(${a[0]}n+${a[1]}) U (${b[0]}n+${b[1]}) = ' + (x == null ? null : x.toString());
	}

	static function t3() {
		trace(union([2, 6], [4, 2]));
		trace(union([3, 5], [3, 3]));
		trace(union([2, 3], [3, 2]));
		trace(union([2, 329], [3, 22]));
		trace(union([7, 9], [15, 22]));
		var n1 = new csss.NM( -2, 10); var n1c = PNM.ofNM(n1);
		var n2 = new csss.NM( -3, 10); var n2c = PNM.ofNM(n2);
		trace("nth-child(" + n1.toString() + ") => nth-child(" + n1c + ")["+ n1c.max +"]");
		trace("nth-child(" + n2.toString() + ") => nth-child(" + n2c + ")["+ n2c.max +"]");
		bLog("nth-child", n1); bLog("nth-child", n1c);
		bLog("nth-child", n2); bLog("nth-child", n2c);


		var l1 = new NM(2, 1); var l1c = PNM.ofLastNM(l1, 10);
		var l2 = new NM(3, 2); var l2c = PNM.ofLastNM(l2, 10);
		trace("nth-last-child(" + l1.toString() + ") => nth-child(" + l1c + ")["+ l1c.max +"]");
		trace("nth-last-child(" + l2.toString() + ") => nth-child(" + l2c + ")["+ l2c.max +"]");
		bLog("nth-last-child", l1); bLog("nth-child", l1c);
		bLog("nth-last-child", l2); bLog("nth-child", l2c);

		var ln1 = new NM(-2, 6); var ln1c = PNM.ofLastNM(ln1, 10);
		var ln2 = new NM(-3, 5); var ln2c = PNM.ofLastNM(ln2, 10);
		trace("nth-last-child(" + ln1.toString() + ") => nth-child(" + ln1c + ")["+ ln1c.max +"]");
		trace("nth-last-child(" + ln2.toString() + ") => nth-child(" + ln2c + ")[" + ln2c.max +"]");
		bLog("nth-last-child", ln1); bLog("nth-child", ln1c);
		bLog("nth-last-child", ln2); bLog("nth-child", ln2c);
	}

	static function bLog(nths, nthc) {
	#if js
		js.Browser.console.log(
			'$nths(${nthc.toString()}): \t',
			js.Browser.document.querySelectorAll("div.selector-test p:" + nths + "(" + nthc +")")
		);
	#end
	}

	static function main() {
		//t1();
		//t2();
		//t3();
		t4();
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

	static function t4() @:privateAccess {
		var txt = haxe.Resource.getString("myxml");
		var html = csss.xml.Parser.parse(txt).firstElement();
		var body = html.elementsNamed("body").next();
		var selector = "#uniq";
		trace('run body.querySelector("$selector")...');
		var x = html.querySelector(selector);
		trace("find: " + x);

		#if js
		js.Lib.global.qq = function(str: String) {
			trace('run body.querySelector("$str")...');
			var x = body.querySelector(str);
			var s = "";
			for (k in x.attributes()) {
				if (k.charCodeAt(0) != ":".code)
					s += ' $k="${x.get(k)}"';
			}
			trace("<"+ x.nodeName + s + ">");
		}

		js.Lib.global.qa = function(str: String) {
			trace('run body.querySelectorAll("$str")...');
			var a = body.querySelectorAll(str);
			for (x in a) {
				var s = "";
				for (k in x.attributes()) {
					if (k.charCodeAt(0) != ":".code)
						s += ' $k="${x.get(k)}"';
				}
				trace("<"+ x.nodeName + s + ">");
			}
		}
		#end
	}

	macro static function t2() {
		var myxml = "bin/index.html";
		var file = sys.io.File.getContent(myxml);

		var html = Parser.parse(file, false).firstElement();

		var body = html.elementsNamed("body").next();
		var bclass = body.get("class");
		if (bclass != "xxx") {
			var p = body.attrPos("class");
			var pos = haxe.macro.PositionTools.make({
				min: p,
				max: p + bclass.length,
				file: myxml}
			);
			haxe.macro.Context.error("click this message to location where the error occurred.", pos);
		}
		return macro null;
	}
}