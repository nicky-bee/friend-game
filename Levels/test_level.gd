extends Node3D

@export var player_scene: PackedScene
@export var bullet_scene: PackedScene

@onready var menu = $MultiplayerMenu

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)

	# Spawn your local player if server or client
	if multiplayer.is_server() or multiplayer.is_client():
		spawn_player(multiplayer.get_unique_id())

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		menu.visible = !menu.visible

		if menu.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

@rpc("any_peer")
func spawn_player(id):
	# Only spawn if this player doesn't exist yet
	if get_node_or_null(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	add_child(player)

	# Assign authority
	player.set_multiplayer_authority(id)

	# Enable camera only for local player
	if player.is_multiplayer_authority():
		player.camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_peer_connected(id):
	if multiplayer.is_server():
		# Tell the new peer to spawn themselves
		rpc_id(id, "spawn_player", id)
		
		# Also tell everyone else to spawn the new player
		for peer_id in multiplayer.get_peers():
			if peer_id != id:
				rpc_id(peer_id, "spawn_player", id)

func _on_connected():
	print("Connected to server!")
	spawn_player.rpc_id(1, multiplayer.get_unique_id())
	
func _on_peer_disconnected(id):
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func spawn_bullet(origin, direction, shooter_id):
	if not multiplayer.is_server():
		return

	# Tell everyone to spawn it visually
	rpc("spawn_bullet_remote", origin, direction, shooter_id)
	
@rpc("call_local")
func spawn_bullet_remote(origin, direction, shooter_id):
	var bullet = bullet_scene.instantiate()
	add_child(bullet)

	bullet.global_transform.origin = origin
	bullet.velocity = direction * 50.0
	bullet.shooter_id = shooter_id
