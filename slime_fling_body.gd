extends RigidBody3D

@export var initial_impulse := Vector3.ZERO
@export var random_spread := 4.0
var player: Node3D = null
@onready var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	player = get_tree().current_scene.get_node_or_null("Player")
	var base_dir := Vector3.FORWARD
	if player and player is Node3D:
		base_dir = (player.global_transform.origin - global_transform.origin).normalized()
	var impulse_mag: float = initial_impulse.length()
	if impulse_mag == 0.0:
		impulse_mag = random_spread * 4.0
	var bonus_mag := rng.randf_range(0.0, random_spread * 2.0)
	var launch_mag := impulse_mag + bonus_mag
	linear_velocity = base_dir.normalized() * launch_mag
