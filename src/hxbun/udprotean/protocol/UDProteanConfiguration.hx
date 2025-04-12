package hxbun.udprotean.protocol;

import haxe.macro.Expr;
import haxe.macro.Context;

class UDProteanConfiguration {
	/**
	 * The size of the sequential communication cyclic buffers.
	 * Increasing this number makes the protocol more resistant to
	 * packet loss and big transmission rates, but increases the memory footprint
	 * as more datagrams will be getting stored.
	 *
	 * **This option needs to have the same value on both peers.**
	 */
	public static inline var SequenceSize:Int = #if !macro getOrDefault("UDPROTEAN_SEQUENCE_SIZE", 512) #else 512 #end;

	/**
	 * The maximum transmittable datagram size in bytes.
	 * Fragment numbers are represented with one byte, so the maximum
	 * size of a single message which can be sent by the protocol will be `255 * FragmentSize`.
	 *
	 * Changing this to a value higher than a normal network MTU can cause problems.
	 *
	 * **This option needs to have the same value on both peers.**
	 */
	public static inline var FragmentSize:Int = #if !macro getOrDefault("UDPROTEAN_FRAGMENT_SIZE", 540) #else 540 #end;

	/**
	 * The time (in ms) after which a not acknowledged datagram should be re-sent.
	 * A larger value is recommended for servers with multiple clients.
	 */
	public static inline var RepeatDatagramAge:Float = #if !macro getOrDefault("UDPROTEAN_REPEAT_AGE", 50) #else 50 #end;

	/**
	 * The time (in ms) after which retransmission of a datagram should be requested when receiving one out-of-order.
	 * A larger value is recommended for servers with multiple clients.
	 */
	public static inline var StaleDatagramAge:Float = #if !macro getOrDefault("UDPROTEAN_STALE_AGE", 20) #else 20 #end;

	/**
	 * The number of bytes needed to hold the sequence number.
	 * The amount of bytes set here needs to be able to hold the maximum sequence number
	 * which is `SequenceSize-1` as a **signed** integer.
	 *
	 * **This option needs to have the same value on both peers.**
	 */
	public static inline var SequenceBytes:Int = #if !macro getOrDefault("UDPROTEAN_SEQUENCE_BYTES", 3) #else 3 #end;

	/**
	 * The maximum cyclical distance one datagram can have from another and be presumed to be earlier than it.
	 * This is used as a threshold for discarding datagrams which arrive, and which are presumably older than
	 * the ones that have already been processed. A value too small may caused older re-transmitted datagrams to be
	 * processed a second time when the cyclic buffer reaches them on the next pass, and a value too big can cause
	 * legitimate datagrams to be discarded during heavy network traffic and/or significant packet loss, when the
	 * head of the cyclic buffer approaches its tail.
	 */
	public static inline var SequenceDistanceRelationship:Int = #if !macro getOrDefault("UDPROTEAN_SEQUENCE_DISTANCE", 32) #else 32 #end;

	/**
	 * The time (in seconds) of inactivity after which the client will send a keep-alive ping message to the server.
	 */
	public static inline var ClientPingInterval:Float = #if !macro getOrDefault("UDPROTEAN_PING_INTERVAL", 1.0) #else 1.0 #end;

	/**
	 * The time (in seconds) of inactivity after which a client is considered disconnected and removed from the server.
	 */
	public static inline var ClientIdleTimeLimit:Float = #if !macro getOrDefault("UDPROTEAN_CLIENT_IDLE_TIME", 3.0) #else 3.0 #end;

	@IgnoreCover
	macro static function getOrDefault(key:String, defaultValue:Expr) {
		if (Context.defined(key)) {
			return macro $v{Context.definedValue(key)};
		} else {
			return macro $e{defaultValue};
		}
	}
}
