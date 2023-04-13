extends CharacterBody3D


const GRAVITY := 15.0
const MAX_STUCK_TIME := 10
const FADEOUT_TIME := 0.5
const COLLISION_DELAY := 0.05

var archer: CharacterBody3D		# the player who shot the arrow
var desired_dir: Vector3
var stuck := false		# whether the arrow has hit a wall

func remove_collision() -> void:
	collision_layer = 0

func _physics_process(delta: float) -> void:
	if stuck:
		return
	velocity.y -= GRAVITY * delta
	desired_dir = position + velocity
	look_at(desired_dir, Vector3.UP)
	var collision = move_and_collide(velocity * delta)
	if collision:
		velocity = Vector3.ZERO
		stuck = true
		get_tree().create_timer(MAX_STUCK_TIME).timeout.connect(queue_free)
		get_tree().create_timer(COLLISION_DELAY).timeout.connect(remove_collision)
