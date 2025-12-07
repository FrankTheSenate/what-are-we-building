extends Area3D

@export var horizontal_drag := 0.35
@export var upward_drift := 2.5

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody3D:
			var cbody := body as CharacterBody3D
			cbody.velocity.x *= horizontal_drag
			cbody.velocity.z *= horizontal_drag
			cbody.velocity.y = max(cbody.velocity.y, upward_drift)
