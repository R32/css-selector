 // Note: This is a Modified version copy from Xml of haxe.
 // This revision provides pos info that can be used to locate invalid value/attr.
 //

package csss.xml;

// https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
@:enum abstract XmlType(Int) to Int {
	var Element = 1;
	var TEXT   = 3;
	var PCData = 3;
	var CData = 4;
	var ProcessingInstruction = 7;
	var Comment = 8;
	var Document = 9;
	var DocType = 10;
}


@:forward(length, push, splice)
abstract TupleArray<T>(Array<T>) from Array<T> {
	public inline function new() this = [];
	@:arrayAccess inline function get(i : Int) : T return this[i];
	@:arrayAccess inline function set(i : Int, v : T) : T return this[i] = v;
}

// Xml with Position
class Xml {

	public var nodeType(default, null): XmlType;
	public var nodeName(default, null): String;
	public var nodeValue(default, null): String;
	public var nodePos(default, null): Int;
	public var nodeBinPos(default, null): Int;

	public var parent(default, null): Xml;
	var children: Array<Xml>;
	var attributeMap: TupleArray<String>; // [(attr, value)]
	var akeyPos: TupleArray<Int>;         // [(cpos, bpos)], the pos of the attribute
	var avalPos: TupleArray<Int>;         // [(cpos, bpos)], the pos of the value of attribute
	function new(nodeType, cpos, bpos) {
		this.nodeType = nodeType;
		if (nodeType == Element || nodeType == Document)
			children = [];
		if (nodeType == Element) {
			attributeMap = [];
			akeyPos = [];
			avalPos = [];
		}
		nodePos = cpos;
		nodeBinPos = bpos;
	}

	public function toString() {
		return csss.xml.Printer.print(this);
	}

	public function get( att : String ) : String {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		while (i < attributeMap.length) {
			if (attributeMap[i] == att) return attributeMap[i + 1];
			i += 2;
		}
		return null;
	}

	// for old
	public inline function attrPos(name: String):Int return getPos(name, false, false);

	public function getPos(name : String, isKey : Bool, isBin : Bool) : Int {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		while (i < attributeMap.length) {
			if (attributeMap[i] == name) {
				var a = isKey ? akeyPos : avalPos;
				if (isBin) ++i;
				return a[i];
			}
			i += 2;
		}
		return -1;
	}

	public function set( att : String, value : String, cpos: Int, bpos: Int, vcpos : Int, vbpos) : Void {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		var max = attributeMap.length;
		while (i < max) {
			if (attributeMap[i] == att) {
				attributeMap[i + 1] = value;
				akeyPos[i] = cpos;
				akeyPos[i + 1] = bpos;
				avalPos[i] = vcpos;
				avalPos[i + 1] = vbpos;
				return;
			}
			i += 2;
		}
		attributeMap.push(att);
		attributeMap.push(value);
		akeyPos.push(cpos);
		akeyPos.push(bpos);
		avalPos.push(vcpos);
		avalPos.push(vbpos);
	}

	public function remove( att : String ) : Void {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		while (i < attributeMap.length) {
			if (attributeMap[i] == att) {
				attributeMap.splice(i, 2);
				akeyPos.splice(i, 2);
				avalPos.splice(i, 2);
			}
			i += 2;
		}
	}

	public inline function exists( att : String ) : Bool {
		return get(att) != null;
	}

	public function attributes() : Iterator<String> {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		var ret = [];
		while (i < attributeMap.length) {
			ret.push(attributeMap[i]);
			i += 2;
		}
		return ret.iterator();
	}

	public inline function iterator() : Iterator<Xml> {
		ensureElementType();
		return children.iterator();
	}

	public function elements() : Iterator<Xml> {
		ensureElementType();
		var ret = [for (child in children) if (child.nodeType == Element) child];
		return ret.iterator();
	}

	public function elementsNamed( name : String ) : Iterator<Xml> {
		ensureElementType();
		var ret = [for (child in children) if (child.nodeType == Element && child.nodeName == name) child];
		return ret.iterator();
	}

	public function firstChild() : Xml {
		ensureElementType();
		return children[0];
	}

	public function firstElement() : Xml {
		ensureElementType();
		for (child in children) {
			if (child.nodeType == Element) {
				return child;
			}
		}
		return null;
	}

	public function addChild( x : Xml ) : Void {
		ensureElementType();
		if (x.parent != null) {
			x.parent.removeChild(x);
		}
		children.push(x);
		x.parent = this;
	}

	public function removeChild( x : Xml ) : Bool {
		ensureElementType();
		if (children.remove(x)) {
			x.parent = null;
			return true;
		}
		return false;
	}

	public function insertChild( x : Xml, pos : Int ) : Void {
		ensureElementType();
		if (x.parent != null) {
			x.parent.children.remove(x);
		}
		children.insert(pos, x);
		x.parent = this;
	}

	inline function ensureElementType() {
		if (nodeType != Document && nodeType != Element) {
			throw 'Bad node type, expected Element or Document but found $nodeType';
		}
	}

	// Note: Use UpperCase for name.
	static public function createElement( name : String, pos : Int, bpos : Int ) : Xml {
		var xml = new Xml(Element, pos, bpos);
		xml.nodeName = name;
		return xml;
	}

	static public function createPCData( data : String, pos : Int, bpos : Int ) : Xml {
		var xml = new Xml(PCData, pos, bpos);
		xml.nodeValue = data;
		xml.nodeName = "#TEXT";
		return xml;
	}

	static public function createCData( data : String, pos : Int, bpos : Int ) : Xml {
		var xml = new Xml(CData, pos, bpos);
		xml.nodeValue = data;
		xml.nodeName = "#CDATA";
		return xml;
	}

	static public function createComment( data : String, pos : Int, bpos : Int ) : Xml {
		var xml = new Xml(Comment, pos, bpos);
		xml.nodeValue = data;
		xml.nodeName = "#COMMENT";
		return xml;
	}

	static public function createDocType( data : String, pos : Int, bpos : Int ) : Xml {
		var xml = new Xml(DocType, pos, bpos);
		xml.nodeValue = data;
		return xml;
	}

	static public function createProcessingInstruction( data : String, pos : Int, bpos : Int ) : Xml {
		var xml = new Xml(ProcessingInstruction, pos, bpos);
		xml.nodeValue = data;
		return xml;
	}

	static public function createDocument() : Xml {
		return new Xml(Document, 0, 0);
	}

	static public function parse( str : String ) : Xml {
		return csss.xml.Parser.parse(str, false);
	}
}
