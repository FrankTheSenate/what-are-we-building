extends Area3D

@export var launch_direction := Vector3(0, 1, 0)
@export var launch_strength := 16.0

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		var dir := launch_direction.normalized()
		var cbody := body as CharacterBody3D
		cbody.velocity += dir * launch_strength
