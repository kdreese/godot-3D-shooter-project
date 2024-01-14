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
func request_game(params: GameParams) -> Error:
	if params.max_players < 2 or params.max_players > 8:
		return ERR_INVALID_PARAMETER

	if len(params.server_name) > 32:
		return ERR_INVALID_PARAMETER

	var request := {
		"protocol_version": PROTOCOL_VERSION,
		"max_players": params.max_players,
		"server_name": params.server_name,
	}

	var error = http_request.request("http://192.168.1.4:6789", PackedStringArray(), HTTPClient.METHOD_GET, str(request))
	if error != OK:
		print("Error: ", error)
		return error

	var response = await http_request.request_completed

	if response[1] == 200:
		var resp_string = response[3].get_string_from_utf8()
		var json = JSON.new()
		json.parse(resp_string)
		var data = json.data

		params.host = data["host"]
		params.port = data["port"]
		return OK
	else:
		return ERR_CONNECTION_ERROR

class GameParams:
	var server_name: String = ""
	var max_players: int = 8
	var host: String = ""
	var port: int = 0

