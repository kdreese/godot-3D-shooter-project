class_name GMPClientClass
extends Node
## Client for interacting with the host server using the Game Management Protocol (GMP)
##
## This class should be used for all communication between game instances and the host server, for
## things such as creating and browsing games to join.
##
## This class is designed to be asynchronous.



const PROTOCOL_VERSION := 1 ## The GMP version
const HOST := "http://192.168.1.4:6789"


@onready var http_request := HTTPRequest.new()


func _ready() -> void:
	add_child(http_request)


## Make a generic HTTP request.
## The returned value is an [Array] with the first member being an [Error], and the second being the
## response. In case of an error, the response will always be formatted as
## `{ "error": <String> }.
func make_request(method: HTTPClient.Method, request: Dictionary) -> Array:
	var error = http_request.request(HOST, PackedStringArray(), method, str(request))
	if error:
		return [error, {"error": "Could not connect to server."}]

	var http_response = await http_request.request_completed

	if http_response[0]:
		return[http_response[0], {"error": "Could not connect to server."}]


	var resp_string = http_response[3].get_string_from_utf8()
	var json = JSON.new()
	error = json.parse(resp_string)
	if error != OK:
		return [error, {"error": "Error parsing JSON response from server."}]

	if http_response[1] == HTTPClient.RESPONSE_OK:
		return [OK, json.data]
	else:
		return [ERR_CONNECTION_ERROR, json.data]

## Request the server to create a game.
##
## Returns an Array with the first element being an Error, and the second being the error response,
## if applicable.
func request_game(params: GameParams) -> Array:
	if params.max_players < 2 or params.max_players > 8:
		return [ERR_INVALID_PARAMETER, {"error": "Invalid max number of players."}]

	if len(params.server_name) > 32:
		return [ERR_INVALID_PARAMETER, {"error": "Server name too long."}]

	var request := {
		"protocol_version": PROTOCOL_VERSION,
		"max_players": params.max_players,
		"server_name": params.server_name,
	}

	var response = await make_request(HTTPClient.METHOD_POST, request)
	if response[0]:
		# There were errors, pass them along.
		return response
	else:
		params.host = response[1]["host"]
		params.port = response[1]["port"]
		return [OK]


class GameParams:
	var server_name: String = ""
	var max_players: int = 8
	var host: String = ""
	var port: int = 0

