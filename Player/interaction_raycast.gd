extends RayCast3D

@onready var interaction_raycast = $"."
@onready var interaction_text = $interaction_text

var collider

func _physics_process(delta):
	collider = self.get_collider()
	
	if self.is_colliding():
		if collider.is_in_group("interactable"):
			interaction_text.show()
			if Input.is_action_just_pressed("interact"):
				pass # collider.interact()
		else:
			interaction_text.hide()
	else:
		interaction_text.hide()
