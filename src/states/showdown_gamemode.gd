extends Gamemode


func _ready() -> void:
	curr_level = preload("res://src/levels/arena.tscn").instantiate() as Node3D
	add_child(curr_level)

	super._ready()

	# The base arena has all of the targets in the scene,
	# so we have to destroy any existing targets
	var targets := get_targets()
	for target in targets:
		target.queue_free()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if game_state == GameState.ENDED:
		match_timer.text = "Time's up!"
		return


func everyone_gets_an_arrow(id: String, power: float) -> void:
	var player := $Players.get_node(id)
	super.everyone_gets_an_arrow(id, power)
	if player.state == Player.PlayerState.NORMAL and player.num_arrows > 0: # if player meets the requirements to be able to shoot
		player.num_arrows -= 1
		rpc_id(int(id), "update_quiver_amt", player.num_arrows)


func spawn_arrow(id: String, power: float) -> ArrowObject:
	var new_arrow = super.spawn_arrow(id, power)
	new_arrow.spawn_pickup.connect(self.on_arrow_pickup_spawn)
	return new_arrow
