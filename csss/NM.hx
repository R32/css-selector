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
	public inline function toString() return '${n}n+$m';

	public inline function copy() return new NM(n, m);

	public static function union(A: NM, B: NM) {
		if (A.n < 0 || B.n < 0) return null;
		if (A.n == 0) return ((A.m - B.m) % A.n) == 0 ? A.copy() : null;
		if (B.n == 0) return ((B.m - A.m) % B.n) == 0 ? B.copy() : null;
		if (A.n < B.n || A.n == B.n && A.m < B.m) {  // swap
			var t = A;
			A = B;
			B = t;
		} else if (A.n == B.n && A.m == B.m) {       // eq
			return A.copy();
		}
		var n = lcm(A.n, B.n);
		var m = 0;
		var i = 1;
		while (true) {
			m = A.n * i + A.m;
			if (!(m < n) || (m - B.m) % B.n == 0) break;
			++i;
		}
		return m < n ? new NM(n, m) : null;
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