CSS Selector
--------

A css selector tool and a simple xml parser(Provides additional position information).

It's suitable for use in non-browsing environments.

example:

```haxe
import csss.xml.Xml;
using csss.Query;

class Main {
    static function main() {
        mymacro();
    }

    macro static function mymacro() {
        var myxml = "bin/index.html";
        var file = sys.io.File.getContent(myxml);
        var body = Xml.parse(file).querySelector("body");

        var x = body.querySelector("#t3 > li span");
        trace(x != null ? x.toSimpleString() : x);

        var a = body.querySelectorAll(".selector-test > :nth-child(2n+1)");
        for (x in a) {
            trace(x.toSimpleString());
        }
        var value = body.get("class");
        if (value != "expected") {
            var p = body.attrPos("class");
            var pos = haxe.macro.PositionTools.make({
                min: p,
                max: p + value.length,
                file: myxml
            });
            haxe.macro.Context.error("click this message to location where the error occurred.", pos);
        }
        return macro null;
    }
}
```

### Issues

* [Insolvable] Do not suport escaped single/double quotes.

  e.g: `a[title="hi \"name\"."]` will get a unexpected value.


### Changes

* `x.x.x`:
  - removed uppercase
  - Rewrote csss.Query again
