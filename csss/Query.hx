package csss;

import csss.xml.Xml;
import csss.Selector;

@:access(csss.xml.Xml)
class Query {

	var stop: Bool; // Indicates that it no longer matches the current sets of QItem

	function new() { stop = false; }

	function matchQItem(xml: Xml, qitem: QItem, ei): Bool {
		var ret = false;
		var val: String;
		inline function strEq(s1: String, s2: String) return s1 != null && s1 != "" && s1 == s2;
		switch (qitem) {
		case QNode(n):
			ret = n == "*" || n == xml.nodeName || n.toLowerCase() == xml.nodeName.toLowerCase();
		case QId(id):
			ret = strEq(xml.get("id"), id);
			if (ret) stop = true;
		case QClass(c):
			ret = classEq(val = xml.get("class"), c);
		case QAttr(a):
			val = xml.get(a.name);
			if (val == null) return false;
			var tval = StringTools.trim(val);
			switch (a.type) {
			case AExists:
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
				ret = matchQItem(xml, i, ei) == false;
			case PNth(type, n, m):
				switch (type) {
				case NthChild:      ret = nthEq(xml, ei, n, m);
				case NthLastChild,  // TODO Not Implemented
					 NthOfType,
					 NthLastOfType: ret = false;
				}
			case PContains(s):
				function loop( node : Xml ) {
					switch(node.nodeType) {
					case TEXT:
						return node.nodeValue.indexOf(s) != -1;
					case Element:
						for (x in node.children) {
							if (loop(x))
								return true;
						}
					case _:
					}
					return false;
				}
				ret = loop(xml);
			}
		}
		return ret;
	}

	function nthEq(xml: Xml, ei, n, m): Bool {
		++ ei;  // start at 1.
		if (n < 0) {
			if (m < 0) {
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
			stop = true;
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
		case "checked", "disabled":
			ret = xml.exists(s);
		case _:
		#if js
			#if haxe4
			throw new js.lib.Error("Unsupported: " + s);
			#else
			throw new js.Error("Unsupported: " + s);
			#end
		#else
			throw ("Unsupported: " + s);
		#end
		}
		return ret;
	}

	function search(col:Array<Xml>, i: Int, max: Int, ei:Int, cur: QList): Xml {
		var prev = this.stop;
		var ret: Xml = null;
		this.stop = false;   // reset
		while (i < max) {
			var xml = col[i];
			if (xml.nodeType == Element) {
				var done = true;
				for (q in cur.h) {
					if ( !matchQItem(xml, q, ei) ) {
						done = false;
						break;
					}
				}
				if (done && cur.sub == null) {
					ret = xml;
					break;
				}

				// depthLookup
				if ( !stop && (cur.opt == None || cur.opt == Space) ) {
					ret = search(xml.children, 0, xml.children.length, 0, cur);          // current
					if (ret != null)
						break;
				}
				if (done) {
					// next sets of QItem;
					switch(cur.sub.opt) {
					case None:  // throw "will never run to here"
					case Space, Child:
						ret = search(xml.children, 0, xml.children.length, 0, cur.sub);  // sub
					case Adjoin, Sibling:
						// TODO: search(i+1,...) should be delay until its have depthLookup(i + 1)
						ret = search(col, i + 1, max, ei + 1, cur.sub);                  // sub
					}
					if (ret != null)
						break;
				}
				if (this.stop || cur.opt == Adjoin)
					break;
				++ ei;
			}
			++ i;
		}
		this.stop = prev;
		return ret;
	}

	function searchAll(out: Array<Xml>, col: Array<Xml>, i:Int, max:Int, ei:Int, cur:QList, ?dup:Bool):Void {
		var prev = this.stop;
		this.stop = false;
		while (i < max) {
			var xml = col[i];
			if (xml.nodeType == Element) {
				var done = true;
				for (q in cur.h) {
					if ( !matchQItem(xml, q, ei) ) {
						done = false;
						break;
					}
				}
				if (done && cur.sub == null && (!dup || out.lastIndexOf(xml) == -1) ) {
					out.push( xml );
				}
				if ( !stop && (cur.opt == None || cur.opt == Space) ) {
					searchAll(out, xml.children, 0, xml.children.length, 0, cur, dup);
				}
				if (done && cur.sub != null) {
					switch(cur.sub.opt) {
					case None:
					case Space, Child:
						searchAll(out, xml.children, 0, xml.children.length, 0, cur.sub, dup);
					case Adjoin, Sibling:
						// TODO: same as this.search()
						searchAll(out, col, i + 1, max, ei + 1, cur.sub, true);
					}
				}
				if (this.stop || cur.opt == Adjoin)
					break;
				++ ei;
			}
			++ i;
		}
		this.stop = prev;
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
			return q.search(top.children, 0, top.children.length, 0, sa[0]);
		} else {
			var r = [];
			for (que in sa) {
				var x = q.search(top.children, 0, top.children.length, 0, que);
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
			q.searchAll(ret, top.children, 0, top.children.length, 0, sa[0]);
		} else {
			for (que in sa) {
				q.searchAll(ret, top.children, 0, top.children.length, 0, que);
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
