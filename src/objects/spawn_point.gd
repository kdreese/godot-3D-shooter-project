extends Node3D
class_name SpawnPoint


@onready var exclusion_zone = $ExclusionZone


# The player currently associated with this spawn point, or -1 if there are no players.
var assigned_player_id: int = -1


func _ready():
	hide()


# Returns true if there are no players (except possibly the player that is spawning) within the
# exclusion zone.
# :param player_id: The player that is spawning.
func available(player_id: int) -> bool:
	# If this spawn point is already assigned to someone, it is not available.
	if assigned_player_id != -1:
		return false
	var players_in_zone := exclusion_zone.get_overlapping_bodies() as Array[Node3D]
	if len(players_in_zone) == 0:
		return true
	elif len(players_in_zone) == 1 and players_in_zone[0].name == str(player_id):
		return true
	else:
		return false
