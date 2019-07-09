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
        var div = Xml.createElement("DIV", 1, 1);
        div.set("hello", "world", 0, 0, 0, 0);
        var input = Xml.createElement("INPUT", 6, 6);
        input.set("type", "button", 0, 0, 0, 0);
        input.set("value", "click", 0, 0, 0, 0);
        div.addChild(input);
        div.addChild(Xml.createPCData("abcdefg", 0, 0));
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

        var value = body.get("class");
        if (value != "expected") {
            var p = body.getPos("class", false, true);                       // utf8 byte position
            var pos = haxe.macro.PositionTools.make({
                min: p,
                max: p + csss.CValid.mbsLength(value),                       // utf8 bytes length
                file: myxml
            });
            haxe.macro.Context.error("click this message to location where the error occurred.", pos);
        }
        return macro null;
    }
}