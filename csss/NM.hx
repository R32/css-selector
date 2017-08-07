package csss;

/**
(10n+6) U (6n+3) = null
(10n+6) U (6n+4) = 30n+16
( 2n+1) U (2n+0) = null
( 5n+6) U (6n+5) = 30n+11
*/
class NM {
	public var n: Int;
	public var m: Int;
	public function new(n, m){
		this.n = n;
		this.m = m;
	}
	public function toString() return '${n}n+$m';

	public inline function copy() return new NM(n, m);

	public static function union(A: NM, B: NM) {
		if (A.n < 0 || B.n < 0) return null;
		if (A.n == 0) return (A.m >= B.m && ((A.m - B.m) % A.n) == 0) ? A.copy() : null;
		if (B.n == 0) return (B.m >= A.m && ((B.m - A.m) % B.n) == 0) ? B.copy() : null;
		if (A.n < B.n || A.n == B.n && A.m < B.m) {  // swap
			var t = A;
			A = B;
			B = t;
		} else if (A.n == B.n && A.m == B.m) {       // eq
			return A.copy();
		}
		var n = lcm(A.n, B.n);
		var m = 0;
		var i = B.m < A.m ? 0 : Std.int((B.m - A.m) / A.n);
		var max = i + n;
		while (i < max) {
			m = A.n * i + A.m;
			if ((m - B.m) % B.n == 0) break;
			++i;
		}
		return i < max ? new NM(n, m) : null;
	}

	// least common multiple
	static function lcm(a, b): Int {
		var t;
		if (a < b) {
			var t = a;
			a = b;
			b = t;
		}
		t = a % b;
		if (t == 0)
			return a;
		else if (t == 1)
			return a * b;
		else
			return untyped a * b / gcd(a, b);
	}
	// greatest common divisor
	static function gcd(a, b) {
		var t;
		if (a < b) {
			t = a;
			a = b;
			b = t;
		}
		t = a % b;
		if (t == 0)
			return b;
		else
			return gcd(b, t);
	}
}

class PNM extends NM {
	public var max(default, null): Int;
	function new(n, m, max) {
		this.max = max;
		super(n, m);
	}

	//override public function toString() return '${n}n+$m, [$max]';

	// for: nth-child(-2+10), (-3+10)
	public static function ofNM(A: NM): PNM {
		var n = A.n;
		var m = A.m;
		var max = -1;
		if (n < 0) {
			if (m < 0) {
				n = m = max = 0;   // union with any NM that will getting null
			} else {
				max = m;
				n = -n;
				m = max % n;
			}
		}
		return new PNM(n, m, max);
	}

	// for: when get the max value then do nth-last-child(2n+1) => nth-child(n, m), max
	public static function ofLastNM(A: NM, max: Int) {
		var n = A.n;
		var m = A.m;
		if (n < 0) {
			if (m < 0) {
				n = m = max = 0;
			} else {
				m = max + 1 - m;
				n = -n;
				max = max + 1 - n;
			}
		} else {
			max = max + 1 - m;
			m = max % n;
		}
		return new PNM(n, m, max);
	}
}