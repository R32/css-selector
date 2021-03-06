 // Note: This is a Modified version copy from haxe.xml.Printer.
 //
 //

package csss.xml;

/**
	This class provides utility methods to convert Xml instances to
	String representation.
**/
class Printer {
	/**
		Convert `Xml` to string representation.

		Set `pretty` to `true` to prettify the result.
	**/
	static public function print(xml:Xml, ?pretty = false) {
		var printer = new Printer(pretty);
		printer.writeNode(xml, "");
		return printer.output.toString();
	}

	var output:StringBuf;
	var pretty:Bool;

	function new(pretty) {
		output = new StringBuf();
		this.pretty = pretty;
	}

	function writeNode(value:Xml, tabs:String) {
		switch (value.nodeType) {
			case CData:
				write(tabs + "<![CDATA[");
				write(StringTools.trim(value.nodeValue));
				write("]]>");
				newline();
			case Comment:
				var commentContent:String = value.nodeValue;
				commentContent = ~/[\n\r\t]+/g.replace(commentContent, "");
				commentContent = "<!--" + commentContent + "-->";
				write(tabs);
				write(StringTools.trim(commentContent));
				newline();
			case Document:
				for (child in value) {
					writeNode(child, tabs);
				}
			case Element:
				write(tabs + "<");
				write(value.nodeName.toLowerCase());
				var a = @:privateAccess value.attributeMap;
				var i = 0;
				while (i < a.length) {
					write(" " + a[i] + "=\"");
					write(a[i + 1]);
					write("\"");
					i += 2;
				}
				if (hasChildren(value)) {
					write(">");
					newline();
					for (child in value) {
						writeNode(child, pretty ? tabs + "\t" : tabs);
					}
					write(tabs + "</");
					write(value.nodeName.toLowerCase());
					write(">");
					newline();
				} else {
					write("/>");
					newline();
				}
			case PCData:
				var nodeValue:String = value.nodeValue;
				if (nodeValue.length != 0) {
					write(tabs + nodeValue);
					newline();
				}
			case ProcessingInstruction:
				write("<?" + value.nodeValue + "?>");
				newline();
			case DocType:
				write("<!DOCTYPE " + value.nodeValue + ">");
				newline();
		}
	}

	inline function write(input:String) {
		output.add(input);
	}

	inline function newline() {
		if (pretty) {
			output.add("\n");
		}
	}

	function hasChildren(value:Xml):Bool {
		for (child in value) {
			switch (child.nodeType) {
				case Element, PCData:
					return true;
				case CData, Comment:
					if (StringTools.ltrim(child.nodeValue).length != 0) {
						return true;
					}
				case _:
			}
		}
		return false;
	}
}
