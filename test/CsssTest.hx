package test;

import csss.xml.Parser;
import csss.xml.Xml;
import csss.Selector;
import csss.NM;
import csss.Path;
using csss.Query;

class CsssTest {

	static function arrayEq<T>(a: Array<T>, b: Array<T>): Bool {
		if (a == b) return true;
		var len = a.length;
		if (len != b.length) return false;
		var i = 0;
		while (i < len) {
			if (a[i] != b[i]) return false;
			++ i;
		}
		return true;
	}

	static function t3() {
		trace("------ t3 ------");
		function union(a: Array<Int>, b: Array<Int>) {
			var x = NM.union(new NM(a[0], a[1]), new NM(b[0], b[1]));
			trace('(${a[0]}n+${a[1]}) U (${b[0]}n+${b[1]}) = ' + (x == null ? null : x.toString()));
		}
		union([2, 6], [4, 2]);
		union([3, 5], [3, 3]);
		union([2, 3], [3, 2]);
		union([2, 329], [3, 22]);
		union([7, 9], [15, 22]);

		function convert(a, max, last, ?pos: haxe.PosInfos) {
			var nm = new NM(a[0], a[1]);
			var pnm = max > 0 ? PNM.ofLastNM(nm, max) : PNM.ofNM(nm);
			var sa = last ? "nth-last-child" : "nth-child";
			trace('$sa(${ nm.toString() }) => nth-child(${ pnm.toString() })[${pnm.max}]');
		#if js
			if (untyped __js__("'textContent' in document.documentElement")) { // simeple IE8 detection
				var r0 = js.Browser.document.querySelectorAll('div.selector-test p:$sa(${ nm.toString() })');
				var r1 = js.Browser.document.querySelectorAll('div.selector-test p:nth-child(${ pnm.toString() })');
				//js.Browser.console.log('$sa(${nm.toString()}): \t', r0);
				//js.Browser.console.log('nth-child(${pnm.toString()}): \t', r1);
				if (!arrayEq(cast r0, cast r1)) js.Browser.console.error('Error Line: ${pos.lineNumber}');
			}
		#end
		}
		var max = 10; // document.querySelector('div.selector-test').children.length;
		convert([-2, max], 0, false);
		convert([-3, max], 0, false);
		convert([ 2, 1], max, true);
		convert([ 3, 2], max, true);
		convert([-2, 6], max, true);
		convert([-3, 5], max, true);
	}

	static function main() {
		t1();
		//t2();
		t3();
		t4();
	}
	static function t1() {
		trace("------ t1 ------");
		var a = [
			"a li#uniq.btn.btn-primary[title][name^=hello]:empty",
			"a span:last-child, a li:not(:first-child) > span[title]",
			"a.btn:nth-child( -2n + 01 )",
			":nth-child(-n+01)",
			":nth-child(-0n+20)",
			":nth-child(+0n+003)",
			":nth-child( -0n+2 )",
			":nth-child( -n-2 )",
			//":nth-last-child(0n - 40)",
			//":nth-last-child(+210n + 50)",
			//":nth-last-child(n)",
		];
		for (sel in a) {
			var list = Selector.parse(sel);
			var s = [for (c in list) c.toString()].join(", ");
			trace(s);
		}

		@:privateAccess { // Query.classVali
			if (!(
				   csss.Query.classVali("abc hi", "hi")
				&& csss.Query.classVali("hi", "hi")
				&& csss.Query.classVali(" hi ", "hi")
				&& !csss.Query.classVali("hid", "hi")
				&& !csss.Query.classVali(".hi", "hi")
				&& !csss.Query.classVali("", "")
				&& !csss.Query.classVali("hi", null)
			)) trace("Query.classVali Error...");
		}
	}

	static function t4() @:privateAccess {
		trace("------ t4 query ------");
		var txt = haxe.Resource.getString("myxml");
		var html = csss.xml.Parser.parse(txt).firstElement();
		var body = html.elementsNamed("body").next();
		#if js
		js.Lib.global.qq = function(str: String) {
			var x = html.querySelector(str);
			if (x == null) {
				trace(x);
			} else {
				trace(x.toSimpleString());
			}
		}

		js.Lib.global.qa = function(str: String) {
			var a = html.querySelectorAll(str);
			trace(a.map(x->x.toSimpleString()).join(", "));
		}

		var doc = html.parent;
		function sub(xml, top, ?pos: haxe.PosInfos) {
			var p = csss.Path.ofXml(xml, top);
			if (top == null) top = doc;
			if (p == null) {
				if (xml == top || top.contains(xml))
					js.Browser.console.error('Error Line: ${pos.lineNumber}');
			} else {
				eq(p.toXml(top) == xml);
			}
		}
		sub(html, null);
		sub(html, html);
		var st3 = html.one("#t3");
		sub(st3, html);
		sub(st3, null);
		sub(st3.one(".l2-3"), st3);
		sub(st3.one(".l2-3"), null);
		sub(st3.one(".L2-3-s"), st3);
		sub(st3.one(".L2-3-s"), null);
		sub(html.one("#uniq"), st3);
		//
		#end
	}

	static function eq(b, ?pos: haxe.PosInfos) {
		if (!b) throw "Error Line: " + pos.lineNumber;
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