package;

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
		function union(a: Array<Int>, b: Array<Int>, ?result : String ) {
			var x = NM.union(new NM(a[0], a[1]), new NM(b[0], b[1]));
			//trace('(${a[0]}n+${a[1]}) U (${b[0]}n+${b[1]}) = ' + (x == null ? null : x.toString()));
			var s = x == null ? "null" : x.toString();
			eq(result == s);
		}
		union([2, 6], [4, 2], "4n+6");
		union([3, 5], [3, 3], "null");
		union([2, 3], [3, 2], "6n+5");
		union([2, 329], [3, 22], "6n+331");
		union([7, 9], [15, 22] , "105n+37");

		function convert(a, max, last, ?pos: haxe.PosInfos) {
			var nm = new NM(a[0], a[1]);
			var pnm = max > 0 ? PNM.ofLastNM(nm, max) : PNM.ofNM(nm);
			var sa = last ? "nth-last-child" : "nth-child";
		//	trace('$sa(${ nm.toString() }) => nth-child(${ pnm.toString() })[${pnm.max}]');
		#if js
			if (js.Syntax.code("'textContent' in document.documentElement")) { // simeple IE8 detection
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
		t3();
		t4();
	}
	static function t1() {
		var src = [
			"a li#uniq.btn.btn-primary[title][name^=hello]:empty",
			"a span:last-child, a li:not(:first-child) > span[title]",
			"a.btn:nth-child( -2n + 01 )",
			":nth-child(-n+01)",
			":nth-child(-0n+20)",
			":nth-child(+0n+003)",
			":nth-child( -0n+2 )",
			":nth-child( -n-2 )",
			"b~b+b:last-child>b",
			"b+b+b>b",
			"b,a li",
		];
		var dst = [
			'a li#uniq.btn.btn-primary[title][name^="hello"]:empty',
			'a span:last-child, a li:not(:first-child) > span[title]',
			'a.btn:nth-child(-2n+1)',
			':nth-child(-n+1)',
			':nth-child(20)',
			':nth-child(3)',
			':nth-child(2)',
			':nth-child(-n-2)',
			'b ~ b + b:last-child > b',
			'b + b + b > b',
			"b, a li",
		];
		for (i in 0...src.length) {
			var list = Selector.parse(src[i]);
			var s = [for (c in list) csss.SelectorTools.toString(c)].join(", ");
			//trace(s);
			eq(s == dst[i]);
		}
		var classEqual = @:privateAccess csss.Query.classEqual;
		if (!(classEqual("abc hi", "hi")
		&& classEqual("hi", "hi")
		&& classEqual(" hi ", "hi")
		&& !classEqual("hid", "hi")
		&& !classEqual(".hi", "hi")
		&& !classEqual("", "")
		&& !classEqual("hi", null)
		)) throw "Query.classEq Error...";
	}

	static function t4() @:privateAccess {
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
			trace("(" + a.length + ") [" + a.map(x->x.toSimpleString()).join(", ") + "]");
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

		// querySelector
		var selectors = [
			"div > div div",
			"div#t4 > div div",
			"b ~ b",
			"b + b",
			"b ~ b ~ b",
			"b + b + b",
			"b + b + b + b",
			"b ~ b ~ b ~ b",
			"div p a",
			"#t3 li ol span",
			"b, a",
		];
		for(s in selectors) {
			var x1 = csss.Query.one(html, s);
			var x2 = js.Browser.document.querySelector(s);
			var s1 = x1.toSimpleString();
			var s2 = DOMToString(x2);
			eq(s1.toLowerCase() == s2.toLowerCase());
		}
		// querySelectorAll
		var selectors = ["a", "div", "div p", "b + b + b", "b ~ b ~ b"];
		for(s in selectors) {
			var a1 = csss.Query.all(html, s);
			var a2 = js.Browser.document.querySelectorAll(s);
			eq(a1.length == a2.length);
			for(i in 0...a1.length) {
				var s1 = a1[i].toSimpleString();
				var s2 = DOMToString(cast a2[i]);
				eq(s1.toLowerCase() == s2.toLowerCase());
				//trace(s1, s2, s1.toLowerCase() == s2.toLowerCase());
			}
		}
		#end
	}

	static function DOMToString( node : js.html.Element ) {
		if (node == null)
			return "null";
		var id = node.id == "" ? "" : "#" + node.id;
		var cls = node.className == "" ? "" : ("." + node.className.split(" ").join("."));
		return '<${node.tagName}$id$cls>';
	}

	static function eq(b, ?pos: haxe.PosInfos) {
		if (!b) throw "Error Line: " + pos.lineNumber;
	}
}
