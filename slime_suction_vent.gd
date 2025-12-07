extends Area3D

@export var pull_strength := 18.0
@export var spin_force := 6.0
@export var range := 6.0

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody3D:
			var cbody := body as CharacterBody3D
			var to_center := global_transform.origin - cbody.global_transform.origin
			var dist := to_center.length()
			if dist < 0.001 or dist > range:
				continue
			var dir := to_center.normalized()
			cbody.velocity += dir * pull_strength * (1.0 - dist / range)
			var spin_dir := dir.cross(Vector3.UP).normalized()
			cbody.velocity += spin_dir * spin_force * (1.0 - dist / range)
