import haxe.io.BytesData;
import js.lib.Promise;
import haxe.io.Bytes;
import hxbun.udprotean.UDProteanClientBehavior;
import hxbun.udprotean.UDProteanServer;

using jsasync.JSAsyncTools;

import jsasync.IJSAsync;

class EchoClientBehavior extends UDProteanClientBehavior {
	// Called after the constructor.
	override function initialize() {}

	// Called after the connection handshake.
	override function onConnect() {}

	override function onMessage(message:BytesData) {
		send(Bytes.ofString('Pong!'));
	}

	override function onDisconnect() {}
}

class BunTestMain implements IJSAsync {
	public static function main() {
		mainAsync();
	}

	@:jsasync public static function mainAsync() {
		var server = new UDProteanServer("0.0.0.0", 9000, EchoClientBehavior);
		server.start();
		server.update().jsawait();
	}
}
