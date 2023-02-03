extends KinematicBody


const GRAVITY = 9.8

var archer
var velocity: Vector3
var desired_dir: Vector3
var stuck


func _physics_process(delta: float) -> void:
	if not stuck:
		velocity.y -= GRAVITY * delta
		desired_dir = translation + velocity
		look_at(desired_dir, Vector3.UP)
	var collision = move_and_collide(velocity * delta)
	if collision:
		velocity = Vector3.ZERO
		stuck = true
