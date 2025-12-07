extends Node3D

@export var spawn_interval := 0.75
@export var life_time := 3.5
@export var spawn_radius := 15.0
@export var spawn_height := 8.0
@export var base_impulse := Vector3(0, 10, 0)
@export var random_impulse := Vector3(22, 12, 22)
@export var random_torque := Vector3(6, 6, 6)

var time_accum := 0.0
var rng := RandomNumberGenerator.new()
var player: Node3D = null

func _ready() -> void:
	rng.randomize()
	player = get_tree().current_scene.get_node_or_null("Player")

func _physics_process(delta: float) -> void:
	time_accum += delta
	while time_accum >= spawn_interval:
		time_accum -= spawn_interval
		_spawn_body()

func _spawn_body() -> void:
	var body := RigidBody3D.new()
	body.mass = 1.5
	body.contact_monitor = true
	body.max_contacts_reported = 4

	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.2
	phys_mat.bounce = 0.35
	body.physics_material_override = phys_mat

	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	var mesh_type := rng.randi_range(0, 2)

	if mesh_type == 0:
		var size := Vector3(
			rng.randf_range(1.5, 3.0),
			rng.randf_range(1.2, 2.8),
			rng.randf_range(1.5, 3.0)
		)
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
	elif mesh_type == 1:
		var radius := rng.randf_range(0.9, 1.6)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh_instance.mesh = mesh
		var shape := SphereShape3D.new()
		shape.radius = radius
		collision.shape = shape
	else:
		var radius := rng.randf_range(0.8, 1.4)
		var height := rng.randf_range(1.4, 3.0)
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh_instance.mesh = mesh
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(
		rng.randf_range(0.1, 0.4),
		rng.randf_range(0.6, 1.0),
		rng.randf_range(0.2, 0.8),
		1.0
	)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.6
	mesh_instance.material_override = mat

	body.add_child(mesh_instance)
	body.add_child(collision)

	var angle := rng.randf_range(0.0, TAU)
	var radius_offset := rng.randf_range(0.0, spawn_radius)
	var spawn_pos := global_transform.origin + Vector3(
		cos(angle) * radius_offset,
		spawn_height,
		sin(angle) * radius_offset
	)
	body.global_transform = Transform3D(Basis.IDENTITY, spawn_pos)

	var aim_dir := Vector3.UP
	if player and player is Node3D:
		var to_player := player.global_transform.origin - spawn_pos
		if to_player.length() > 0.001:
			aim_dir = to_player.normalized()
	var base_mag: float = base_impulse.length()
	if base_mag <= 0.01:
		base_mag = 12.0
	var bonus_mag: float = rng.randf_range(0.0, random_impulse.length())
	var launch_mag := base_mag + bonus_mag
	body.linear_velocity = aim_dir * launch_mag

	var torque := Vector3(
		rng.randf_range(-random_torque.x, random_torque.x),
		rng.randf_range(-random_torque.y, random_torque.y),
		rng.randf_range(-random_torque.z, random_torque.z)
	)
	body.apply_torque_impulse(torque)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = life_time
	timer.autostart = true
	timer.connect("timeout", Callable(body, "queue_free"))
	body.add_child(timer)

	get_parent().add_child(body)
