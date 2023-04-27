@tool
extends Node3D


@export var pan_circle_center: Vector3 = Vector3(0, 20, 0)
@export var pan_circle_radius: float = 12.5
@export_range(0, 360) var pan_angle: float = 0
@export_range(0, 90) var angle_of_depression: float = 0


@onready var camera: Camera3D = %Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Despawn all the targets.
	var nodes := get_tree().get_nodes_in_group("Targets") as Array
	nodes = Utils.shuffle(nodes)
	for idx in range(len(nodes) - 6):
		nodes[idx].queue_free()
	if not Engine.is_editor_hint():
		var pan := get_tree().create_tween()
		pan.bind_node(self)
		pan.set_trans(Tween.TRANS_LINEAR)
		pan.set_loops()
		pan.tween_method(self.set_pan_angle, 0.0, 360.0, 30.0)
		pan.play()


func _process(_delta):
	var pan_angle_rad = deg_to_rad(pan_angle)
	var towards_center := Vector3(cos(pan_angle_rad), 0.0, -sin(pan_angle_rad))
	camera.position = pan_circle_center + pan_circle_radius * towards_center
	camera.rotation = Vector3(deg_to_rad(-angle_of_depression), pan_angle_rad + PI/2, 0.0)


func set_pan_angle(angle: float):
	pan_angle = angle
