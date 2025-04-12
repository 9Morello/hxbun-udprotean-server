package hxbun.udprotean;

import sys.net.UdpSocket;
import hxbun.udprotean.protocol.UDProteanPeer;

using hxbun.udprotean.Utils;

class UDProteanClientBehavior extends UDProteanPeer {
	@:noCompletion
	public final peerID:String;
	public final peerAddressID:Int;

	public final function new(socket:UdpSocket, hostName:String, peerID:String, hostPort:Int) {
		this.peerID = peerID;
		super(socket, hostName, hostPort);
		this.peerAddressID = Utils.portAndHostToId(hostPort, hostName);
	}

	public final override function update() {
		super.update();
	}

	public inline final function getPeerAddressID():Int {
		return peerAddressID;
	}
}
