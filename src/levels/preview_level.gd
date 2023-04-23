@tool
extends Node3D


@export var running: bool = false
@export var pan_circle_center: Vector3 = Vector3(0, 20, 0)
@export var pan_circle_radius: float = 12.5
@export_range(0, 90) var angle_of_depression: float = 0


@onready var camera: Camera3D = %Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	running = true
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
	if running:
		camera.position = pan_circle_center + pan_circle_radius * Vector3(cos(angle), 0.0, -sin(angle))
		camera.rotation = Vector3(deg_to_rad(-angle_of_depression), angle + PI/2, 0.0)
	else:
		camera.position = pan_circle_center + pan_circle_radius * Vector3.RIGHT
		camera.rotation = Vector3(deg_to_rad(-angle_of_depression), PI/2, 0.0)
