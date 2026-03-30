extends Control

const PORT = 9999

func host_game():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", PORT)

func join_game(ip):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer

	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	print("Joining ", ip)


func _on_host_pressed():
	host_game()

func _on_join_pressed():
	var ip = $PanelContainer/VBoxContainer/ip_input.text
	join_game(ip)
