CSS Selector
--------

**Works In Progress**

CSS-Selector With a Modified Xml Parser

* Provide extra position info that can be used to locate invalid value/attr(optional)

* Not based on RegExp

* querySelector & querySelectorAll see [Query.hx](csss/Query.hx?ts=4)

  ```
  E :   supported
  E F : supported
  E > F : supported
  E + F : supported
  E ~ F : supported
  ```

  supported pseudo-classes/element in [Selector.hx](csss/Selector.hx?ts=4#L535-L550)


example:

```haxe
import csss.xml.Parser;
import csss.xml.Xml;
using csss.Query;

class Main {
    static function main() {
        mymacro();
    }

    macro static function mymacro() {
        var myxml = "bin/index.html";
        var file = sys.io.File.getContent(myxml);
        var body = Parser.parse(file, false).querySelector("body");

        var x = body.querySelector(".t2 span");
        trace(str(x));

        var a = body.querySelectorAll(".selector-test > :nth-child(2n+1)");
        for (x in a) {
            trace(str(x));
        }
        var attr = body.get("class");
        if (attr != "expected") {
            var p = body.attrPos("class");
            var pos = haxe.macro.PositionTools.make({
                min: p,
                max: p + attr.length,
                file: myxml
            });
            haxe.macro.Context.error("click this message to location where the error occurred.", pos);
        }
        return macro null;
    }

    static function str(x: Xml) {
        var s = "<" + x.nodeName;
        for (k in x.attributes()) {
            if (k.charCodeAt(0) != ":".code)
                s += ' $k="${x.get(k)}"';
        }
        return s + ">";
    }
}
```

Note: If you added `-D NO_POS` then the `Query` will use the standard XML of haxe.(no longer provide position info.)


