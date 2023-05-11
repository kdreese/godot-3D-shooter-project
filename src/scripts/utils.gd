extends Node
class_name Utils


# Shuffle the contents of an array.
static func shuffle(array_in: Array) -> Array:
	var array_out := []
	while len(array_in) > 0:
		var idx := randi() % len(array_in)
		var obj = array_in.pop_at(idx)
		array_out.push_back(obj)
	return array_out


# Given a time in seconds, return a formatting string MM:SS.S, rounded to .1 seconds
static func format_time(time: float, round_up := false) -> String:
	if round_up:
		time = ceil(10 * time) / 10
	else:
		time = floor(10 * time) / 10
	var is_neg := time < 0
	if is_neg:
		time = -time
	var minutes := floori(time / 60)
	var seconds := fmod(time, 60.0)
	return "%s%d:%04.1f" % ["-" if is_neg else "", minutes, seconds]
