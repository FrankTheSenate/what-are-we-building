extends Node3D

@export var player_scene: PackedScene = preload("res://PlayerChar.tscn")
@export var orb_scene: PackedScene = preload("res://OrbFollower.tscn")
@export var goblin_scene: PackedScene = preload("res://Goblin.tscn")
@export var spawn_player_at: Vector3 = Vector3(0.0, 4.587867, 0.0)
@export var orb_offset: Vector3 = Vector3(5.0, 1.5, 0.0)
@export var goblin_spawn: Vector3 = Vector3(4.0, 0.45, 4.0)
@export var spawn_powerups := true
@export var powerup_spawn_interval := 8.0
@export var powerup_spawn_radius := 20.0
@export var powerup_min_spawn_radius := 6.0
@export var powerup_max := 5

var _registry: Node = null

func _ready() -> void:
	_registry = get_node_or_null("/root/Registry")
	var player := _spawn_player()
	var orb := _spawn_orb(player)
	var goblin := _spawn_goblin(player)
	if spawn_powerups:
		_spawn_powerups(player)
	_register("player", player)
	_register("orb", orb)
	_register("goblin", goblin)


func _spawn_player() -> Node:
	if player_scene == null:
		return null
	var player := player_scene.instantiate()
	add_child(player)
	if player is Node3D:
		player.transform.origin = spawn_player_at
	return player


func _spawn_orb(player: Node) -> Node:
	if orb_scene == null:
		return null
	var orb := orb_scene.instantiate()
	add_child(orb)
	if orb is Node3D:
		var start := spawn_player_at + orb_offset
		orb.transform.origin = start
	if player and orb.has_method("set"):
		if orb.has_method("set_target"):
			orb.call("set_target", player)
		elif orb.has_method("set_target_path") and orb is Node3D:
			var path := orb.get_path_to(player)
			orb.call("set_target_path", path)
		else:
			var path := orb.get_path_to(player)
			orb.set("target_path", path)
	return orb


func _spawn_goblin(player: Node) -> Node:
	if goblin_scene == null:
		return null
	var goblin := goblin_scene.instantiate()
	add_child(goblin)
	if goblin is Node3D:
		goblin.transform.origin = goblin_spawn
	if player and goblin.has_method("set"):
		var path := goblin.get_path_to(player) if goblin is Node3D else NodePath("")
		if goblin.has_method("set_target_path"):
			goblin.call("set_target_path", path)
		else:
			goblin.set("target_path", path)
	return goblin


func _spawn_powerups(player: Node) -> void:
	var spawner := Node3D.new()
	spawner.set_script(load("res://powerup_spawner.gd"))
	spawner.set("spawn_interval", powerup_spawn_interval)
	spawner.set("spawn_radius", powerup_spawn_radius)
	spawner.set("min_spawn_radius", powerup_min_spawn_radius)
	spawner.set("max_powerups", powerup_max)
	if spawner.has_method("set_player"):
		spawner.call("set_player", player)
	add_child(spawner)
	_register("powerup_spawner", spawner)


func _register(name: String, node: Node) -> void:
	if _registry and _registry.has_method("register_node"):
		_registry.call("register_node", name, node)
