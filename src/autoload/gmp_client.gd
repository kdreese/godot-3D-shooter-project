class_name GMPClientClass
extends Node
## Client for interacting with the host server using the Game Management Protocol (GMP)
##
## This class should be used for all communication between game instances and the host server, for
## things such as creating and browsing games to join.
##
## This class is designed to be synchronous, so sending and receiving data will block the calling
## thread

const CONNECTION_TIMEOUT := 5.0 ## The connection timeout (in seconds)

const PROTOCOL_VERSION := 1 ## The GMP version

signal connected(Error) ## The client connected to the server.
signal disconnected ## The client disconnected from the server.
signal connection_error(Error) ## The client encountered an error.
signal response(PackedByteArray) ## A response packet was received from the server.


@onready var peer := StreamPeerTCP.new()
@onready var connection_timer := Timer.new()


var status := peer.STATUS_NONE;
var received_packet: PackedByteArray = []


func _ready() -> void:
	add_child(connection_timer)
	connection_timer.one_shot = true


func _process(_delta: float) -> void:
	peer.poll()
	var new_status := peer.get_status()
	match [status, new_status]:
		[_, peer.STATUS_ERROR]:
			connection_error.emit(ERR_CONNECTION_ERROR)
		[peer.STATUS_NONE, peer.STATUS_CONNECTED]:
			connected.emit(OK)
		[peer.STATUS_CONNECTING, peer.STATUS_CONNECTED]:
			connected.emit(OK)
		[peer.STATUS_NONE, peer.STATUS_NONE]:
			pass # Do nothing, only match so the below doesn't generate false alarms.
		[_, peer.STATUS_NONE]:
			disconnected.emit()
		[_, peer.STATUS_CONNECTING]:
			if connection_timer.time_left == 0.0:
				peer.disconnect_from_host()
				connected.emit(ERR_TIMEOUT)

	status = new_status

	if status == peer.STATUS_CONNECTED:
		var num_bytes := peer.get_available_bytes()
		if num_bytes > 0:
			var resp := peer.get_data(num_bytes)
			if resp[0] != OK:
				connection_error.emit(resp[0])
			received_packet += PackedByteArray(resp[1])
			if is_complete_packet(received_packet):
				if (received_packet[0] & 0xF0) >> 4 != PROTOCOL_VERSION:
					# If there's a version mismatch, still emit the signal, to unblock.
					response.emit([])
				else:
					response.emit(received_packet.duplicate().slice(2))
				received_packet = []


## Return true if this is a complete GMP packet.
func is_complete_packet(packet: PackedByteArray) -> bool:
	var length := ((packet[0] & 0xF) << 8) | packet[1]
	# We are only ever sending one packet at a time, so we should not have to worry about getting
	# more bytes than stated.
	if len(packet) >= length:
		return true
	else:
		return false


## Connect the client to a host.
func connect_to_host(host: String, port: int) -> Error:
	if status == peer.STATUS_CONNECTED or status == peer.STATUS_CONNECTING:
		push_error("The peer is already connected or attempting to connect.")
		return ERR_CONNECTION_ERROR

	var error := peer.connect_to_host(host, port)
	if error != OK:
		push_error("Error when attempting to connect: ", error)
		return error

	peer.set_no_delay(true)

	connection_timer.start(CONNECTION_TIMEOUT)
	return OK


## Disconnect the client. Wrapper created for convenience.
func disconnect_from_host() -> void:
	peer.disconnect_from_host()


## Send a byte array. The input argument is assumed not to have the 2-byte GMP header.
func send_bytes(packet: PackedByteArray) -> Error:
	var out: PackedByteArray = []
	# Need to add 2 to account for the header.
	var length := len(packet) + 2
	if length >= 4096:
		# Packets can only have a length that is 12 bytes long or less.
		return ERR_INVALID_DATA

	out.append(((PROTOCOL_VERSION & 0xF) << 4) | ((length & 0xF00) >> 8))
	out.append(length & 0xFF)
	out += packet

	var error := peer.put_data(out)
	return error
