extends Area3D

@export var stick_drag := 0.15
@export var climb_boost := 5.0

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody3D:
			var cbody := body as CharacterBody3D
			cbody.velocity.x *= stick_drag
			cbody.velocity.z *= stick_drag
			# Give a little upward push to let the slime "climb".
			cbody.velocity.y = max(cbody.velocity.y, climb_boost)
