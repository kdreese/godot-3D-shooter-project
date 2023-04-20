extends Node3D


const PAN_CIRCLE_CENTER: Vector3 = Vector3(0, 20, 0)
const PAN_CIRCLE_RADIUS: float = 12.5
const ANGLE_OF_DEPRESSION: float = deg_to_rad(-35)


@onready var camera: Camera3D = %Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Despawn all the targets.
	var nodes := get_tree().get_nodes_in_group("Targets") as Array
	nodes = Utils.shuffle(nodes)
	for idx in range(len(nodes) - 6):
		nodes[idx].queue_free()
	var pan := get_tree().create_tween()
	pan.bind_node(self)
	pan.set_trans(Tween.TRANS_LINEAR)
	pan.set_loops()
	pan.tween_method(self.set_camera_transform, 0.0, 2 * PI, 30.0)
	pan.play()


func set_camera_transform(angle: float) -> void:
	camera.position = PAN_CIRCLE_CENTER + PAN_CIRCLE_RADIUS * Vector3(cos(angle), 0.0, -sin(angle))
	camera.rotation = Vector3(ANGLE_OF_DEPRESSION, angle + PI/2, 0.0)
