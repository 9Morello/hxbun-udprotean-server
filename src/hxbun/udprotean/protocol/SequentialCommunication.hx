package hxbun.udprotean.protocol;

import js.lib.DataView;
import js.lib.ArrayBuffer;
import haxe.io.BytesData;
import haxe.io.Bytes;

abstract class SequentialCommunication {
	private var sendingSequence:Sequence; // Sending progress through sendingBuffer.
	private var sendingAckSequence:Sequence; // Sent dgrams that have been ACKed.
	private var receivingSequence:Sequence; // Receiving progress through receivingBuffer.
	private var receivingAckSequence:Sequence; // Received dgrams that have been ACKed.
	private var processingSequence:Sequence; // Dgrams that have been processed.

	private var sendingBuffer:DatagramBuffer;
	private var receivingBuffer:DatagramBuffer;
	private var sequenceBuffer = new DataView(new ArrayBuffer(4));
	private var sendingSequenceBuffer = new DataView(new ArrayBuffer(3));

	public function new() {
		initSequentialCommunication();
	}

	@:protected @:noCompletion
	function initSequentialCommunication() {
		// Initialize buffers.
		sendingBuffer = new DatagramBuffer();
		receivingBuffer = new DatagramBuffer();

		// Initialize sequences
		sendingSequence = 0;
		sendingAckSequence = 0;
		receivingSequence = 0;
		receivingAckSequence = -1;
		processingSequence = 0;
	}

	/**
	 * Send a message to the connected peer.
	 * @param message The message to send. Due to fragmentation, the maximum size for a single message is (255 * FragmentSize).
	 * @param sendNow Whether or not to transmit datagrams immediately. If `false`, the method will only store datagrams in the
	 *                buffers and return immediately. These datagrams will be sent during the next `update()`.
	 */
	public final function send(message:Bytes, sendNow:Bool = true) {
		var fragmentCount:Int = Std.int(message.length / UDProteanConfiguration.FragmentSize) + 1;
		var dataIndex:Int = 0;

		while (fragmentCount > 0) {
			fragmentCount--;

			var fragmentSize:Int = Std.int(Math.min(message.length - dataIndex, UDProteanConfiguration.FragmentSize));

			var fragment:Bytes = Bytes.alloc(fragmentSize + 1);

			fragment.set(0, fragmentCount);
			fragment.blit(1, message, dataIndex, fragmentSize);

			dataIndex += fragmentSize;

			sendDatagram(fragment, sendNow);
		}
	}

	/**
	 * Process a received datagram, as it was received on the socket.
	 */
	@:noCompletion
	public function onReceived(datagram:BytesData) {
		sequenceBuffer.setUint8(0, Bytes.fastGet(datagram, 0));
		sequenceBuffer.setUint8(1, Bytes.fastGet(datagram, 1));
		sequenceBuffer.setUint8(2, Bytes.fastGet(datagram, 2));
		var datagramSequence:Sequence = sequenceBuffer.getInt32(0, true);

		// If the datagram is only SequenceBytes long, then it's an ACK.
		if (datagram.byteLength == UDProteanConfiguration.SequenceBytes) {
			onReceivedAck(datagramSequence);
			return;
		}

		// Check if we already have this datagram and we just haven't ACKed it yet.
		if (datagramSequence == receivingAckSequence || datagramSequence.isBetween(receivingAckSequence, receivingSequence)) {
			return;
		}

		// Check if it's an unnecessary retransmission of an already-processed datagram.
		if (datagramSequence.isBefore(processingSequence)) {
			return;
		}

		// Keep the payload in the datagramm by removing the sequence bytes,
		// and add it to the receiving buffer at its position in the sequence.
		var data:BytesData = datagram.slice(UDProteanConfiguration.SequenceBytes);
		receivingBuffer.insert(datagramSequence, data);

		if (datagramSequence == receivingSequence) {
			/*
			 * This datagram is on-par with the sequence.
			 */
			processReceivingBuffer();

			sendAck(receivingSequence);
			receivingSequence.moveNext();
		} else if (receivingBuffer.isStale(receivingSequence)) {
			/*
			 * We received a datagram with an unexpected sequence number.
			 * Let the other end know which was the last datagram we received.
			 */
			sendAck(receivingSequence.previous);
		}
	}

	/**
	 * Update method meant to be called periodically.
	 * This method re-sends messages that have not been acknowledged,
	 * and requests repeats of expected messages that have not been received.
	 */
	@:noCompletion
	public function update() {
		// Repeat everything from the last ACKed message up to the end of the sending buffer.
		var sendingFlushSequence:Sequence = sendingAckSequence;
		while (sendingFlushSequence != sendingSequence) {
			if (sendingBuffer.isToRepeat(sendingFlushSequence)) {
				transmitFromBuffer(sendingFlushSequence);
			}
			sendingFlushSequence.moveNext();
		}
	}

	@:noCompletion
	private final function sendDatagram(fragment:Bytes, sendNow:Bool) {
		// Get the sequence number for this datagram according to sendingSequence.
		var datagramSequence:Sequence = sendingSequence.getAndMoveNext();

		// Allocate the size of the datagram.
		var datagram:Bytes = Bytes.alloc(UDProteanConfiguration.SequenceBytes + fragment.length);
		var datagramView = new DataView(new ArrayBuffer(3 + fragment.length));
		var fragmentView = new DataView(fragment.getData());
		datagramView.setInt32(0, datagramSequence, true);

		var i:Int = 0;
		while (i < fragment.length) {
			datagramView.setUint8(3 + i, fragmentView.getUint8(i));
			i++;
		}

		// Write sequence number goes into the first bytes.
		// datagram.setInt32(0, datagramSequence);

		// Write the fragment into the rest.
		// datagram.blit(UDProteanConfiguration.SequenceBytes, fragment, 0, fragment.length);

		// Store the datagram in the sending buffer.
		sendingBuffer.insertStale(datagramSequence, datagramView.buffer);

		/*
		 * Empty the next spot in the circular buffer.
		 * This is done to ensure separation between this
		 * and the previous cycle of values.
		 * Helps clearing the buffer backwards upon
		 * acknowledgements without deleting newer datagrams.
		 */
		sendingBuffer.clear(datagramSequence.next);

		if (sendNow) {
			// Finally, transmit the datagram.
			transmitFromBuffer(datagramSequence);
		}
	}

	/**
	 * Goes through all the datagrams in the receiving buffer which have not yet been consumed.
	 * This function makes sure that datagrams are consumed in order, and that fragmented
	 * payloads are received to their entirety.
	 * The `processingSequence` is used to track the last consumed datagram in the receiving buffer.
	 *
	 * @returns The amount of positions the processing sequence was moved by.
	 */
	@:noCompletion
	private final function processReceivingBuffer():Int {
		var stepCount:Int = 0;

		while (!receivingBuffer.isEmpty(processingSequence)) {
			var datagramLength:Int = getCompletedDatagramAt(processingSequence);

			if (datagramLength > 0) {
				// There is a completed datagram at the current position.
				var datagram:Bytes = Bytes.alloc(datagramLength);
				var bufferIndex:Int = 0;

				while (bufferIndex < datagramLength) {
					var fragment:Bytes = Bytes.ofData(receivingBuffer.get(processingSequence));

					// Write the fragment to the datagram, excluding the first byte
					// which is the fragment number.
					datagram.blit(bufferIndex, fragment, 1, fragment.length - 1);

					// Clear the datagram we just read.
					receivingBuffer.clear(processingSequence);

					bufferIndex += fragment.length - 1;
					stepCount++;

					if (processingSequence == receivingSequence.next) {
						/*
						 * If we are progressing past the receiving sequence, then it means
						 * that the datagram that was just received filled a gap in the receiving sequence,
						 * and allowed the processing sequence to go past the receiving one.
						 * In this case we should also pull up the receiving sequence so that
						 * it doesn't stay behind what is being processed for two reasons:
						 * - ACKs should not be sent for datagrams that are not the last one that we actually have.
						 * - The processReceivingBuffer() method will not be called properly if processing > receiving.
						 */
						sendAck(receivingSequence);
						receivingSequence.moveNext();
					}
					processingSequence.moveNext();
				}

				handleDatagram(datagram.getData());
			} else {
				break;
			}
		}

		return stepCount;
	}

	/**
	 * Checks if the potentially fragmented datagram, starting at the given position, is completed.
	 * Meaning that all of its fragments are already stored in the buffer and in the correct order.
	 *
	 * @returns The length in bytes of the datagram, or `0` if there is no completed datagram.
	 */
	@:noCompletion
	private final function getCompletedDatagramAt(sequenceNum:Sequence):Int {
		var datagramLength:Int = 0;
		var previousFragmentNum:Int = 0;

		while (!receivingBuffer.isEmpty(sequenceNum)) {
			var fragment:Bytes = Bytes.ofData(receivingBuffer.get(sequenceNum));

			// Get the first byte, which is the fragment number.
			var fragmentNum:Int = fragment.get(0);
			var fragmentPayloadLength:Int = fragment.length - 1;

			datagramLength += fragmentPayloadLength;

			if (previousFragmentNum > 0 && fragmentNum != previousFragmentNum - 1) {
				throw 'Inconsistent fragment numbers: $previousFragmentNum->$fragmentNum';
			}

			if (fragmentNum == 0) {
				return datagramLength;
			}

			previousFragmentNum = fragmentNum;
			sequenceNum.moveNext();
		}

		return 0;
	}

	@:noCompletion
	private final function onReceivedAck(sequenceNumberAcked:Sequence) {
		if (sequenceNumberAcked == sendingAckSequence) {
			/*
			 * Received an expected ACK on-sequence.
			 * Cleared the ACKed datagram from the sending buffer,
			 * as well as any datagrams before it.
			 */
			var bufferClearSequence:Sequence = sendingAckSequence.getAndMoveNext();

			while (!sendingBuffer.isEmpty(bufferClearSequence) && bufferClearSequence != sendingAckSequence) {
				sendingBuffer.clear(bufferClearSequence);
				bufferClearSequence.movePrevious();
			}
		} else {
			/*
			 * We received an ACK for a datagram that was not the last on the sequence.
			 * Resend the datagram that is after the one being acknowledged.
			 */
			sendingAckSequence.set(sequenceNumberAcked.next);

			if (sendingBuffer.isStale(sendingAckSequence)) {
				transmitFromBuffer(sendingAckSequence);
			}
		}
	}

	@:noCompletion
	private final function sendAck(sequenceNumber:Sequence) {
		// Upda the receiving ack sequence to point to the last number ACKed.
		// trace('1 - receivingAckSequence $receivingAckSequence');
		receivingAckSequence.set(sequenceNumber);
		// trace('2 - receivingAckSequence $receivingAckSequence');
		// Refresh the timestamp on the datagram being ACKed.
		sendingBuffer.refresh(sequenceNumber);
		sequenceBuffer.setInt32(0, sequenceNumber, true);
		sendingSequenceBuffer.setUint8(0, sequenceBuffer.getUint8(0));
		sendingSequenceBuffer.setUint8(1, sequenceBuffer.getUint8(1));
		sendingSequenceBuffer.setUint8(2, sequenceBuffer.getUint8(2));

		// var ackDatagram: Bytes = sequenceNumber.toBytes();
		onTransmit(sendingSequenceBuffer.buffer);
	}

	@:noCompletion
	private final function transmitFromBuffer(bufferIndex:Int) {
		var datagram:BytesData = sendingBuffer.get(bufferIndex);
		sendingBuffer.refresh(bufferIndex);
		onTransmit(datagram);
	}

	@:noCompletion
	private final function handleDatagram(datagram:BytesData) {
		onMessageReceived(datagram);
	}

	@:noCompletion @:protected @IgnoreCover
	function onTransmit(datagram:BytesData) {
		throw "Not implemented, function should be overriden.";
	}

	@:noCompletion @:protected @IgnoreCover
	function onMessageReceived(message:BytesData) {
		throw "Not implemented, function should be overriden.";
	}
}
