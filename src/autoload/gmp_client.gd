class_name GMPClientClass
extends Node
## Client for interacting with the host server using the Game Management Protocol (GMP)
##
## This class should be used for all communication between game instances and the host server, for
## things such as creating and browsing games to join.
##
## This class is designed to be asynchronous.


const PROTOCOL_VERSION := 1 ## The GMP version
const HEADERS = ["User-Agent: Godot"]
const HOST := "https://api.admoore.xyz/godot-3d-shooter"


## Make a generic HTTP request.
## The returned value is an [Array] with the first member being an [Error], and the second being the
## response. In case of an error, the response will always be formatted as
## `{ "error": <String> }.
func make_request(host: String, method: HTTPClient.Method, request: Dictionary) -> Array:
	var http_request := HTTPRequest.new()
	add_child(http_request)
	var error: Error
	if request != {}:
		error = http_request.request(host, HEADERS, method, str(request))
	else:
		error = http_request.request(host, HEADERS, method)

	if error:
		http_request.queue_free()
		remove_child(http_request)
		return [error, {"error": "Could not connect to server."}]

	var http_response = await http_request.request_completed

	http_request.queue_free()
	remove_child(http_request)

	if http_response[0]:
		return[http_response[0], {"error": "Could not connect to server."}]

	# HTTP code 500 and above indicate that the server is probably down.
	if http_response[1] >= 500:
		return [ERR_CANT_CONNECT, {"error": "Game server is temporarily offline."}]

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
		"action": "create_game",
		"max_players": params.max_players,
		"server_name": params.server_name,
	}

	if params.password_hash != "":
		request["password_hash"] = params.password_hash

	var response = await make_request(HOST, HTTPClient.METHOD_POST, request)
	if response[0]:
		# There were errors, pass them along.
		return response
	else:
		params.host = response[1]["host"]
		params.port = response[1]["port"]
		return [OK]


## Request the server for new game info.
##
## Returns an Array with the first element being an Error, and the second being the error response,
## if applicable.
func get_game_info(games: Array[GameParams]) -> Array:
	games.clear()

	var url = HOST + "games?protocol_version=" + str(PROTOCOL_VERSION)

	var response = await make_request(url, HTTPClient.METHOD_GET, {})

	if response[0]:
		return response
	else:
		for game_json in response[1]["games"]:
			games.append(GameParams.from_json(game_json))
		return [OK]


## Request the server to update a game's player count.
##
## Returns an Array with the first element being an Error, and the second being the error response,
## if applicable.
func update_player_count(game_id: int, new_player_count: int) -> Array:
	var request := {
		"protocol_version": PROTOCOL_VERSION,
		"action": "update_player_count",
		"game_id": game_id,
		"new_player_count": new_player_count,
	}

	return await make_request(HOST, HTTPClient.METHOD_POST, request)


## Request the server to stop a game.
##
## Returns an Array with the first element being an Error, and the second being the error response,
## if applicable.
func stop_game(game_id: int) -> Array:
	var request := {
		"protocol_version": PROTOCOL_VERSION,
		"action": "stop_game",
		"game_id": game_id
	}

	return await make_request(HOST, HTTPClient.METHOD_POST, request)


class GameParams:
	var game_id: int = 0
	var server_name: String = ""
	var max_players: int = 8
	var current_players: int = 0
	var private: bool = false
	var password_hash: String = ""
	var host: String = ""
	var port: int = 0

	static func from_json(data: Dictionary) -> GameParams:
		var params = GameParams.new()
		params.game_id = data["game_id"]
		params.server_name = data["server_name"]
		params.max_players = data["max_players"]
		params.current_players = data["current_players"]
		params.private = data.get("private", false)
		params.host = data["host"]
		params.port = data["port"]
		return params
