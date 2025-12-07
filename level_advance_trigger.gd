extends Area3D

@export var target_scene_path := "res://SlimeSanctuary.tscn"

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		get_tree().change_scene_to_file(target_scene_path)
