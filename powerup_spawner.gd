extends Node3D

@export var player_path: NodePath
@export var spawn_interval := 7.5
@export var max_powerups := 4
@export var spawn_radius := 18.0
@export var min_spawn_radius := 4.0
@export var spawn_height := 0.75

const PickupScene := preload("res://powerup_pickup.gd")

var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _definitions: Array[Dictionary] = []
var _active_pickups: Array[Node] = []
var _active_effects: Dictionary = {}
var _effect_id := 1

@onready var _player: Node = get_node_or_null(player_path)

func set_player(player: Node) -> void:
	_player = player

func _ready() -> void:
	if _player == null:
		var reg := get_node_or_null("/root/Registry")
		if reg and reg.has_method("get_node_ref"):
			var reg_player: Node = reg.get_node_ref("player")
			if reg_player:
				_player = reg_player
	_rng.randomize()
	_definitions = _build_definitions()


func _physics_process(delta: float) -> void:
	_cleanup_pickups()
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_powerup()


func _cleanup_pickups() -> void:
	_active_pickups = _active_pickups.filter(func(p):
		return p != null and is_instance_valid(p)
	)


func _spawn_powerup() -> void:
	if _definitions.is_empty():
		return
	if _active_pickups.size() >= max_powerups:
		return
	var definition := _definitions[_rng.randi_range(0, _definitions.size() - 1)]
	var pickup: Area3D = PickupScene.new()
	pickup.definition = definition
	pickup.global_transform.origin = _pick_spawn_position()
	pickup.collected.connect(func(def: Dictionary, body: Node):
		_on_pickup_collected(def, body, pickup)
	, Object.CONNECT_ONE_SHOT)
	add_child(pickup)
	_active_pickups.append(pickup)


func _pick_spawn_position() -> Vector3:
	var center := global_transform.origin
	if _player and is_instance_valid(_player):
		var player_origin: Vector3 = _player.global_transform.origin
		center.x = player_origin.x
		center.z = player_origin.z
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(min_spawn_radius, spawn_radius)
	return center + Vector3(
		cos(angle) * radius,
		spawn_height,
		sin(angle) * radius
	)


func _on_pickup_collected(definition: Dictionary, body: Node, pickup: Node) -> void:
	_active_pickups.erase(pickup)
	_apply_powerup(definition, body)


func _apply_powerup(definition: Dictionary, body: Node) -> void:
	var player := _resolve_player(body)
	if player == null:
		return
	var apply_callable: Callable = definition.get("apply", Callable())
	var cleanup: Callable = Callable()
	if apply_callable.is_valid():
		var result: Variant = apply_callable.call(player)
		if result is Callable:
			cleanup = result
	var duration: float = float(definition.get("duration", 8.0))
	var id: int = _effect_id
	_effect_id += 1
	if duration > 0.0:
		var timer := get_tree().create_timer(duration)
		_active_effects[id] = {"cleanup": cleanup}
		timer.timeout.connect(func():
			_expire_effect(id)
		, Object.CONNECT_ONE_SHOT)
	else:
		_run_cleanup(cleanup)
	print("Powerup picked: %s - %s" % [definition.get("name", "???"), definition.get("summary", "")])


func _expire_effect(id: int) -> void:
	if not _active_effects.has(id):
		return
	var cleanup: Callable = _active_effects[id].get("cleanup", Callable()) as Callable
	_run_cleanup(cleanup)
	_active_effects.erase(id)


func _run_cleanup(cleanup: Callable) -> void:
	if cleanup.is_valid():
		cleanup.call()


func _resolve_player(body: Node) -> Node:
	if body == null:
		return null
	if body.get_parent():
		return body.get_parent()
	return body


func _get_stat(player: Node, stat: String, fallback: Variant) -> Variant:
	if player and player.has_method("get_base_stat"):
		return player.get_base_stat(stat)
	return fallback


func _build_definitions() -> Array[Dictionary]:
	return [
	{
		"name": "Goose Juice Turbo",
		"summary": "Legs go zoom, brain lags behind.",
		"duration": 10.0,
		"color": Color(1, 0.63, 0.2, 1),
		"apply": func(player):
			var base_speed: float = float(_get_stat(player, "speed", player.speed))
			var base_accel: float = float(_get_stat(player, "acceleration", player.acceleration))
			player.speed = base_speed * 1.85
			player.acceleration = base_accel * 1.35
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.speed = base_speed
				player.acceleration = base_accel
			return cleanup
	},
	{
		"name": "Moonshroom Springs",
		"summary": "Lunar legs double-jump off pure nonsense.",
		"duration": 10.0,
		"color": Color(0.73, 0.55, 1, 1),
		"apply": func(player):
			var base_jump: float = float(_get_stat(player, "jump_velocity", player.jump_velocity))
			var base_gravity: float = float(_get_stat(player, "gravity", player.gravity))
			player.jump_velocity = base_jump * 2.1
			player.gravity = base_gravity * 0.55
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.jump_velocity = base_jump
				player.gravity = base_gravity
			return cleanup
	},
	{
		"name": "Mirror Mango Mayhem",
		"summary": "Brain says left, feet hear right.",
		"duration": 8.0,
		"color": Color(0.98, 0.87, 0.21, 1),
		"apply": func(player):
			var prev: bool = bool(player.invert_controls)
			player.invert_controls = true
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.invert_controls = prev
			return cleanup
	},
	{
		"name": "Bubblegum Halo",
		"summary": "Bouncier than a caffeinated trampoline.",
		"duration": 9.0,
		"color": Color(1, 0.52, 0.78, 1),
		"apply": func(player):
			var base_freq: float = float(_get_stat(player, "bounce_frequency", player.bounce_frequency))
			var base_damp: float = float(_get_stat(player, "bounce_damping", player.bounce_damping))
			player.bounce_frequency = base_freq + 4.0
			player.bounce_damping = max(1.0, base_damp * 0.45)
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.bounce_frequency = base_freq
				player.bounce_damping = base_damp
			return cleanup
	},
	{
		"name": "Slippery Soap Comets",
		"summary": "Stopping is optional; sliding is mandatory.",
		"duration": 12.0,
		"color": Color(0.62, 0.86, 1, 1),
		"apply": func(player):
			var base_decel: float = float(_get_stat(player, "deceleration", player.deceleration))
			player.deceleration = max(0.5, base_decel * 0.35)
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.deceleration = base_decel
			return cleanup
	},
	{
		"name": "Cotton Candy Jetstream",
		"summary": "Leaves a sugary exhaust wherever you wobble.",
		"duration": 9.0,
		"color": Color(1, 0.62, 0.9, 1),
		"apply": func(player):
			var base_interval: float = float(_get_stat(player, "trail_interval", player.trail_interval))
			var base_size: Vector2 = Vector2(_get_stat(player, "trail_size", player.trail_size))
			var base_color: Color = Color(_get_stat(player, "trail_color", player.trail_color))
			player.trail_interval = 0.05
			player.trail_size = base_size * 1.4
			player.trail_color = Color(1, 0.63, 0.92, 0.75)
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.trail_interval = base_interval
				player.trail_size = base_size
				player.trail_color = base_color
			return cleanup
	},
	{
		"name": "Pancake Planet Passport",
		"summary": "Impacts flatten the universe around you.",
		"duration": 10.0,
		"color": Color(0.96, 0.72, 0.5, 1),
		"apply": func(player):
			var base_impact_scale: float = float(_get_stat(player, "impact_scale_factor", player.impact_scale_factor))
			var base_impact_max: float = float(_get_stat(player, "impact_max_amplitude", player.impact_max_amplitude))
			var base_squash: float = float(_get_stat(player, "vertical_squash_amount", player.vertical_squash_amount))
			player.impact_scale_factor = base_impact_scale * 2.2
			player.impact_max_amplitude = base_impact_max * 1.5
			player.vertical_squash_amount = base_squash * 1.3
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.impact_scale_factor = base_impact_scale
				player.impact_max_amplitude = base_impact_max
				player.vertical_squash_amount = base_squash
			return cleanup
	},
	{
		"name": "Gremlin Spin-Doctor",
		"summary": "Hands off the mouse, the gremlin is steering.",
		"duration": 8.0,
		"color": Color(0.4, 1, 0.76, 1),
		"apply": func(player):
			var prev: float = float(player.auto_spin_rate)
			player.auto_spin_rate = 2.6
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.auto_spin_rate = prev
			return cleanup
	},
	{
		"name": "Featherweight Fiesta",
		"summary": "Ragdolls at the slightest insult, floats like lint.",
		"duration": 11.0,
		"color": Color(0.72, 0.9, 0.98, 1),
		"apply": func(player):
			var base_threshold: float = float(_get_stat(player, "ragdoll_speed_threshold", player.ragdoll_speed_threshold))
			var base_duration: float = float(_get_stat(player, "ragdoll_duration", player.ragdoll_duration))
			player.ragdoll_speed_threshold = max(2.0, base_threshold * 0.45)
			player.ragdoll_duration = base_duration * 1.35
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.ragdoll_speed_threshold = base_threshold
				player.ragdoll_duration = base_duration
			return cleanup
	},
	{
		"name": "Espresso Express Eyebeams",
		"summary": "Aim like a laser pointer on three espressos.",
		"duration": 9.0,
		"color": Color(0.83, 0.45, 0.2, 1),
		"apply": func(player):
			var base_mouse: float = float(_get_stat(player, "mouse_sensitivity", player.mouse_sensitivity))
			player.mouse_sensitivity = base_mouse * 2.25
			var cleanup := func():
				if not is_instance_valid(player):
					return
				player.mouse_sensitivity = base_mouse
			return cleanup
	}
	]
