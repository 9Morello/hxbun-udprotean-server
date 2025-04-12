package hxbun.udprotean.protocol;

import haxe.io.BytesData;

class DatagramBuffer {
	var buffer:Array<BytesData>;
	var timestamps:Array<Timestamp>;

	public function new() {
		buffer = new Array<BytesData>();
		buffer.resize(UDProteanConfiguration.SequenceSize);
		timestamps = new Array<Timestamp>();
		timestamps.resize(UDProteanConfiguration.SequenceSize);
	}

	/**
		Returns the datagram at the given index in the buffer.
	**/
	public inline function get(index:Int):BytesData {
		return buffer[index];
	}

	/**
	 * Inserts a datagram at the specified index in the buffer,
	 * with a current timestamp.
	 */
	public inline function insert(index:Int, datagram:BytesData) {
		buffer[index] = datagram;
		refresh(index);
	}

	/**
	 * Inserts a datagram at the specified index in the buffer,
	 * with a zero (stale) timestamp.
	 */
	public inline function insertStale(index:Int, datagram:BytesData) {
		buffer[index] = datagram;
		setStale(index);
	}

	/**
		Refreshes the timestamp of the datagram at the given index in the buffer.
	**/
	public inline function refresh(index:Int) {
		timestamps[index] = new Timestamp();
	}

	/**
		Returns `true` if the given index in the buffer is empty (null).
	**/
	public inline function isEmpty(index:Int):Bool {
		return buffer[index] == null;
	}

	/**
	 * Returns `true` if the datagram at the given index in the buffer exists and is older than StaleDatagramAge.
	 */
	public inline function isStale(index:Int):Bool {
		return !isEmpty(index) && timestamps[index].elapsedMs() > UDProteanConfiguration.StaleDatagramAge;
	}

	/**
	 * Sets the timestamp of the datagram at the given index in the buffer to zero,
	 * thus making subsequent calls to the `isStale()` and `istoRepeat()` methods return `true`.
	 * (Assuming that the datagram at the given index exists)
	 */
	public inline function setStale(index:Int) {
		timestamps[index] = Timestamp.Zero;
	}

	/**
	 * Returns `true` if the datagram at the given index in the buffer exists and is older than RepeatDatagramAge.
	 */
	public inline function isToRepeat(index:Int):Bool {
		return !isEmpty(index) && timestamps[index].elapsedMs() > UDProteanConfiguration.RepeatDatagramAge;
	}

	/**
	 * Clears the given index in the buffer, setting it to null.
	 */
	public inline function clear(index:Int) {
		buffer[index] = null;
	}
}
