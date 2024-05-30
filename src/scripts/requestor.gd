class_name Requestor
extends Node


## Dictionary from callback name to an object containing the callback Callable and the condition
## Callable
var registered_requests := {}


## Register a callback for this requestor.
##
## func_name is the name for the callback.
##
## callback is a Callable object representing the desired outcome on all clients if the condition
## is true
##
## condition is a Callable object that returns true on the multiplayer authority only if the desired
## actiona should actually be taken.
func register(func_name: String, callback: Callable, condition: Callable) -> void:
	if func_name in registered_requests:
		push_error("Request with that name already connected")
		return

	registered_requests[func_name] = {"callback": callback, "condition": condition}


## Request a callback from the multiplayer authority.
##
## func_name is the name of the callback.
##
## params is a list of arguments to the registered callback Callable.
@rpc("any_peer")
func request(func_name: String, params: Array = []) -> void:
	if func_name not in registered_requests:
		push_error("Requested callback with name %s does not exist" % func_name)
		return

	var callback := registered_requests[func_name]["callback"] as Callable
	var condition := registered_requests[func_name]["condition"] as Callable

	if is_multiplayer_authority():
		if condition.call():
			callback.bindv(params).rpc()
	else:
		request.rpc_id(1, func_name, params)
