class_name Requestor
extends Node


var registered_requests := {}


func register(func_name: String, predicate: Callable) -> void:
	if func_name in registered_requests:
		push_error("Request with that name already connected")
		return

	registered_requests[func_name] = predicate


@rpc("any_peer")
func request(func_name: String, params: Array = []) -> void:
	if func_name not in registered_requests:
		push_error("Requested callback with name %s does not exist" % func_name)
		return

	var callback = registered_requests[func_name] as Callable

	if is_multiplayer_authority():
		var remote_id := multiplayer.get_remote_sender_id()
		if remote_id == 0 or Multiplayer.is_id_leader(remote_id):
			callback.bindv(params).rpc()
	else:
		request.rpc_id(1, func_name, params)
