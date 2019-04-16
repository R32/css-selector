CSS Selector
--------

CSS-Selector With a Modified Xml Parser. Note: the parsed XML instance will not contain empty TextNodes.

* Provide extra position info that can be used to locate the value/attr

  > If the position is not accurate(in flashdevelop). You may need add `-D old-error-format`

* No Dependencies

* Ease To Use.

  use `.querySelector/one` or `.querySelectorAll/all` to query XML. e.g. `xml.all("a:not([href='#'])")`.

  supported descendant selector:

  ```
  E :   supported
  E F : supported
  E > F : supported
  E + F : supported  Note: Partial
  E ~ F : supported  Note: Partial
  ```

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

        var x = body.querySelector("#t3 > li span");                         // equal body.one("#t3 > li span")
        trace(x != null ? x.toSimpleString() : x);

        var a = body.querySelectorAll(".selector-test > :nth-child(2n+1)");  // equal body.all("...")
        for (x in a) {
            trace(x.toSimpleString());
        }
        var attr = body.get("class");
        if (attr != "expected") {
            var p = body.attrPos("class");                                   // got position of attr
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
```

### Issues

* [Insolvable] Do not suport escaped single/double quotes.

  e.g: `a[title="hi \"name\"."]` will get a unexpected value.

* Do not suport **two** consecutive `+` or `~`.

  Invalid: `"li + li + li"`, `"li ~ li ~ li"`, `"li + li ~ li"`, `"li ~ li + li"`

  Available: `"li + li > li"`, `"li + li li"`, `"li li + li"`, `"li > li > li"`


### Changes


* `x.x.x`: removed uppercase
* `0.5.0`: rewritten the Query.search
