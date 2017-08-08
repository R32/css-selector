package csss;

#if js
typedef Dict<T> = haxe.DynamicAccess<T>;
#else
typedef Dict<T> = haxe.ds.StringMap<T>;
#end