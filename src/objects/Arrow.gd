extends KinematicBody


const GRAVITY := 9.8
const MAX_STUCK_TIME := 10
const FADEOUT_TIME := 0.5

var archer: KinematicBody		# the player who shot the arrow
var velocity: Vector3
var desired_dir: Vector3
var stuck := false		# whether the arrow has hit a wall


func _physics_process(delta: float) -> void:
	if stuck:
		collision_layer = 0
		return
	velocity.y -= GRAVITY * delta
	desired_dir = translation + velocity
	look_at(desired_dir, Vector3.UP)
	var collision = move_and_collide(velocity * delta)
	if collision:
		velocity = Vector3.ZERO
		stuck = true
		get_tree().create_timer(MAX_STUCK_TIME).connect("timeout", self, "queue_free")