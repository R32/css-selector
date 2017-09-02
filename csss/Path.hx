package csss;

import csss.xml.Xml;

@:forward(push, length, join, iterator)
abstract Path(Array<Int>) to Array<Int> from Array<Int> {
	public inline function new() this = [];

	public inline function toXml(top: Xml): Xml {
		return PTools.lookup(this, top);
	}

	inline function reverse() this.reverse();

	public static inline function ofXml(xml: Xml, top: Xml = null): Path {
		return PTools.getPath(xml, top);
	}
}

@:allow(csss.Path)
class PTools {

	public static function onSort(a: Path, b: Path): Int {
		var i = 0;
		var len = a.length;
		if (b.length < len) len = b.length;
		while (i < len) {
			if (a[i] == b[i]) {
				++ i;
			} else {
				return a[i] - b[i];
			}
		}
		return a.length - b.length;
	}

	// relative to the #document when top == null
	static function getPath(xml: Xml, top: Xml): Path {
		var ret = new Path();
		while (xml != null && xml != top) {
			if (xml.parent != null) {
				var i = 0;
				var col = @:privateAccess xml.parent.children;
				var len = col.length;
				while (i < len) {
					if (col[i] == xml) ret.push(i);
					++ i;
				}
			}
			xml = xml.parent;
		}
		if (xml == top)
			@:privateAccess ret.reverse();
		else
			ret = null;
		return ret;
	}

	static function lookup(path: Path, top: Xml): Xml {
		if (top == null) return null;
		for (i in path) {
			top = @:privateAccess top.children[i];
		}
		return top;
	}
}