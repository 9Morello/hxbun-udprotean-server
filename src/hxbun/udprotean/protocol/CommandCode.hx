package hxbun.udprotean.protocol;

import haxe.io.Bytes;

enum abstract CommandCode(String) from String to String {
	var Handshake = "ffff";
	var Disconnect = "fffe";
	var UnreliableMessage = "fffd";
	var Ping = "fffc";

	public inline function getByteLength():Int {
		return Std.int(this.length / 2);
	}

	public inline function toBytes():Bytes {
		return Bytes.ofHex(this);
	}

	public static inline function ofBytes(bytes:Bytes):CommandCode {
		return bytes.length >= 2 ? bytes.toHex().substr(0, 4) : "";
	}
}
