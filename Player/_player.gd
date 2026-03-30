extends CharacterBody3D

# =========================
# CONFIG
# =========================
const GRAVITY := 9.8
const JUMP_VELOCITY := 4.5

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0

const ACCEL := 10.0
const AIR_CONTROL := 3.0
const FRICTION := 8.0

const SENSITIVITY := 0.005

# Movement states
var sprinting := false
var walking := false

# Speed control
var speed := WALK_SPEED
var lerp_speed := 10.0
var air_lerp_speed := 3.0

# Direction-based movement
var direction: Vector3 = Vector3.ZERO

# =========================
# STATE
# =========================
var health := 100
var input_dir := Vector2.ZERO
var is_sprinting := false
var wants_jump := false
var jump_velocity = 4.0

# =========================
# MULTIPLAYER
# =========================
var target_position: Vector3
var target_velocity: Vector3
var target_yaw: float
var target_pitch: float
var current_anim: String = ""
var target_anim: String = ""

# =========================
# NODES
# =========================
@export var bullet_scene: PackedScene

@onready var head = $player_head
@onready var camera = $player_head/player_camera
@onready var interaction_raycast = $player_head/player_camera/interaction_raycast
@onready var muzzle = $player_head/player_camera/muzzle
@onready var animation_player: AnimationPlayer = $animation_player

func _ready():
	print("Player ", name, " authority: ", get_multiplayer_authority(), " | my id: ", multiplayer.get_unique_id())
	if !is_multiplayer_authority():
		camera.current = false

# =========================
# INPUT (FRAME-BASED)
# =========================
		
	
func _process(_delta):
	if not is_multiplayer_authority():
		return

	input_dir = Input.get_vector("right", "left", "back", "forward")

	if Input.is_action_just_pressed("interact"):
		interact()

# =========================
# LOOK (EVENT-BASED)
# =========================
func _input(event):
	# UI should ALWAYS work locally
	if event.is_action_pressed("ui_cancel"):

		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	if Input.is_action_just_pressed("shoot"):
		shoot()

	# Only block gameplay input
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(70))

# =========================
# PHYSICS (CLEAN)
# =========================
func _physics_process(delta):
	if is_multiplayer_authority():
		apply_gravity(delta)
		handle_jump()
		handle_movement(delta)

		move_and_slide()

		update_animation_state()

		rpc("sync_movement",
			global_transform.origin,
			velocity,
			head.rotation.y,
			camera.rotation.x
		)
	else:
		# Smooth position
		global_transform.origin = global_transform.origin.lerp(target_position, 10 * delta)

		# Smooth velocity (optional but helps)
		velocity = velocity.lerp(target_velocity, 10 * delta)

		# Smooth body rotation (yaw)
		var current_yaw = head.rotation.y
		head.rotation.y = lerp_angle(current_yaw, target_yaw, 10 * delta)

		# Smooth camera pitch
		var current_pitch = camera.rotation.x
		camera.rotation.x = lerp(current_pitch, target_pitch, 10 * delta)
		
		if target_anim != current_anim:
			current_anim = target_anim
			play_animation(current_anim)

# =========================
# MOVEMENT
# =========================
func handle_movement(delta):
	handle_sprint(delta)

	var target_dir = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor():
		direction = direction.lerp(target_dir, delta * lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = direction.lerp(target_dir, delta * air_lerp_speed)

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func handle_sprint(delta):
	if Input.is_action_pressed("sprint"):
		sprinting = true
		walking = false
		speed = lerp(speed, SPRINT_SPEED, delta * lerp_speed)
	else:
		sprinting = false
		walking = true
		speed = lerp(speed, WALK_SPEED, delta * lerp_speed)

# =========================
# GRAVITY / JUMP
# =========================
func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

		if is_multiplayer_authority():
			play_animation("Jump")
			rpc("sync_animation", "jump")

# =========================
# INTERACTION
# =========================
func interact():
	var collider = interaction_raycast.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact()
		
func shoot():
	if not is_multiplayer_authority():
		return

	var origin = muzzle.global_transform.origin
	var direction = -camera.global_transform.basis.z.normalized()

	if multiplayer.is_server():
		request_shoot(origin, direction)
	else:
		rpc_id(1, "request_shoot", origin, direction)

func apply_damage(amount, attacker_id):
	if not multiplayer.is_server():
		return

	health -= amount

	if health <= 0:
		die(attacker_id)

func die(attacker_id):
	print("Player ", name, " killed by ", attacker_id)

# =========================
# ANIMATION
# =========================
func play_animation(anim_name: String):
	if animation_player.current_animation == anim_name:
		return

	animation_player.play(anim_name)

# =========================
# MULTIPLAYER
# =========================
@rpc("unreliable")
func sync_movement(pos, vel, yaw, pitch):
	if is_multiplayer_authority():
		return

	target_position = pos
	target_velocity = vel
	target_yaw = yaw
	target_pitch = pitch

@rpc("any_peer")
func request_shoot(origin, direction):
	if not multiplayer.is_server():
		return

	var shooter_id = multiplayer.get_remote_sender_id()
	if shooter_id == 0:
		shooter_id = multiplayer.get_unique_id()

	get_tree().current_scene.spawn_bullet(origin, direction, shooter_id)

func update_animation_state():
	var new_anim = "Idle"

	if not is_on_floor():
		new_anim = "Jump"
	elif velocity.length() > 0.1:
		if sprinting:
			new_anim = "Sprint"
		else:
			new_anim = "Walk"
	else:
		new_anim = "Idle"

	if new_anim != current_anim:
		current_anim = new_anim
		play_animation(current_anim)

		if is_multiplayer_authority():
			rpc("sync_animation", current_anim)

@rpc("unreliable")
func sync_animation(anim_name):
	if is_multiplayer_authority():
		return

	target_anim = anim_name
