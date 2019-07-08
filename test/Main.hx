package test;

import csss.xml.Xml;
using csss.Query;

class Main {
    static function main() {
        xml_test();
        mymacro();
    }

    macro static function xml_test() {
        var xml = Xml.createDocument();
        var div = Xml.createElement("DIV", 1);
        div.set("hello", "world", 11);
        var input = Xml.createElement("INPUT", 3);
        input.set("type", "button", 31);
        input.set("value", "click", 32);
        div.addChild(input);
        div.addChild(Xml.createPCData("abcdefg", 2));
        xml.addChild(div);
        trace(xml.toString() == '<div hello="world"><input type="button" value="click"/>abcdefg</div>');
        div.remove("hello");
        trace(xml.toString() == '<div><input type="button" value="click"/>abcdefg</div>');
        return macro null;
    }

    macro static function mymacro() {
        var myxml = "bin/index.html";
        var file = sys.io.File.getContent(myxml);
        var body = Xml.parse(file).querySelector("body");

        var x = body.querySelector("#t3 > li span");                         // equal body.one("#t3 > li span")
        trace(x != null ? x.toSimpleString() : x);

        var a = body.querySelectorAll(".selector-test > :nth-child(2n+1)");  // equal body.all("...")
        for (x in a) {
            trace(x.toSimpleString());
        }

        var attr = body.get("class");
        if (attr != "expected") {
            var p = body.attrPos("class");             // char position
            var p = csss.CValid.bytePosition(file, p); // convert to utf8 position
            var pos = haxe.macro.PositionTools.make({
                min: p,
                max: p + attr.length,
                file: myxml
            });
            haxe.macro.Context.error("click this message to location where the error occurred.", pos);
        }
        return macro null;
    }
}