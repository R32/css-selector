 // Note: This is a Modified version copy from Xml of haxe.
 // This revision provides pos info that can be used to locate invalid value/attr.
 //

package csss.xml;

// https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
extern enum abstract XmlType(Int) to Int {
	var Element = 1;
	var TEXT   = 3;
	var PCData = 3;
	var CData = 4;
	var ProcessingInstruction = 7;
	var Comment = 8;
	var Document = 9;
	var DocType = 10;
}

// Xml with Position
class Xml {

	public var nodeType(default, null) : XmlType;
	public var nodeName(default, null) : String;
	public var nodeValue(default, null) : String;
	public var nodePos(default, null) : Int;
	public var parent(default, null) : Xml;
	var children : Array<Xml>;
	var attributeMap : Array<String>; // [(attr, value)]
	var attributePos : Array<Int>;    // [(attr, value)], the pos of the attribute
	function new( nodeType, pos ) {
		this.nodeType = nodeType;
		if (nodeType == Element || nodeType == Document)
			children = [];
		if (nodeType == Element) {
			attributeMap = [];
			attributePos = [];
		}
		nodePos = pos;
	}

	public function toString() {
		return csss.xml.Printer.print(this);
	}

	public function get( att : String ) : String {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		var max = attributeMap.length;
		while (i < max) {
			if (attributeMap[i] == att) return attributeMap[i + 1];
			i += 2;
		}
		return null;
	}

	public inline function attrPos( name : String ) : Int return getPos(name, false);

	public function getPos( name : String, isKey : Bool ) : Int {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		var max = attributeMap.length;
		while (i < max) {
			if (attributeMap[i] == name) {
				if (!isKey) ++i;
				return attributePos[i];
			}
			i += 2;
		}
		return -1;
	}

	public function set( att : String, value : String, apos: Int, vpos: Int ) : Void {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		var max = attributeMap.length;
		while (i < max) {
			if (attributeMap[i] == att) {
				attributeMap[i + 1] = value;
				attributePos[i] = apos;
				attributePos[i + 1] = vpos;
				return;
			}
			i += 2;
		}
		attributeMap.push(att);
		attributeMap.push(value);
		attributePos.push(apos);
		attributePos.push(vpos);
	}

	public function remove( att : String ) : Void {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		var i = 0;
		var max = attributeMap.length;
		while (i < max) {
			if (attributeMap[i] == att) {
				attributeMap.splice(i, 2);
				attributePos.splice(i, 2);
				break;
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
		var max = attributeMap.length;
		while (i < max) {
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
	static public function createElement( name : String, pos : Int ) : Xml {
		var xml = new Xml(Element, pos);
		xml.nodeName = name;
		return xml;
	}

	static public function createPCData( data : String, pos : Int ) : Xml {
		var xml = new Xml(PCData, pos);
		xml.nodeValue = data;
		xml.nodeName = "#TEXT";
		return xml;
	}

	static public function createCData( data : String, pos : Int ) : Xml {
		var xml = new Xml(CData, pos);
		xml.nodeValue = data;
		xml.nodeName = "#CDATA";
		return xml;
	}

	static public function createComment( data : String, pos : Int ) : Xml {
		var xml = new Xml(Comment, pos);
		xml.nodeValue = data;
		xml.nodeName = "#COMMENT";
		return xml;
	}

	static public function createDocType( data : String, pos : Int ) : Xml {
		var xml = new Xml(DocType, pos);
		xml.nodeValue = data;
		return xml;
	}

	static public function createProcessingInstruction( data : String, pos : Int ) : Xml {
		var xml = new Xml(ProcessingInstruction, pos);
		xml.nodeValue = data;
		return xml;
	}

	static public function createDocument() : Xml {
		return new Xml(Document, 0);
	}

	static public function parse( str : String ) : Xml {
		return csss.xml.Parser.parse(str, false);
	}
}
