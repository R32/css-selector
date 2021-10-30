package csss;

import csss.xml.Xml;
import csss.Selector;

@:access(csss.xml.Xml)
class Query {

	static function doMatch( xml : Xml, query : QItem, epos : Int ) : Bool {
		var ret = false;
		inline function stringEqual(s1, s2) return s1 != null && s1 != "" && s1 == s2;
		switch (query) {
		case QNode(n):
			ret = n == "*" || n == xml.nodeName || n.toLowerCase() == xml.nodeName.toLowerCase();
		case QId(id):
			ret = stringEqual(xml.get("id"), id);
		case QClass(c):
			ret = classEqual(xml.get("class"), c);
		case QAttr(a):
			var val = xml.get(a.name);
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
				ret = pselectorEqual(xml, s, epos);
			case PLang(s):
				ret = stringEqual(xml.get("lang"), s);
			case PNot(i):
				ret = doMatch(xml, i, epos) == false;
			case PNth(type, n, m):
				switch (type) {
				case NthChild:      ret = nthEqual(xml, epos, n, m);
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

	static function nthEqual( xml : Xml, epos : Int, n : Int, m : Int ) : Bool {
		++ epos;  // start at 1.
		if (n < 0) {
			if (m < 0) {
				return false;
			}
			var pnm = NM.PNM.ofNM(new NM(n, m));
			return epos <= pnm.max && pnm.valid(epos);
		} else if (n == 0) {
			return epos == m;
		} else {
			return epos >= m && (epos - m) % n == 0;
		}
	}

	static function pselectorEqual( xml : Xml, s : String, epos: Int ) : Bool {
		var ret = false;
		switch (s) {
		case "root":
			ret = xml.parent != null && xml.parent.nodeType == Document;
		case "first-child":
			ret = epos == 0;
		case "last-child":
			var sibs = xml.parent.children;
			var last = sibs.length;
			while (--last >= epos) {
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
			throw "Unsupported: " + s;
		}
		return ret;
	}

	static function search( childNodes : Array<Xml>, i : Int, max : Int, epos : Int, current : QList, mode : Operator ) : Xml {
		var ret = null;
		while(i < max) {
			final xml = childNodes[i++];
			if (xml.nodeType != Element)
				continue;
			ret = xml;
			for (query in current.h) {
				if (!doMatch(xml, query, epos)) {
					ret = null;
					break;
				}
			}
			epos++;
			if (ret != null) { // if matched
				if (current.sub == null)
					return xml;
				final nextSelector = current.sub;
				final nextMode = nextSelector.opt;
				switch(nextMode) {
				case Top: // throw "never runs to here"
				case Space, Child:
					ret = search(xml.children, 0, xml.children.length, 0, nextSelector, nextMode);
				case Adjoin, Sibling:
					ret = search(childNodes, i, max, epos, nextSelector, nextMode);
				}
			}
			// do depth search if fails
			if (ret == null && mode == Space) {
				ret = search(xml.children, 0, xml.children.length, 0, current, Space);
			}
			if (ret != null || mode == Adjoin)
				break;
		}
		return ret;
	}

	static function searchAll( out : Array<Xml>, childNodes : Array<Xml>, i : Int, max : Int, epos : Int, current : QList, mode : Operator ) : Void {
		var matched : Bool;
		while(i < max) {
			final xml = childNodes[i++];
			if (xml.nodeType != Element)
				continue;
			matched = true;
			for (query in current.h) {
				if (!doMatch(xml, query, epos)) {
					matched = false;
					break;
				}
			}
			epos++;
			if (matched) {
				if (current.sub == null) {
					out.push(xml);
				} else {
					final nextSelector = current.sub;
					final nextMode = nextSelector.opt;
					switch(nextMode) {
					case Top:
					case Space, Child:
						searchAll(out, xml.children, 0, xml.children.length, 0, nextSelector, nextMode);
					case Adjoin, Sibling:
						searchAll(out, childNodes, i, max, epos, nextSelector, nextMode);
					}
				}
			}
			if (mode == Space) {
				searchAll(out, xml.children, 0, xml.children.length, 0, current, Space);
			} else if (mode == Adjoin) {
				break;
			}
		}
	}

	static function classEqual( s : String, v : String ) : Bool {
		if (s == null || s == "") return false;
		var c : Int;
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

	public static inline function querySelector( top : Xml, s : String ) : Xml {
		return one(top, s);
	}

	public static function one( top : Xml, s : String ) : Xml {
		if (top.nodeType != Document && top.nodeType != Element)
			return null;
		var qlists = QList.parse(s);
		if (qlists.length == 0)
			return null;
		if (qlists.length == 1)
			return search(top.children, 0, top.children.length, 0, qlists[0], Space);
		var col = [];
		for(query in qlists) {
			var x = search(top.children, 0, top.children.length, 0, query, Space);
			if (x != null)
				col.push(x);
		}
		if (col.length == 0)
			return null;
		if (col.length == 1)
			return col[0];
		// sort
		var paths = [];
		for (x in col)
			paths.push(Path.ofXml(x, top));
		paths.sort(Path.PTools.onSort);
		return paths[0].toXml(top);
	}

	public static inline function querySelectorAll(top: Xml, s: String): Array<Xml> {
		return all(top, s);
	}

	public static function all( top : Xml, s : String ) : Array<Xml> {
		var ret = [];
		if (top.nodeType != Document && top.nodeType != Element)
			return ret;
		var qlists = QList.parse(s);
		for (query in qlists) {
			searchAll(ret, top.children, 0, top.children.length, 0, query, Space);
		}
		var paths = [];
		for (x in ret) {
			paths.push(Path.ofXml(x, top));
		}
		paths.sort(Path.PTools.onSort);
		ret = [];
		if (paths.length > 0) {
			ret.push(paths[0].toXml(top));
		}
		// eliminate duplicates
		var last = 0;
		for (i in 1...paths.length) {
			var x = paths[i].toXml(top);
			if (x != ret[last]) {
				ret.push(x);
				last++;
			}
		}
		return ret;
	}

	public static function contains( xml : Xml, child : Xml ) : Bool {
		var pa = child.parent;
		while (pa != null) {
			if (pa == xml) return true;
			pa = pa.parent;
		}
		return false;
	}

	public static function ownerDocument( xml : Xml ) : Xml {
		var ret = xml.parent;
		while (ret != null) {
			if (ret.nodeType == Document) break;
			ret = ret.parent;
		}
		return ret;
	}

	public static function toSimpleString( xml : Xml ) : String {
		if (xml == null)
			return "null";
		if (xml.nodeType == Element) {
			var id = xml.get("id");
			var cls = xml.get("class");
			if (id == null) {
				id = "";
			} else if (id != "") {
				id = "#" + id;
			}
			if (cls == null) {
				cls = "";
			} else if (cls != ".") {
				cls = "." + cls.split(" ").join("."); //
			}
			return '<${xml.nodeName}$id$cls>';
		} else {
			return xml.toString();
		}
	}
}
