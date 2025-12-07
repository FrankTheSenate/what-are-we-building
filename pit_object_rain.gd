extends Node3D

@export var object_count := 1300
@export var batch_size := 40
@export var batch_interval := 1.0
@export var spawn_radius := 40.0
@export var spawn_height := 35.0
@export var base_downward_speed := 8.0
@export var random_speed := 10.0

var rng := RandomNumberGenerator.new()
var _time_accum := 0.0

func _ready() -> void:
	rng.randomize()
	for i in object_count:
		_spawn_body()

func _physics_process(delta: float) -> void:
	_time_accum += delta
	while _time_accum >= batch_interval:
		_time_accum -= batch_interval
		for i in batch_size:
			_spawn_body()

func _spawn_body() -> void:
	var body := RigidBody3D.new()
	body.mass = rng.randf_range(0.8, 2.5)
	body.contact_monitor = true
	body.max_contacts_reported = 6

	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.35
	phys_mat.bounce = 0.45
	body.physics_material_override = phys_mat

	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	var mesh_type := rng.randi_range(0, 2)

	if mesh_type == 0:
		var size := Vector3(
			rng.randf_range(1.0, 3.8),
			rng.randf_range(1.0, 3.2),
			rng.randf_range(1.0, 3.8)
		)
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
	elif mesh_type == 1:
		var radius := rng.randf_range(0.8, 1.8)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh_instance.mesh = mesh
		var shape := SphereShape3D.new()
		shape.radius = radius
		collision.shape = shape
	else:
		var radius := rng.randf_range(0.7, 1.6)
		var height := rng.randf_range(1.2, 3.4)
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
		rng.randf_range(0.05, 0.35),
		rng.randf_range(0.6, 1.0),
		rng.randf_range(0.25, 0.9),
		1.0
	)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * rng.randf_range(0.3, 0.8)
	mesh_instance.material_override = mat

	body.add_child(mesh_instance)
	body.add_child(collision)

	var angle := rng.randf_range(0.0, TAU)
	var radius_offset := rng.randf_range(0.0, spawn_radius)
	var spawn_pos := global_transform.origin + Vector3(
		cos(angle) * radius_offset,
		spawn_height + rng.randf_range(0.0, spawn_height * 0.3),
		sin(angle) * radius_offset
	)
	body.global_transform = Transform3D(Basis.IDENTITY, spawn_pos)

	var downward_speed := base_downward_speed + rng.randf_range(0.0, random_speed)
	var lateral := Vector3(
		rng.randf_range(-random_speed * 0.5, random_speed * 0.5),
		0.0,
		rng.randf_range(-random_speed * 0.5, random_speed * 0.5)
	)
	body.linear_velocity = Vector3(0, -downward_speed, 0) + lateral

	var torque := Vector3(
		rng.randf_range(-8.0, 8.0),
		rng.randf_range(-8.0, 8.0),
		rng.randf_range(-8.0, 8.0)
	)
	body.apply_torque_impulse(torque)

	add_child(body)
