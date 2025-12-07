extends Area3D

@export var launch_velocity := 12.0
@export var bonus_per_down_speed := 0.6
@export var max_launch := 26.0

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		var cbody := body as CharacterBody3D
		var down_speed: float = max(-cbody.velocity.y, 0.0)
		var bonus: float = down_speed * bonus_per_down_speed
		var target: float = clampf(launch_velocity + bonus, launch_velocity, max_launch)
		cbody.velocity.y = max(cbody.velocity.y, target)
