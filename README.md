# hxbun-udprotean-server

hxbun-udprotean-server is an experimental [UDProtean](https://gitlab.com/haath/udprotean/) server implemented with [hxbun](https://github.com/9Morello/hxbun)'s UDP Socket APIs.

UDProtean is a reliable communication protocol built on top of UDP, created by [Haath](https://gmantaos.com/), who also wrote the original implementation. Most of the code in this library either comes directly from his Haxe library, or was slightly modified to use hxbun's UDP Socket APIs. So, most of the credit goes to him.

## Usage

Your server can be initialized in a very similar way to the UDProtean library:

```haxe
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

    // Called when the server receives a message from a connected client.
	override function onMessage(message:BytesData) {
		send(Bytes.ofString('Pong!'));
	}

	override function onDisconnect() {}
}

class BunUdpServer implements IJSAsync {

	@:jsasync public static function startServerAsync() {
		var server = new UDProteanServer("0.0.0.0", 9000, EchoClientBehavior);
		server.start();
		server.update().jsawait();
	}
}

```

You can then talk to the UDProtean server [using the original UDProtean library](https://gitlab.com/haath/udprotean/#client), which provides a client implementation.
