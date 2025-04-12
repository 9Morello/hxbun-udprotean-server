package hxbun.udprotean.protocol;

import haxe.io.Bytes;

/**
	Holds an a numerical sequence which cycles between 0 and SEQUENCE_SIZE.
**/
abstract Sequence(Int) from Int to Int {
	public static var maxValue(get, never):Int;

	public var previous(get, never):Int;
	public var next(get, never):Int;

	public function new(initialValue:Int = 0) {
		this = initialValue;
	}

	public static inline function get_maxValue():Int {
		return UDProteanConfiguration.SequenceSize - 1;
	}

	public function get_previous():Int {
		return this > 0 ? (this - 1) : maxValue;
	}

	public function get_next():Int {
		return (this + 1) % UDProteanConfiguration.SequenceSize;
	}

	public inline function set(value:Int) {
		this = value;
	}

	public inline function movePrevious() {
		this = previous;
	}

	public inline function moveNext() {
		this = next;
	}

	public inline function isBefore(seq:Sequence):Bool {
		return distanceTo(seq) < UDProteanConfiguration.SequenceDistanceRelationship && this != seq;
	}

	/**
	 * Returns the current value and then advances it forward.
	 */
	public inline function getAndMoveNext() {
		moveNext();
		return previous;
	}

	/**
	 * Returns `true` if the sequence is cyclically between `s1` and `s2`.
	 */
	public inline function isBetween(s1:Sequence, s2:Sequence):Bool {
		return (s1 < s2 && s1 < this && this < s2) // [ .. s1 .. this .. s2 .. ]
			|| (s1 > s2 && (s1 < this || this < s2)); // [ .. this .. s2 .. s1 .. ]
		// [ .. s2 .. s1 .. this .. ]
	}

	/**
	 * Returns the distance to the given sequence.
	 * Meaning the amount of steps with the `moveNext()` function needed to reach it.
	 */
	public inline function distanceTo(seq:Sequence):Int {
		return seq >= this ? Std.int(seq - this) : Std.int(UDProteanConfiguration.SequenceSize - this + seq);
	}

	public inline function toBytes():Bytes {
		var buf:Bytes = Bytes.alloc(4);
		buf.setInt32(0, this);
		return buf.sub(0, 3);
	}

	/**
	 * Returns the sequence number from the first `SequenceBytes` little-endian bytes of the given buffer.
	 */
	public static inline function fromBytes(bytes:Bytes):Sequence {
		var b:Bytes = Bytes.alloc(4);
		b.blit(0, bytes, 0, UDProteanConfiguration.SequenceBytes);
		return b.getInt32(0);
	}

	/**
		OVERLOADS
	**/
	@:op(A == B)
	static function eq(a:Sequence, b:Sequence):Bool {
		return cast(a, Int) == cast(b, Int);
	}

	@:op(A > B)
	static function gt(a:Sequence, b:Sequence):Bool {
		return cast(a, Int) > cast(b, Int);
	}

	@:op(A >= B)
	static function gtequals(a:Sequence, b:Sequence):Bool {
		return cast(a, Int) >= cast(b, Int);
	}

	@:op(A < B)
	static function lt(a:Sequence, b:Sequence):Bool {
		return cast(a, Int) < cast(b, Int);
	}

	@:op(A <= B)
	static function ltequals(a:Sequence, b:Sequence):Bool {
		return cast(a, Int) < cast(b, Int);
	}
}
