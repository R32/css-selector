package csss;

enum Operator {
	None;    //
	Space;   //
	Child;   // ">"
	Adjoin;  // "+"
	Sibling; // "~"
}

enum NthType {
	NthChild;
	NthLastChild;
	NthOfType;
	NthLastOfType;
}

enum Pseudo {
	PSelector(s:String);   // :first-child
	PSelectorDb(s:String); // ::first-child
	PLang(s:String);       // lang()
	PNot(i:QItem);         //
	PNth(t:NthType, n:Int, m:Int);
}

enum AttrType {
	AExists;
	AEq;
	AWave;
	AXor;
	ADollar;
	AMul;
	AOr;
}

class Attr {
	public var name: String;
	public var value: String;
	public var type: AttrType;
	public function new(n, v, t) {
		name = n;
		value = v;
		type = t;
	}
}

enum QItem {
	QNode(s: String);
	QId(s: String);
	QClass(s: String);
	QAttr(a: Attr);
	QPseudo(p: Pseudo);
}

class QList {
	public var h(default, null): Array<QItem>;
	public var opt: Operator;
	public var sub: QList;
	public function new(opt) {
		this.h = [];
		this.opt = opt;
	}
	public inline function add(i: QItem) this.h.push(i);

	public inline function empty() return h.length == 0;

	static public function ofSelector(s: Selector): QList {
		var q = new QList(s.opt);
		if (s.id != null)     q.h.push( QId(s.id) );
		if (s.node != null)   q.h.push( QNode(s.node) );
		for (c in s.classes)  q.h.push( QClass(c) );
		for (a in s.attries)  q.h.push( QAttr(a) );
		for (p in s.pseudes)  q.h.push( QPseudo(p) );
		if (s.sub != null)
			q.sub = ofSelector(s.sub);
		return q;
	}

	static public inline function parse(s: String): Array<QList> {
	#if (lex && !macro)
		return csss.LRParser.parse(s);
	#else
		return csss.Parser.parse(s);
	#end
	}
}

class Selector {
	public var node: String;
	public var id: String;
	public var classes: Array<String>;
	public var attries: Array<Attr>;
	public var pseudes: Array<Pseudo>;
	public var sub: Selector;
	public var opt: Operator;
	public function new(opt) {
		classes = [];
		attries = [];
		pseudes = [];
		this.opt = opt;
	}

	static public function ofQueue(q: QList): Selector {
		var s = new Selector(q.opt);
		for (i in q.h) {
			switch(i){
			case QNode(n):    s.node = n;
			case QId(i):      s.id = i;
			case QClass(c):   s.classes.push(c);
			case QAttr(a):    s.attries.push(a);
			case QPseudo(p):  s.pseudes.push(p);
			}
		}
		if (q.sub != null)
			s.sub = ofQueue(q.sub);
		return s;
	}

	static public function parse(s: String): Array<Selector> {
		return QList.parse(s).map( q -> ofQueue(q) );
	}
}
