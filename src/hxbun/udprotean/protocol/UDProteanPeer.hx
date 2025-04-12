package hxbun.udprotean.protocol;

import haxe.io.BytesData;
import haxe.io.Bytes;
import hxbun.udprotean.protocol.CommandCode;
import hxbun.udprotean.protocol.SequentialCommunication;
import sys.net.UdpSocket;

class UDProteanPeer extends SequentialCommunication {
	var socket:UdpSocket;
	var peerHost:String;
	var peerPort:Int;
	var lastReceived:Timestamp;
	var lastTransmitted:Timestamp;

	#if UDPROTEAN_UNIT_TEST
	public static var PacketLoss:Float = 0;

	var rand:seedyrng.Random = new seedyrng.Random();
	#end

	function new(socket:UdpSocket, peerHost:String, peerPort:Int) {
		super();
		this.socket = socket;
		this.peerHost = peerHost;
		this.peerPort = peerPort;
		lastReceived = Timestamp.Now;
		lastTransmitted = Timestamp.Now;
	}

	/**
	 * Send an unreliable message.
	 * This message is one that will bypass the sequential communication
	 * protocol and be transmitted immediately as a normal UDP datagram.
	 * Besides delivery and order of receiving of these messages not being guaranteed,
	 * the fragmentation features of this library also do not apply to messages
	 * sent through this method, this means that a message size larger than the network's
	 * MTU may cause it to get dropped along the way. A recommended maximum message
	 * length would be around 540 bytes.
	 */
	public final function sendUnreliable(message:Bytes) {
		var codeByteLength:Int = CommandCode.UnreliableMessage.getByteLength();
		var datagram:Bytes = Bytes.alloc(message.length + codeByteLength);
		datagram.blit(0, CommandCode.UnreliableMessage.toBytes(), 0, codeByteLength);
		datagram.blit(codeByteLength, message, 0, message.length);
		onTransmit(datagram.getData());
	}

	@:noCompletion
	public override final function onReceived(datagram:BytesData) {
		resetLastReceivedTimestamp();

		super.onReceived(datagram);
	}

	/**
	 * Returns the time elapsed since data was last received from this peer.
	 *
	 * @return The time elapsed in **seconds**.
	 */
	@:noCompletion public inline function getLastReceivedElapsed():Float {
		return lastReceived.elapsed();
	}

	/**
	 * Returns the time elapsed since data was last sent to this peer.
	 *
	 * @return The time elapsed in **seconds**.
	 */
	@:noCompletion
	public inline function getLastTransmittedElapsed():Float {
		return lastTransmitted.elapsed();
	}

	@:noCompletion
	public inline function resetLastReceivedTimestamp() {
		lastReceived = Timestamp.Now;
	}

	inline function resetLastTransmittedTimestamp() {
		lastTransmitted = Timestamp.Now;
	}

	@:noCompletion @:protected
	override final function onTransmit(datagram:BytesData) {
		#if UDPROTEAN_UNIT_TEST
		if (rand.random() >= PacketLoss)
		#end

		resetLastTransmittedTimestamp();
		socket.send(datagram, peerPort, peerHost);
	}

	@:noCompletion @:protected
	final override function onMessageReceived(message:BytesData) {
		onMessage(message);
	}

	@:noCompletion @:allow(hxbun.udprotean.UDProteanServer)
	final function onUnreliableMessageReceived(datagram:BytesData) {
		resetLastReceivedTimestamp();

		var commandCodeLength:Int = CommandCode.UnreliableMessage.getByteLength();
		var message = datagram.slice(commandCodeLength, datagram.byteLength - commandCodeLength);
		onMessage(message);
	}

	@IgnoreCover @:allow(hxbun.udprotean.UDProteanServer) function initialize() {}

	@IgnoreCover @:allow(hxbun.udprotean.UDProteanServer) function onConnect() {}

	@IgnoreCover function onMessage(message:BytesData) {}

	@IgnoreCover @:allow(hxbun.udprotean.UDProteanServer) function onDisconnect() {}
}
