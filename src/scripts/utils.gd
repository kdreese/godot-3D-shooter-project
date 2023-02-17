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
