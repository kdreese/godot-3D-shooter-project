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


# Spawn the player that we are controlling.
func spawn_player() -> void:
	super.spawn_player()
	if is_multiplayer_authority():
		my_player.player_death.connect(self.check_for_last_team_standing)


# Spawn a player controlled by another person.
@rpc("any_peer")
func spawn_peer_player(player_id: int) -> void:
	super.spawn_peer_player(player_id)
	if is_multiplayer_authority():
		$Players.get_node(str(player_id)).player_death.connect(self.check_for_last_team_standing)


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


func check_for_last_team_standing() -> void:
	var remaining_teams := 0
	for team: Array in team_roster.values():
		for member_info: Multiplayer.PlayerInfo in team:
			var member: Player = $Players.get_node(str(member_info.id))
			if member.state == Player.PlayerState.NORMAL:
				remaining_teams += 1
				break
	if remaining_teams <= 1:
		end_of_match.rpc()
