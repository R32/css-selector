package csss;

import csss.xml.Xml;
import csss.Selector;

@:enum private abstract State(Int) to Int {
	var None   = 0;
	var BreakCurrent = 1;  // No need to find current selector in xml but can find in xml.children.
	var NoNeed = 2;        // No need to find current selector in xml and xml.children
	var Invalid = 3;       // No need to find **current and next selector** in xml and xml.children.
}

#if NO_POS
@:access(Xml)
#else
@:access(csss.xml.Xml)
#end
class Query {

	var state: State;

	function new() { state = None; }

	function applyFilters(xml: Xml, fs: Array<Filter>, ei: Int): Bool {
		for (f in fs) {
			if (eq(xml, f, ei) == false) return false;
		}
		return true;
	}

	function eq(xml: Xml, filter: Filter, ei): Bool {
		var ret = false;
		var val: String;
		inline function strEq(s1: String, s2: String) return s1 != null && s1 != "" && s1 == s2;
		switch (filter) {
		case Name(n):
			ret = n == "*" || strEq(n, xml.nodeName);
		case Id(id):
			ret = strEq(id, xml.get("id"));
			if (ret) state = NoNeed;
		case Cls(c):
			ret = classVali(val = xml.get("class"), c);
		case Attr(a):
			val = xml.get(a.name);
			if (val == null) return false;
			var tval = StringTools.trim(val);
			switch (a.type) {
			case None:
				ret = true;
			case Eq:
				ret = a.value != null && val == a.value;  // without trim
			case Wave:    // ~
				ret = a.value != "" && tval.split("-").indexOf(a.value) != -1;
			case Xor:     // ^
				ret = a.value != "" && tval.indexOf(a.value) == 0;
			case Dollar:  // $
				ret = a.value != "" && tval.lastIndexOf(a.value) == tval.length - a.value.length;
			case All:     // *
				ret = a.value != "" && tval.indexOf(a.value) != -1;
			case Or:      // |
				ret = a.value != "" && tval.split("-").indexOf(a.value) == 0;
			}
		case PSU(pe):
			switch (pe) {
			case Classes(t):
				ret = eq_psuedo(xml, t, ei);
			case Lang(s):
				ret = strEq(xml.get("lang"), s);
			case Not(sel):
				if (sel.fs == null) sel.calcFilters();
				ret = sel.fs.length == 1 && eq(xml, sel.fs[0], ei) == false;
			case Nth(type, n, m):
				switch (type) {
				case NthChild:      ret = eq_nth(xml, ei, n, m);
				case NthLastChild,  // TODO Not Implemented
					 NthOfType,
					 NthLastOfType: ret = false;
				}
			}
		}
		return ret;
	}

	function eq_nth(xml: Xml, ei, n, m): Bool {
		++ ei;  // start at 1.
		if (n < 0) {
			if (m < 0) {
				state = Invalid;
				return false;
			}
			var pnm = NM.PNM.ofNM(new NM(n, m));
			return ei <= pnm.max && pnm.valid(ei);
		} else {
			return ei >= m && (ei - m) % n == 0;
		}
	}

	function eq_psuedo(xml: Xml, t: PClsType, ei): Bool {
		return switch (t) {
		case Root:
			state = NoNeed;
			xml.parent != null && xml.parent.nodeType == Document;
		case FirstChild:
			state = BreakCurrent;
			ei == 0;
		case LastChild:
			false; //ei == elen - 1;
		case OnlyChild:
			false; //ei == 0 && elen == 1;
		case FirstOfType:
			false; //ni == 0;
		case LastOfType:
			false;
		case OnlyOfType:
			false;
		case Empty:
			var b = true;
			for (child in xml.children) {
				if (child.nodeType != Comment) {
					b = false;
					break;
				}
			}
			b;
		case Checked:
			xml.exists("checked");
		case Disabled:
			xml.exists("disabled");
		}
	}

	function search(children: Array<Xml>, i: Int, max: Int, j: Int, sel: Selector, rec: Bool): Xml {
		if (sel.fs == null) sel.calcFilters();
		var fs = sel.fs;
		if (fs.length == 0) {
			state = Invalid;
			return null;
		}

		var xml: Xml;
		var ret = null;
		var succeed: Bool;
		var sib: Bool = false; // Sibling
		var adj: Bool = false; // Adjoin

		var prev: State;
		inline function saveState() { prev = state; state = None; }
		inline function resState() { state = prev; }

		var ctype: ChildType = sel.sub == null ? None : sel.sub.ctype;
		inline function not_sub_selector() { return ctype == None; }
		inline function has_sub_selector() { return ctype != None; }

		while (i < max) {
			xml = children[i];
			if (xml.nodeType == Element) {
				succeed = applyFilters(xml, fs, j);

				if (succeed && not_sub_selector())
					return xml;
				else if (sib || adj) {
					saveState();
					ret = search(children, i, i + 1, j, sel.sub, false); // TODO: i + 1
					if (ret != null) return ret;
					if (state == Invalid) break;
					resState();
				}

				adj = false;
				if (succeed && has_sub_selector()) {
					if (ctype == Space || ctype == Child) {
						saveState();
						// ctype == Space ? (E   F)  :  (E > F)
						ret = search(xml.children, 0, xml.children.length, 0, sel.sub, ctype == Space);
						if (ret != null) return ret;
						if (state == Invalid) break;
						resState();
					} else if (ctype == Adjoin) {
						adj = true;  // (E + F)
					} else if (!sib) {
						sib = true;  // (E ~ F)
					}
				}

				if (rec && (state: Int) < (NoNeed: Int)) { // recursive
					saveState();
					ret = search(xml.children, 0, xml.children.length, 0, sel, true);
					if (ret != null) return ret;
					if (state == Invalid) break;
					resState();
				}
				if (state != None) break;
				++ j;
			}
			++ i;
		}
		return ret;
	}

	function searchAll(out: Array<Xml>, children: Array<Xml>, i: Int, max: Int, j: Int, sel: Selector, rec: Bool): Void {
		if (sel.fs == null) sel.calcFilters();
		var fs = sel.fs;
		if (fs.length == 0) {
			state = Invalid;
			return null;
		}

		var xml: Xml;
		var succeed: Bool;
		var sib: Bool = false; // Sibling
		var adj: Bool = false; // Adjoin

		var prev: State;
		inline function saveState() { prev = state; state = None; }
		inline function resState() { state = prev; }

		var ctype: ChildType = sel.sub == null ? None : sel.sub.ctype;
		inline function not_sub_selector() { return ctype == None; }
		inline function has_sub_selector() { return ctype != None; }

		while (i < max) {
			xml = children[i];
			if (xml.nodeType == Element) {
				succeed = applyFilters(xml, fs, j);

				if (succeed && not_sub_selector()) {
					out.push(xml);
				} else if (sib || adj) {
					saveState();
					searchAll(out, children, i, i + 1, j, sel.sub, false); // TODO: looking for anather way instead of i + 1
					if (state == Invalid) break;
					resState();
				}

				adj = false;
				if (succeed && has_sub_selector()) {
					if (ctype == Space || ctype == Child) {
						saveState();
						// ctype == Space ? (E   F)  :  (E > F)
						searchAll(out, xml.children, 0, xml.children.length, 0, sel.sub, ctype == Space);
						if (state == Invalid) break;
						resState();
					} else if (ctype == Adjoin) {
						adj = true;  // (E + F)
					} else if (!sib) {
						sib = true;  // (E ~ F)
					}
				}

				if (rec && (state: Int) < (NoNeed: Int)) {
					saveState();
					searchAll(out, xml.children, 0, xml.children.length, 0, sel, true);
					if (state == Invalid) break;
					resState();
				}
				if (state != None) break;
				++ j;
			}
			++ i;
		}
	}

	static function classVali(s: String, v: String): Bool {
		if (s == null || s == "") return false;
		var c: Int;
		var pos = 0;
		var left = 0;
		var max = s.length;
		while (pos < max) {
			c = StringTools.fastCodeAt(s, pos);
			if (c == " ".code) {
				if (left == pos) {
					++ left;
				} else {
					if (s.substr(left, pos - left) == v) return true;
					left = pos + 1;
				}
			}
			++ pos;
		}
		if (left == 0)
			return s == v;
		else if (pos > left)
			return s.substr(left, pos - left) == v;
		else
			return false;
	}

	public static inline function querySelector(top: Xml, s: String): Xml {
		return one(top, s);
	}

	public static function one(top: Xml, s: String): Xml {
		var ret = null;
		if (top.nodeType != Document && top.nodeType != Element) return ret;
		var q = new Query();
		var sa = Selector.parse(s);
		if (sa.length == 0) return null;
		if (sa.length == 1) {
			return q.search(top.children, 0, top.children.length, 0, sa[0], true);
		} else {
			var r = [];
			for (sel in sa) {
				var x = q.search(top.children, 0, top.children.length, 0, sel, true);
				if (x != null)
					r.push(x);
			}
			if (r.length == 0)
				return null;
			else if (r.length == 1)
				return r[0];
			else {
				var p = [];
				for (x in r) {
					p.push(Path.ofXml(x, top));
				}
				p.sort(Path.PTools.onSort);
				return p[0].toXml(top);
			}
		}
	}

	public static inline function querySelectorAll(top: Xml, s: String): Array<Xml> {
		return all(top, s);
	}
	public static function all(top: Xml, s: String): Array<Xml> {
		var ret = [];
		if (top.nodeType != Document && top.nodeType != Element) return ret;

		var sa = Selector.parse(s);
		if (sa.length == 0) return ret;
		var q = new Query();
		if (sa.length == 1) {
			q.searchAll(ret, top.children, 0, top.children.length, 0, sa[0], true);
		} else {
			for (sel in sa) {
				q.searchAll(ret, top.children, 0, top.children.length, 0, sel, true);
			}
			var p = [];
			for (x in ret) {
				p.push(Path.ofXml(x, top));
			}
			p.sort(Path.PTools.onSort);    // sort
			ret = [];
			ret.push(p[0].toXml(top));
			var j = 1;
			for (i in 1...p.length) {
				var x = p[i].toXml(top);
				if (x != ret[j - 1]) {       // eliminate duplicates
					ret.push(x);
					++ j;
				}
			}
		}
		return ret;
	}

	public static function nodePos(xml: Xml): Int {
		var ret = -1;
	#if !NO_POS
		inline function int(s) return @:privateAccess Selector.int(s);
		switch (xml.nodeType) {
		case Element:
			ret = int(xml.get(":nodeName"));
		case PCData,
			 CData,
			 Comment:
			ret = int(xml.nodeName.split(":")[1]);
		default:
		}
	#end
		return ret;
	}

	public static function attrPos(xml: Xml, name: String): Int {
		var ret = -1;
	#if !NO_POS
		inline function int(s) return @:privateAccess Selector.int(s);
		if (xml.nodeType == Element)
			ret = int(xml.get(":" + name));
	#end
		return ret;
	}

	public static function contains(xml: Xml, child: Xml): Bool {
		var pa = child.parent;
		while (pa != null) {
			if (pa == xml) return true;
			pa = pa.parent;
		}
		return false;
	}

	public static function ownerDocument(xml: Xml): Xml {
		var ret = xml.parent;
		while (ret != null) {
			if (ret.nodeType == Document) break;
			ret = ret.parent;
		}
		return ret;
	}

	public static function toSimpleString(xml: Xml): String {
		if (xml.nodeType == Element) {
			var id = xml.get("id");
			var cls = xml.get("class");
			if (id == null)
				id = "";
			else
				id = "#" + id;
			if (cls == null)
				cls = "";
			else
				cls = "." + cls.split(" ").join("."); //
			return '<${xml.nodeName}$id$cls>';
		} else {
			return xml.toString();
		}
	}
}
