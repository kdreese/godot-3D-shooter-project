class_name GMPClientClass
extends Node
## Client for interacting with the host server using the Game Management Protocol (GMP)
##
## This class should be used for all communication between game instances and the host server, for
## things such as creating and browsing games to join.
##
## This class is designed to be asynchronous.



const PROTOCOL_VERSION := 1 ## The GMP version
const HOSTNAME := "localhost"
const PORT := 6789


@onready var http_request := HTTPRequest.new()


func _ready() -> void:
	add_child(http_request)


## Request the server to create a game.
##
## Returns an Array with the first element being an Error, and the second being a GameParams
## instance if the Error is OK
func request_game(server_name: String, max_players: int) -> Array:
	if max_players < 2 or max_players > 8:
		return [ERR_INVALID_PARAMETER]

	if len(server_name) > 32:
		return [ERR_INVALID_PARAMETER]

	var request := {
		"protocol_version": PROTOCOL_VERSION,
		"max_players": max_players,
		"server_name": server_name,
	}

	var error = http_request.request("http://127.0.0.1:6789", PackedStringArray(), HTTPClient.METHOD_POST, str(request))
	if error != OK:
		print("Error: ", error)
		return [error]

	var response = await http_request.request_completed

	print(response)
	return [OK]

class GameParams:
	var a: int
