package hxbun.udprotean;

import js.lib.ArrayBuffer;
import js.Syntax;
import js.lib.Promise;
import sys.net.UdpSocket;
import hxbun.udprotean.protocol.UDProteanConfiguration;
import hxbun.udprotean.protocol.CommandCode;
import hxbun.udprotean.protocol.Timestamp;
import haxe.io.Bytes;
import haxe.io.BytesData;
import jsasync.Nothing;

using jsasync.JSAsyncTools;
using hxbun.udprotean.Utils;

class UDProteanServer {
	private var serverHost:String;
	private var serverPort:Int;
	private var behaviorType:Class<UDProteanClientBehavior>;

	private var started:Bool;
	private var socket:Null<UdpSocket>;
	private var peers:Array<UDProteanClientBehavior>;
	private var peersMap:Map<Int, UDProteanClientBehavior>;
	private var onClientConnectedCallback:(UDProteanClientBehavior) -> Void;
	private var onClientDisconnectedCallback:(UDProteanClientBehavior) -> Void;

	public var dataToProcess:Array<{
		datagram:BytesData,
		host:String,
		port:Int,
		id:Int
	}>;

	public function new(host:String, port:Int, behaviorType:Class<UDProteanClientBehavior>) {
		this.serverHost = host;
		this.serverPort = port;
		this.behaviorType = behaviorType;
		started = false;
		peers = new Array();
		peersMap = new Map();
		dataToProcess = new Array();
	}

	/**
	 * Starts the server.
	 * Essentially only binds the UDP port.
	 */
	@:jsasync public function start() {
		this.socket = Bun.udpSocket({
			port: this.serverPort,
			hostname: this.serverHost,
			binaryType: ArrayBuffer,
			socket: {
				data: (connectingSocket, data, port, address) -> {
					dataToProcess.push({
						datagram: data,
						host: address,
						id: Utils.portAndHostToId(port, address),
						port: port
					});
				}
			}
		}).jsawait();
		this.started = true;
	}

	/**
	 * Read and process all incoming datagrams currently available on the socket.
	 * The method will only return when there are no available data to read.
	 */
	@:jsasync public function update():Promise<Nothing> {
		updateTimeout(0).jsawait();
		Syntax.code('setImmediate({0});', update);
		return null;
	}

	/**
	 * Read and process all incoming datagrams currently available on the socket,
	 * for a maximum time of the given `timeout`.
	 * A `timeout` of `0` means infinite and the method will never return as long
	 * as there are available data to read.
	 */
	@:jsasync public function updateTimeout(timeout:Float):Promise<Nothing> {
		var timestamp:Timestamp = new Timestamp();
		var hadDatagrams:Bool;

		do {
			hadDatagrams = processRead();
			updatePeers();
		} while (hadDatagrams && !timestamp.isTimedOut(timeout));

		return null;
	}

	/**
	 * Stops the server and closes the socket.
	 */
	public function stop() {
		if (started)
			socket.close();
	}

	/**
	 * Registers a callback to be notified whenever a new client is connected.
	 *
	 * The callback will be invoked after the client's `initialize()` is called,
	 * and right before the client's `onConnect()` is called.
	 *
	 * @param callback The callback to register.
	 */
	public function onClientConnected(callback:(UDProteanClientBehavior) -> Void) {
		onClientConnectedCallback = callback;
	}

	/**
	 * Registers a callback to be notified whenever a client is disconnected.
	 *
	 * The callback will be invoked right after the client's `onDisconnect()` is called.
	 *
	 * @param callback The callback to register.
	 */
	public function onClientDisconnected(callback:(UDProteanClientBehavior) -> Void) {
		onClientDisconnectedCallback = callback;
	}

	function processRead():Bool {
		final data = dataToProcess.shift();
		if (data == null) {
			// Nothing to read.
			return false;
		}

		final datagram = data.datagram;

		var commandCode:CommandCode = CommandCode.ofBytes(Bytes.ofData(datagram));
		var peer:UDProteanClientBehavior = peersMap[data.id];

		switch (commandCode) {
			case CommandCode.Handshake:
				handleHandshake(datagram, data.host, data.port);

			case CommandCode.Disconnect:
				handleDisconnect(datagram, data.host, data.port);

			case CommandCode.UnreliableMessage if (peer != null):
				peer.onUnreliableMessageReceived(datagram);

			case Ping if (peer != null):
				peer.resetLastReceivedTimestamp();

			case _ if (peer != null):
				peer.onReceived(datagram);
		}

		return true;
	}

	function handleHandshake(datagram:ArrayBuffer, host:String, port:Int) {
		socket.send(datagram, port, host);

		var handshakeCode:String = Bytes.ofData(datagram).toHex();
		var peerID:String = Utils.generatePeerID(handshakeCode, Utils.portAndHostToId(port, host));

		// Add sender to the peers list.
		if (!peersMap.exists(Utils.portAndHostToId(port, host))) {
			initializePeer(peerID, host, port);
		}
	}

	function handleDisconnect(datagram:BytesData, host:String, port:Int) {
		var recvFromAddressId:Int = Utils.portAndHostToId(port, host);

		// Bounce back the disconnect code.
		try {
			socket.send(datagram, port, host);
		} catch (e:Dynamic) {
			trace('Disconnect error! $e');
		}

		var disconnectCode:String = Bytes.ofData(datagram).toHex();
		var peerID:String = Utils.generatePeerID(disconnectCode, recvFromAddressId);

		if (peersMap.exists(recvFromAddressId)) {
			var peer:UDProteanClientBehavior = peersMap[recvFromAddressId];
			var validDisconnectCode:Bool = (peer.peerID == peerID);

			if (validDisconnectCode) {
				removePeer(recvFromAddressId);
			}
		}
	}

	function updatePeers() {
		var toRemove:Array<Int> = new Array();

		for (peer in peers) {
			peer.update();

			if (peer.getLastReceivedElapsed() > UDProteanConfiguration.ClientIdleTimeLimit) {
				var addrID:Int = peer.getPeerAddressID();

				toRemove.push(addrID);
			}
		}

		while (toRemove.length > 0) {
			removePeer(toRemove.pop());
		}
	}

	function initializePeer(peerId:String, hostname:String, port:Int) {
		var peer:UDProteanClientBehavior = Type.createInstance(behaviorType, [socket, hostname, peerId, port]);
		peers.push(peer);
		peersMap.set(Utils.portAndHostToId(port, hostname), peer);
		peer.initialize();

		// Invoke the callback if registered.
		if (onClientConnectedCallback != null) {
			onClientConnectedCallback(peer);
		}

		peer.onConnect();
	}

	function removePeer(peerAddressId:Int) {
		var peer:UDProteanClientBehavior = peersMap[peerAddressId];

		// Call the onDisconnect callback.
		peer.onDisconnect();

		// Remove peer.
		peers.remove(peer);
		peersMap.remove(peerAddressId);

		// Invoke the callback if registered.
		if (onClientDisconnectedCallback != null) {
			onClientDisconnectedCallback(peer);
		}
	}
}
