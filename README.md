CSS Selector
--------

CSS-Selector With a Modified Xml Parser

* Provide extra position info that can be used to locate invalid value/attr(optional)

  Note: Use `-D NO_POS` will be able to disable this feature(then std.Xml will instead of csss.Xml).

  If the position is not accurate. You may need add `-D old-error-format`

* Not based on RegExp

* No Dependencies

* Ease To Use.

  use `.querySelector/one` or `.querySelectorAll/all` to query XML. e.g. `xml.querySelectorAll("a:not([href='#'])")`.

  use `.attrPos` or `.nodePos` to got position of attributes/nodeName/nodeValue.

  supported descendant selector:

  ```
  E :   supported
  E F : supported
  E > F : supported
  E + F : supported  Note:
  E ~ F : supported  Note:
  ```

  supported pseudo-classes/element in [Selector.hx](csss/Selector.hx?ts=4#L536-L552)

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

* Do not suport **two** consecutive `+` or `~`. see [Query TODO](csss/Query.hx?ts=4#L233)

  Invalid: `"li + li + li"`, `"li ~ li ~ li"`, `"li + li ~ li"`, `"li ~ li + li"`

  Available: `"li + li > li"`, `"li + li li"`, `"li li + li"`, `"li > li > li"`


### Changes

* `0.3.0`:   fix class validating of Query. [more...](https://github.com/R32/css-selector/compare/176c4c0...472958c)
* `0.2.2`:   added `Xml.parse` that you no longer need to `import csss.xml.Parse`
