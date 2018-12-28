package csss;

import csss.xml.Xml;
import csss.Selector;

@:enum private abstract State(Int) to Int {
	var None   = 0;
//	var BreakCurrent = 1;  // No need to find current selector in xml but can find in xml.children.
	var NoNeed = 2;        // No need to find current selector in xml and xml.children
	var Invalid = 3;       // No need to find **current and next selector** in xml and xml.children.
}

@:access(csss.xml.Xml)
class Query {

	var state: State;

	function new() { state = None; }

	function _apply(xml: Xml, a: Array<QItem>, ei: Int): Bool {
		for (i in a)
			if (!_eval(xml, i, ei)) return false;
		return true;
	}

	function _eval(xml: Xml, qitem: QItem, ei): Bool {
		var ret = false;
		var val: String;
		inline function strEq(s1: String, s2: String) return s1 != null && s1 != "" && s1 == s2;
		switch (qitem) {
		case QNode(n):
		#if NO_UPPER
			ret = n == "*" || n == xml.nodeName;
		#else
			ret = n == "*" || n.toUpperCase() == xml.nodeName;
		#end
		case QId(id):
			ret = strEq(xml.get("id"), id);
			if (ret) state = NoNeed;
		case QClass(c):
			ret = classEq(val = xml.get("class"), c);
		case QAttr(a):
			val = xml.get(a.name);
			if (val == null) return false;
			var tval = StringTools.trim(val);
			switch (a.type) {
			case ANone:
				ret = true;
			case AEq:
				ret = a.value != null && val == a.value;  // without trim
			case AWave:    // ~
				ret = a.value != "" && tval.split(" ").indexOf(a.value) != -1;
			case AXor:     // ^
				ret = a.value != "" && tval.indexOf(a.value) == 0;
			case ADollar:  // $
				ret = a.value != "" && tval.lastIndexOf(a.value) == tval.length - a.value.length;
			case AMul:     // *
				ret = a.value != "" && tval.indexOf(a.value) != -1;
			case AOr:      // |
				ret = a.value != "" && (tval == a.value || (StringTools.startsWith(tval, a.value) && tval.charCodeAt(a.value.length) == "-".code) );
			}
		case QPseudo(pe):
			switch (pe) {
			case PSelector(s), PSelectorDb(s):
				ret = pselectorEq(xml, s, ei);
			case PLang(s):
				ret = strEq(xml.get("lang"), s);
			case PNot(i):
				ret = _eval(xml, i, ei) == false;
			case PNth(type, n, m):
				switch (type) {
				case NthChild:      ret = nthEq(xml, ei, n, m);
				case NthLastChild,  // TODO Not Implemented
					 NthOfType,
					 NthLastOfType: ret = false;
				}
			}
		}
		return ret;
	}

	function nthEq(xml: Xml, ei, n, m): Bool {
		++ ei;  // start at 1.
		if (n < 0) {
			if (m < 0) {
				state = Invalid;
				return false;
			}
			var pnm = NM.PNM.ofNM(new NM(n, m));
			return ei <= pnm.max && pnm.valid(ei);
		} else if (n == 0) {
			return ei == m;
		} else {
			return ei >= m && (ei - m) % n == 0;
		}
	}

	function pselectorEq(xml: Xml, s: String, ei): Bool {
		var ret = false;
		switch (s) {
		case "root":
			state = NoNeed;
			ret = xml.parent != null && xml.parent.nodeType == Document;
		case "first-child":
			ret = ei == 0;
		case "last-child":
			var sibs = xml.parent.children;
			var last = sibs.length;
			while (--last >= ei) {
				if (sibs[last].nodeType == Element) {
					if (sibs[last] == xml)
						ret = true;
					break;
				}
			}
		case "empty":
			ret = true;
			for (child in xml.children) {
				if (child.nodeType != Comment) {
					ret = false;
					break;
				}
			}
		case "checked":
			ret = xml.exists("checked");
		case "disabled":
			ret = xml.exists("disabled");
		case _:
			// throw "Unsupported: " + s;
		}
		return ret;
	}

	function search(siblling: Array<Xml>, i: Int, max: Int, j: Int, chain: QList, rec: Bool): Xml {
		var xml: Xml;
		var ret = null;
		var succeed: Bool;
		var sib: Bool = false; // Sibling
		var adj: Bool = false; // Adjoin

		var prev: State;
		inline function saveState() { prev = state; state = None; }
		inline function resState()  { state = prev; }

		var sopt: Operator = chain.sub == null ? None : chain.sub.opt;
		inline function not_sub_selector() { return sopt == None; }
		inline function has_sub_selector() { return sopt != None; }

		while (i < max) {
			xml = siblling[i];
			if (xml.nodeType == Element) {
				succeed = _apply(xml, chain.h, j);

				if (succeed && not_sub_selector())
					return xml;
				else if (sib || adj) {
					saveState();
					ret = search(siblling, i, i + 1, j, chain.sub, false); // TODO: i + 1
					if (ret != null) return ret;
					if (state == Invalid) break;
					resState();
				}

				adj = false;
				if (succeed && has_sub_selector()) {
					if (sopt == Space || sopt == Child) {
						saveState();
						// sopt == Space ? (E   F)  :  (E > F)
						ret = search(xml.children, 0, xml.children.length, 0, chain.sub, sopt == Space);
						if (ret != null) return ret;
						if (state == Invalid) break;
						resState();
					} else if (sopt == Adjoin) {
						adj = true;  // (E + F)
					} else if (!sib) {
						sib = true;  // (E ~ F)
					}
				}

				if (rec && (state: Int) < (NoNeed: Int)) { // recursive
					saveState();
					ret = search(xml.children, 0, xml.children.length, 0, chain, true);
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

	function searchAll(out: Array<Xml>, siblling: Array<Xml>, i: Int, max: Int, j: Int, chain: QList, rec: Bool): Void {
		var xml: Xml;
		var succeed: Bool;
		var sib: Bool = false; // Sibling
		var adj: Bool = false; // Adjoin

		var prev: State;
		inline function saveState() { prev = state; state = None; }
		inline function resState() { state = prev; }

		var sopt: Operator = chain.sub == null ? None : chain.sub.opt;
		inline function not_sub_selector() { return sopt == None; }
		inline function has_sub_selector() { return sopt != None; }

		while (i < max) {
			xml = siblling[i];
			if (xml.nodeType == Element) {
				succeed = _apply(xml, chain.h, j);

				if (succeed && not_sub_selector()) {
					out.push(xml);
				} else if (sib || adj) {
					saveState();
					searchAll(out, siblling, i, i + 1, j, chain.sub, false); // TODO: looking for anather way instead of i + 1
					if (state == Invalid) break;
					resState();
				}

				adj = false;
				if (succeed && has_sub_selector()) {
					if (sopt == Space || sopt == Child) {
						saveState();
						// sopt == Space ? (E   F)  :  (E > F)
						searchAll(out, xml.children, 0, xml.children.length, 0, chain.sub, sopt == Space);
						if (state == Invalid) break;
						resState();
					} else if (sopt == Adjoin) {
						adj = true;  // (E + F)
					} else if (!sib) {
						sib = true;  // (E ~ F)
					}
				}

				if (rec && (state: Int) < (NoNeed: Int)) {
					saveState();
					searchAll(out, xml.children, 0, xml.children.length, 0, chain, true);
					if (state == Invalid) break;
					resState();
				}
				if (state != None) break;
				++ j;
			}
			++ i;
		}
	}

	static function classEq(s: String, v: String): Bool {
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
		var sa = QList.parse(s);
		if (sa.length == 0) return null;
		if (sa.length == 1) {
			return q.search(top.children, 0, top.children.length, 0, sa[0], true);
		} else {
			var r = [];
			for (chain in sa) {
				var x = q.search(top.children, 0, top.children.length, 0, chain, true);
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

		var sa = QList.parse(s);
		if (sa.length == 0) return ret;
		var q = new Query();
		if (sa.length == 1) {
			q.searchAll(ret, top.children, 0, top.children.length, 0, sa[0], true);
		} else {
			for (chain in sa) {
				q.searchAll(ret, top.children, 0, top.children.length, 0, chain, true);
			}
			var p = [];
			for (x in ret) {
				p.push(Path.ofXml(x, top));
			}
			p.sort(Path.PTools.onSort);    // sort
			ret = [];
			if (p.length > 0)
				ret.push(p[0].toXml(top));
			var j = 1;
			for (i in 1...p.length) {
				var x = p[i].toXml(top);
				if (x != ret[j - 1]) {     // eliminate duplicates
					ret.push(x);
					++ j;
				}
			}
		}
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
