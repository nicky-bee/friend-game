extends CharacterBody3D

const GRAVITY := 9.8
const LIFETIME := 5.0

var damage := 100
var shooter_id := -1

var life_timer := 0.0

func _physics_process(delta):
	life_timer += delta
	if life_timer > LIFETIME:
		queue_free()
		return

	# Apply gravity (bullet drop)
	velocity.y -= GRAVITY * delta

	var collision = move_and_collide(velocity * delta)

	if collision:
		var collider = collision.get_collider()

		if collider.is_in_group("entity"):
			collider.apply_damage(damage, shooter_id)

		queue_free()
