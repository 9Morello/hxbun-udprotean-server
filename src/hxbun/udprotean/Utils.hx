package hxbun.udprotean;

import haxe.crypto.Sha1;
import sys.net.Address;
import haxe.io.Bytes;
import hxbun.udprotean.protocol.CommandCode;

class Utils {
	static final isBigEndian:Bool = js.Syntax.code('(new Uint32Array([0x11223344]))[0] != 0x44');

	/**
	 * Returns the amount of time that has passed since this process started.
	 */
	public static inline function getTimestamp():Float {
		return Bun.nanoseconds();
	}

	/**
	 * Generates a random 6-byte handshake code.
	 */
	public static inline function generateHandshake():String {
		return CommandCode.Handshake + StringTools.hex(randomInt(), 8).toLowerCase();
	}

	/**
	 * Generates a disconnect code for a given handshake code.
	 */
	public static inline function getDisconnectCode(handshakeCode:String):String {
		return CommandCode.Disconnect + handshakeCode.substr(4);
	}

	/**
	 * Returns `true` if the given datagram is a handshake command.
	 */
	public static inline function isHandshake(datagram:Bytes):Bool {
		return datagram.length == 6 && StringTools.startsWith(datagram.toHex(), CommandCode.Handshake);
	}

	/**
	 * Returns `true` if the given datagram is a disconnect command.
	 */
	public static inline function isDisconnect(datagram:Bytes):Bool {
		return datagram.length == 6 && StringTools.startsWith(datagram.toHex(), CommandCode.Disconnect);
	}

	/**
	 * Calculates the Peer ID, given a code and a string representation of the peer's address.
	 */
	public static inline function generatePeerID(code:String, addressId:Int):String {
		return Sha1.encode(addressId + "|" + code.substr(4));
	}

	/**
	 * Returns the string representation of the given address in the `host:port` format.
	 */
	public static inline function addressToString(addr:Address) {
		return addr.host + ":" + addr.port;
	}

	/**
	 * Packs the ip and port numbers of the given address into a single integer.
	 */
	public static inline function portAndHostToId(port:Int, host:String):Int {
		return (port) | (ipToNum(host) << 16);
	}

	/**
	 * Converts an IP address string to an integer, in the same way that the
	 * std `Host` class does it in its constructor.
	 */
	public static inline function ipToNum(ip:String):Int {
		var num:Int = 0;

		var bytes:Array<String> = ip.split('.');

		if (!isBigEndian) {
			bytes.reverse();
		}

		for (b in bytes) {
			num = (num << 8) + Std.parseInt(b);
		}

		return num;
	}

	public static inline function randomInt():Int {
		return (Std.random(0xff) << 24) | (Std.random(0xff) << 16) | (Std.random(0xff) << 8) | Std.random(0xff);
	}
}
