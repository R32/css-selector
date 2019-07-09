 // Note: This is a Modified version copy from haxe.xml.Parse.
 // 1. This revision provides pos info that can be used to locate invalid value/attr.
 // 2. accept a few empty-element with no closing tag.
 // 3. does not escape/unescape the html characters

package csss.xml;

import csss.xml.Xml;
using StringTools;


/* poor'man enum : reduce code size + a bit faster since inlined */
extern private class S {
	public static inline var IGNORE_SPACES 	= 0;
	public static inline var BEGIN			= 1;
	public static inline var BEGIN_NODE		= 2;
	public static inline var TAG_NAME		= 3;
	public static inline var BODY			= 4;
	public static inline var ATTRIB_NAME	= 5;
	public static inline var EQUALS			= 6;
	public static inline var ATTVAL_BEGIN	= 7;
	public static inline var ATTRIB_VAL		= 8;
	public static inline var CHILDS			= 9;
	public static inline var CLOSE			= 10;
	public static inline var WAIT_END		= 11;
	public static inline var WAIT_END_RET	= 12;
	public static inline var PCDATA			= 13;
	public static inline var HEADER			= 14;
	public static inline var COMMENT		= 15;
	public static inline var DOCTYPE		= 16;
	public static inline var CDATA			= 17;
}

class XmlParserException
{
	/**
	 * the XML parsing error message
	 */
	public var message:String;

	/**
	 * the line number at which the XML parsing error occurred
	 */
	public var lineNumber:Int;

	/**
	 * the character position in the reported line at which the parsing error occurred
	 */
	public var positionAtLine:Int;

	/**
	 * the character position in the XML string at which the parsing error occurred
	 */
	public var position:Int;

	public var bpos:Int;

	/**
	 * the invalid XML string
	 */
	public var xml:String;

	public function new(message:String, xml:String, position:Int, bpos:Int)
	{
		this.xml = xml;
		this.message = message;
		this.position = position;
		this.bpos = bpos;
		lineNumber = 1;
		positionAtLine = 0;

		for( i in 0...position)
		{
			var c = xml.fastCodeAt(i);
			if (c == '\n'.code) {
				lineNumber++;
				positionAtLine = 0;
			} else {
				if (c != '\r'.code) positionAtLine++;
			}
		}
	}

	public function toString():String
	{
		return Type.getClassName(Type.getClass(this)) + ": " + message + " at line " + lineNumber + " char " + positionAtLine;
	}
}

@:structInit class BinPosition {
	public var bpos : Int;
}

@:structInit class AName {
	public var s : String;
	public var cpos : Int;
	public var bpos : Int;
}

class Parser
{
	static function is_empty_elem(name: String): Bool {
		// AREA, BASE, BR, COL, EMBED, HR, IMG, INPUT, KEYGEN, LINK, META, PARAM, SOURCE, TRACK, WBR,
		var name = name.toUpperCase();
		if (name == "META" || name == "LINK" || name == "BR" || name == "HR" || name == "INPUT" || name == "IMG")
			return true
		else
			return false;
	}

	/**
	 * Parses the String into an XML Document. Set strict parsing to true in order to enable a strict check of XML attributes and entities.
	 *
	 * @throws haxe.xml.XmlParserException
	 */
	static public function parse(str:String, strict = false)
	{
		var doc = Xml.createDocument();
		doParse(str, strict, 0, {bpos: 0}, doc);
		return doc;
	}

	static function doParse(str:String, strict:Bool, p:Int, warp: BinPosition, parent:Xml):Int
	{
		var xml:Xml = null;
		var state = S.BEGIN;
		var next = S.BEGIN;
		var aname: Null<AName> = null;
		var start = p;
		var bpos = warp.bpos;  // for return the bpos
		var binStart = bpos;
		var nsubs = 0;
		var nbrackets = 0;
		var c = str.fastCodeAt(p);
		var all_spaces = true;
		// need extra state because next is in use
		var escapeNext = S.BEGIN;
		var attrValQuote = -1;
		inline function addChild(xml:Xml) {
			parent.addChild(xml);
			nsubs++;
		}
		var max = str.length;
		while (p < max)
		{
			switch(state)
			{
				case S.IGNORE_SPACES:
					switch(c)
					{
						case
							'\n'.code,
							'\r'.code,
							'\t'.code,
							' '.code:
						default:
							state = next;
							continue;
					}
				case S.BEGIN:
					switch(c)
					{
						case '<'.code:
							state = S.BEGIN_NODE;
						default:
							start = p; (binStart = bpos);
							state = S.PCDATA;
							all_spaces = true;
							continue;
					}
				case S.PCDATA:
					if (c == '<'.code && str.fastCodeAt(p + 1) != " ".code) {
						if (all_spaces == false) {  // ignore the empty TextNode
							addChild(Xml.createPCData(str.substr(start, p - start), start, binStart));
						}
						state = S.BEGIN_NODE;
					} else if (all_spaces && !csss.CValid.is_space(c)){
						all_spaces = false;
					}
				case S.CDATA:
					if (c == ']'.code && str.fastCodeAt(p + 1) == ']'.code && str.fastCodeAt(p + 2) == '>'.code)
					{
						var child = Xml.createCData(str.substr(start, p - start), start, binStart);
						addChild(child);
						p += 2; (bpos += 2);
						state = S.BEGIN;
					}
				case S.BEGIN_NODE:
					switch(c)
					{
						case '!'.code:
							if (str.fastCodeAt(p + 1) == '['.code)
							{
								p += 2; (bpos += 2);
								if (str.substr(p, 6).toUpperCase() != "CDATA[")
									throw new XmlParserException("Expected <![CDATA[", str, p, bpos);
								p += 5; (bpos += 5);
								state = S.CDATA;
								start = p + 1; (binStart = bpos + 1);
							}
							else if (str.fastCodeAt(p + 1) == 'D'.code || str.fastCodeAt(p + 1) == 'd'.code)
							{
								if(str.substr(p + 2, 6).toUpperCase() != "OCTYPE")
									throw new XmlParserException("Expected <!DOCTYPE", str, p, bpos);
								p += 8; (bpos += 8);
								state = S.DOCTYPE;
								start = p + 1; (binStart = bpos + 1);
							}
							else if( str.fastCodeAt(p + 1) != '-'.code || str.fastCodeAt(p + 2) != '-'.code )
								throw new XmlParserException("Expected <!--", str, p, bpos);
							else
							{
								p += 2; (bpos += 2);
								state = S.COMMENT;
								start = p + 1; (binStart = bpos + 1);
							}
						case '?'.code:
							state = S.HEADER;
							start = p; (binStart = bpos);
						case '/'.code:
							if( parent == null )
								throw new XmlParserException("Expected node name", str, p, bpos);
							start = p + 1; (binStart = bpos + 1);
							state = S.CLOSE;
						default:
							state = S.TAG_NAME;
							start = p; (binStart = bpos);
							continue;
					}
				case S.TAG_NAME:
					if (!isValidChar(c)) @:privateAccess
					{
						if (parent.nodeName == "script" && parent.children.length > 0) {
							var last = parent.children[parent.children.length - 1];
							// remove last textNode and recover the state
							last.parent = null;
							parent.children.pop();
							start = last.nodePos; (binStart = last.nodeBinPos);
							state = S.PCDATA;
							continue;
						}
						if( p == start )
							throw new XmlParserException("Expected node name", str, p, bpos);
						xml = Xml.createElement(str.substr(start, p - start), start, binStart);
						addChild(xml);
						state = S.IGNORE_SPACES;
						next = S.BODY;
						continue;
					}
				case S.BODY:
					switch(c)
					{
						case '/'.code:
							state = S.WAIT_END;
						case '>'.code:
							if (is_empty_elem(xml.nodeName)) // empty-element tag
								state = S.BEGIN;
							else
								state = S.CHILDS;
						default:
							state = S.ATTRIB_NAME;
							start = p; (binStart = bpos);
							continue;
					}
				case S.ATTRIB_NAME:
					if (!isValidChar(c))
					{
						if( start == p )
							throw new XmlParserException("Expected attribute name", str, p, bpos);
						aname = {s: str.substr(start,p-start).toLowerCase(), cpos: start, bpos: binStart};
						if( xml.exists(aname.s) )
							throw new XmlParserException("Duplicate attribute [" + aname.s + "]", str, start, binStart);
						state = S.IGNORE_SPACES;
						next = S.EQUALS;
						continue;
					}
				case S.EQUALS:
					switch(c)
					{
						case '='.code:
							state = S.IGNORE_SPACES;
							next = S.ATTVAL_BEGIN;
						default:
							if ( isValidChar(c) || c == '>'.code || c == '/'.code ) {
								xml.set(aname.s, "", aname.cpos, aname.bpos, p-1, bpos-1);
								state = S.BODY;
								continue;
							}
							throw new XmlParserException("Expected =", str, p, bpos);
					}
				case S.ATTVAL_BEGIN:
					switch(c)
					{
						case '"'.code | '\''.code:
							state = S.ATTRIB_VAL;
							start = p + 1; (binStart = bpos + 1);
							attrValQuote = c;
						default:
							throw new XmlParserException("Expected \"", str, p, bpos);
					}
				case S.ATTRIB_VAL:
					switch (c) {
						case '>'.code | '<'.code if( strict ):
							// HTML allows these in attributes values
							throw new XmlParserException("Invalid unescaped " + String.fromCharCode(c) + " in attribute value", str, p, bpos);
						case _ if (c == attrValQuote):
							xml.set(aname.s, str.substr(start, p - start), aname.cpos, aname.bpos, start, binStart);
							state = S.IGNORE_SPACES;
							next = S.BODY;
					}
				case S.CHILDS:
					var tmp:BinPosition = {bpos: bpos};
					p = doParse(str, strict, p, tmp, xml); (bpos = tmp.bpos);
					start = p; (binStart = bpos);
					state = S.BEGIN;
				case S.WAIT_END:
					switch(c)
					{
						case '>'.code:
							state = S.BEGIN;
						default :
							throw new XmlParserException("Expected >", str, p, bpos);
					}
				case S.WAIT_END_RET:
					switch(c)
					{
						case '>'.code:
							if( nsubs == 0 )
								parent.addChild(Xml.createPCData("", p + 1, bpos + 1));
							warp.bpos = bpos; return p;
						default :
							throw new XmlParserException("Expected >", str, p, bpos);
					}
				case S.CLOSE:
					if (!isValidChar(c))
					{
						if( start == p )
							throw new XmlParserException("Expected node name", str, p, bpos);
						var v = str.substr(start,p - start);
						if (parent == null || parent.nodeType != Element) {
							throw new XmlParserException('Unexpected </$v>, tag is not open', str, p, bpos);
						}
						if (v != parent.nodeName)
							throw new XmlParserException("Expected </" +parent.nodeName + ">", str, p, bpos);

						state = S.IGNORE_SPACES;
						next = S.WAIT_END_RET;
						continue;
					}
				case S.COMMENT:
					if (c == '-'.code && str.fastCodeAt(p +1) == '-'.code && str.fastCodeAt(p + 2) == '>'.code)
					{
						addChild(Xml.createComment(str.substr(start, p - start), start, binStart));
						p += 2; (bpos += 2);
						state = S.BEGIN;
					}
				case S.DOCTYPE:
					if(c == '['.code)
						nbrackets++;
					else if(c == ']'.code)
						nbrackets--;
					else if (c == '>'.code && nbrackets == 0)
					{
						addChild(Xml.createDocType(str.substr(start, p - start), start, binStart));
						state = S.BEGIN;
					}
				case S.HEADER:
					if (c == '?'.code && str.fastCodeAt(p + 1) == '>'.code)
					{
						p++; (bpos ++);
						var str = str.substr(start + 1, p - start - 2);
						addChild(Xml.createProcessingInstruction(str, start, binStart));
						state = S.BEGIN;
					}
			}
			bpos += mbsChar( c ); // ?mbsChar( str.fastCodeAt(p) );
			c = str.fastCodeAt(++p);
		}
		if (state == S.BEGIN)
		{
			start = p;
			state = S.PCDATA;

		}
		if (state == S.PCDATA)
		{
			if (parent.nodeType == Element) {
				throw new XmlParserException("Unclosed node <" + parent.nodeName + ">", str, p, bpos);
			}
			if (p != start || nsubs == 0) {
				addChild(Xml.createPCData(str.substr(start, p - start), start, binStart));
			}
			warp.bpos = bpos; return p;
		}
		throw new XmlParserException("Unexpected end", str, p, bpos);
	}

	static inline function isValidChar(c) {
		return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == ':'.code || c == '.'.code || c == '_'.code || c == '-'.code;
	}

	static function is_allspace(str: String, pos: Int, right: Int): Bool {
		while (pos < right) {
			if (str.fastCodeAt(pos) > " ".code) return false;
			++ pos;
		}
		return true;
	}

	static function mbsChar(c: Int): Int {
		return if (c < 0x80) {
			1;
		} else if (c < 0x800) {
			2;
		} else if (c >= 0xD800 && c <= 0xDFFF) {
			4;
		} else {
			3;
		}
	}
}
