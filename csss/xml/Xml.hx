/*
 * Copyright (C)2005-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

 // Note: This is a Modified version copy from Xml of haxe.
 // This revision provides pos info that can be used to locate invalid value/attr.
 //

package csss.xml;

#if NO_POS
typedef Xml = std.Xml;

// fake
abstract PString(String) to String from String {
	public inline function new(s: String) this = s;

	public var value(get, set): String;
	inline function get_value(): String return this;
	inline function set_value(s: String): String return this = s;

	public var pos(get, set): Int;
	inline function get_pos(): Int return 0;
	inline function set_pos(s: Int): Int return 0;

	public inline function toString(): String return this;

	public inline static function eq(ps: PString, val: String): Bool {
		return ps != null && ps != "" && ps == val;
	}

	public inline static function attr(xml: Xml, name): String {
		return xml.get(name);
	}

	public inline static function name(xml: Xml): String {
		return xml.nodeName;
	}

	public inline static function text(xml: Xml): String {
		return xml.nodeValue;
	}
}

#else
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

// Xml with Position
class Xml {

	public var nodeType(default, null): XmlType;
	public var nodeName(default, null): PString;
	public var nodeValue(default, null): PString;
	public var parent(default, null): Xml;

	var children: Array<Xml>;
	var attributeMap: Dict<PString>;

	public function new(nodeType) {
		this.nodeType = nodeType;
		children = [];
		attributeMap = new Dict();
	}

	public function toString() {
		return csss.xml.Printer.print(this);
	}

	public function get( att : String ) : PString {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		return attributeMap.get(att);
	}

	public function set( att : String, value : PString ) : Void {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		attributeMap.set(att, value);
	}

	public function remove( att : String ) : Void {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		attributeMap.remove(att);
	}

	public function exists( att : String ) : Bool {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		return attributeMap.exists(att);
	}

	public function attributes() : Iterator<String> {
		if (nodeType != Element) {
			throw 'Bad node type, expected Element but found $nodeType';
		}
		#if js
		return attributeMap.keys().iterator();
		#else
		return attributeMap.keys();
		#end
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
		var ret = [for (child in children) if (child.nodeType == Element && child.nodeName.value == name.toUpperCase()) child];
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
	static public function createElement( name : PString ) : Xml {
		var xml = new Xml(Element);
		xml.nodeName = name;
		return xml;
	}

	static public function createPCData( data : PString ) : Xml {
		var xml = new Xml(PCData);
		xml.nodeValue = data;
		return xml;
	}

	static public function createCData( data : PString ) : Xml {
		var xml = new Xml(CData);
		xml.nodeValue = data;
		return xml;
	}

	static public function createComment( data : PString ) : Xml {
		var xml = new Xml(Comment);
		xml.nodeValue = data;
		return xml;
	}

	static public function createDocType( data : PString ) : Xml {
		var xml = new Xml(DocType);
		xml.nodeValue = data;
		return xml;
	}

	static public function createProcessingInstruction( data : PString ) : Xml {
		var xml = new Xml(ProcessingInstruction);
		xml.nodeValue = data;
		return xml;
	}

	static public function createDocument() : Xml {
		return new Xml(Document);
	}
}

@:structInit class PString {
	public var pos(default, null): Int;
	public var value(default, null): String;
	public function new(value, pos) {
		this.value = value;
		this.pos = pos;
	}
	public inline function toString(): String {
		return this.value;
	}

	public inline static function eq(ps: PString, val: String): Bool {
		return ps != null && val != "" && ps.value == val;
	}

	public inline static function attr(xml: Xml, name): String {
		var p = xml.get(name);
		return p == null ? null : p.value;
	}

	public inline static function name(xml: Xml): String {
		var p = xml.nodeName;
		return p == null ? null : p.value;
	}

	public inline static function text(xml: Xml): String {
		var p = xml.nodeValue;
		return p == null ? null : p.value;
	}
}

#end