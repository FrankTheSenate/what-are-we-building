extends Node3D

@export var speed := 7.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.002
@export var acceleration := 18.0
@export var deceleration := 12.0
@export var tilt_max_radians := deg_to_rad(18.0)
@export var tilt_smoothness := 10.0
@export var pulse_speed := 3.0
@export var pulse_amount := 0.08
@export var vertical_squash_amount := 0.8
@export var vertical_squash_smoothness := 14.0
@export var bounce_frequency := 9.0
@export var bounce_damping := 6.5
@export var impact_scale_factor := 0.04
@export var impact_max_amplitude := 1.0
@export var impact_frequency := 8.0
@export var impact_damping := 5.0
@export var trail_interval := 0.15
@export var trail_lifetime := 5.0
@export var trail_size := Vector2(1.2, 1.2)
@export var trail_color := Color(0.2, 0.9, 0.4, 0.65)
@export var character_color := Color(0.2, 0.9, 0.4, 0.65)
@export var hit_tilt_factor := 0.06
@export var ragdoll_speed_threshold := 13.0
@export var ragdoll_duration := 1.5
@export var ragdoll_min_recover_time := 2.0

@onready var body: CharacterBody3D = $CharacterBody3D
@onready var camera: Camera3D = $CharacterBody3D/Camera3D
@onready var mesh: MeshInstance3D = $CharacterBody3D/MeshInstance3D
@onready var trail_container: Node3D = Node3D.new()
@onready var body_collision: CollisionShape3D = $CharacterBody3D/CollisionShape3D

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var camera_yaw := 0.0
var camera_pitch := 0.0
var camera_offset := Vector3.ZERO
var base_mesh_scale := Vector3.ONE
var pulse_time := 0.0
var landed_velocity := 0.0
var prev_vertical_velocity := 0.0
var bounce_amplitude := 0.0
var bounce_time := 0.0
var impact_amplitude := 0.0
var impact_time := 0.0
var trail_timer := 0.0
var hit_tilt_dir := Vector3.ZERO
var hit_tilt_weight := 0.0
var ragdoll_timer := 0.0
var ragdoll_body: RigidBody3D = null
var ragdoll_mesh: MeshInstance3D = null
var ragdoll_collision: CollisionShape3D = null
var ragdoll_shape: CapsuleShape3D = null
var original_collision_layer := 0
var original_collision_mask := 0
var ragdoll_rng := RandomNumberGenerator.new()
const RAGDOLL_BASE_RADIUS := 0.6
const RAGDOLL_BASE_HEIGHT := 1.6
var ragdoll_min_timer := 0.0
var ragdoll_active := false
var base_body_radius := 0.6
var base_body_height := 1.6

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_offset = camera.transform.origin
	base_mesh_scale = mesh.scale
	if mesh.material_override == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = character_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.7
		mesh.material_override = mat
	get_tree().current_scene.add_child(trail_container)
	ragdoll_rng.randomize()
	original_collision_layer = body.collision_layer
	original_collision_mask = body.collision_mask
	if body_collision and body_collision.shape is CapsuleShape3D:
		var cap := body_collision.shape as CapsuleShape3D
		base_body_radius = cap.radius
		base_body_height = cap.height

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		camera_yaw -= motion.relative.x * mouse_sensitivity
		camera_pitch = clamp(camera_pitch - motion.relative.y * mouse_sensitivity, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	prev_vertical_velocity = body.velocity.y
	var velocity := body.velocity

	var was_on_floor := body.is_on_floor()

	if ragdoll_timer > 0.0:
		ragdoll_timer -= delta
	if ragdoll_active:
		ragdoll_min_timer = max(ragdoll_min_timer - delta, 0.0)
		velocity = Vector3.ZERO
		if ragdoll_body:
			body.global_transform.origin = ragdoll_body.global_transform.origin

	if not ragdoll_active:
		if not body.is_on_floor():
			velocity.y -= gravity * delta
		else:
			if Input.is_action_just_pressed("Jump") and ragdoll_timer <= 0.0:
				velocity.y = jump_velocity
			else:
				velocity.y = 0.0
			if not was_on_floor:
				landed_velocity = 0.0

		var direction := Vector3.ZERO
		var forward := -camera.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()

		if Input.is_action_pressed("Forward"):
			direction += forward
		if Input.is_action_pressed("Back"):
			direction -= forward
		if Input.is_action_pressed("Right"):
			direction += right
		if Input.is_action_pressed("Left"):
			direction -= right

		var target_velocity := Vector3.ZERO
		if ragdoll_timer <= 0.0 and direction != Vector3.ZERO:
			target_velocity = direction.normalized() * speed

		var accel_rate := acceleration if direction != Vector3.ZERO and ragdoll_timer <= 0.0 else deceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, accel_rate * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, accel_rate * delta)

		body.velocity = velocity
		body.move_and_slide()
	else:
		body.velocity = Vector3.ZERO

	for i in range(body.get_slide_collision_count()):
		var collision := body.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var collider_vel := collision.get_collider_velocity()
			var relative_vec := collider_vel - body.velocity
			var relative_speed := relative_vec.length()
			var hit_strength := clampf(relative_speed * impact_scale_factor, 0.0, impact_max_amplitude)
			impact_amplitude = max(impact_amplitude, hit_strength)
			impact_time = 0.0
			var rel_flat := Vector3(relative_vec.x, 0.0, relative_vec.z)
			if rel_flat.length() > 0.001:
				hit_tilt_dir = -rel_flat.normalized()
				hit_tilt_weight = clampf(relative_speed * hit_tilt_factor, 0.0, 2.0)
			elif relative_vec.length() > 0.001:
				hit_tilt_dir = -relative_vec.normalized()
				hit_tilt_weight = clampf(relative_speed * hit_tilt_factor, 0.0, 2.0)
			if relative_speed >= ragdoll_speed_threshold:
				_start_ragdoll(collider_vel)

	var ground_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)
	trail_timer += delta
	if body.is_on_floor() and ground_velocity.length() > 0.2 and trail_timer >= trail_interval:
		_spawn_trail(body.get_floor_normal())
		trail_timer = 0.0

	var yaw_basis := Basis(Vector3.UP, camera_yaw)
	var pitch_basis := Basis(Vector3.RIGHT, camera_pitch)
	var orbit_offset := yaw_basis * pitch_basis * camera_offset
	var cam_transform: Transform3D = camera.transform
	cam_transform.origin = orbit_offset
	camera.transform = cam_transform
	camera.look_at(body.global_transform.origin, Vector3.UP)

	var active_mesh := ragdoll_mesh if ragdoll_mesh != null else mesh

	var current_velocity := (ragdoll_body.linear_velocity if ragdoll_active and ragdoll_body else body.velocity)
	var horizontal_velocity := Vector3(current_velocity.x, 0.0, current_velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var tilt_dir := horizontal_velocity.normalized() if horizontal_speed > 0.001 else Vector3.ZERO
	if hit_tilt_weight > 0.001 and hit_tilt_dir.length() > 0.001:
		tilt_dir += hit_tilt_dir * hit_tilt_weight
		hit_tilt_weight = move_toward(hit_tilt_weight, 0.0, delta * 0.7)

	var tilt_axis := tilt_dir.cross(Vector3.UP)
	var tilt_quat := Quaternion.IDENTITY
	if tilt_axis.length() > 0.001:
		var speed_ratio := clampf(horizontal_speed / speed, 0.0, 1.0)
		var tilt_angle := tilt_max_radians * speed_ratio
		tilt_quat = Quaternion(tilt_axis.normalized(), tilt_angle)

	var current_quat := active_mesh.transform.basis.get_rotation_quaternion()
	var lerp_amount := clampf(delta * tilt_smoothness, 0.0, 1.0)
	var blended_quat := current_quat.slerp(tilt_quat, lerp_amount)
	var mesh_transform := active_mesh.transform
	mesh_transform.basis = Basis(blended_quat)
	active_mesh.transform = mesh_transform

	var moving := horizontal_speed > 0.05
	if moving:
		pulse_time += delta
		var pulse := 1.0 + sin(pulse_time * TAU * pulse_speed) * pulse_amount
		active_mesh.scale = base_mesh_scale * pulse
	else:
		var settle_rate := 0.05 if ragdoll_active else 1.0
		var settle_lerp := clampf(delta * settle_rate, 0.0, 1.0)
		active_mesh.scale = active_mesh.scale.lerp(base_mesh_scale, settle_lerp)

	var vertical_ratio: float = clampf(current_velocity.y / jump_velocity, -4.0, 2.5)
	var squash: float = vertical_ratio * vertical_squash_amount
	var target_scale := Vector3(
		base_mesh_scale.x * (1.0 + squash * 0.6),
		base_mesh_scale.y * (1.0 - squash),
		base_mesh_scale.z * (1.0 + squash * 0.6)
	)
	var squash_rate := vertical_squash_smoothness * (0.05 if ragdoll_active else 1.0)
	var squash_lerp := clampf(delta * squash_rate, 0.0, 1.0)
	active_mesh.scale = active_mesh.scale.lerp(target_scale, squash_lerp)

	if was_on_floor and not body.is_on_floor():
		landed_velocity = 0.0
	elif not was_on_floor and body.is_on_floor():
		landed_velocity = max(-prev_vertical_velocity, 0.0)
		bounce_amplitude = clampf(landed_velocity / (jump_velocity * 0.8), 0.0, 1.0)
		bounce_time = 0.0

	if body.is_on_floor() and landed_velocity > 0.01:
		var impact_strength := clampf(landed_velocity / (jump_velocity * 0.6), 0.0, 1.0)
		var impact_scale := base_mesh_scale * Vector3(
			1.0 + 0.35 * impact_strength,
			1.0 - 0.5 * impact_strength,
			1.0 + 0.35 * impact_strength
		)
		active_mesh.scale = active_mesh.scale.lerp(impact_scale, clampf(delta * vertical_squash_smoothness * 3.0, 0.0, 1.0))
		landed_velocity = move_toward(landed_velocity, 0.0, impact_strength * 4.5 * delta)

	if bounce_amplitude > 0.001:
		bounce_time += delta
		var wave := sin(bounce_time * TAU * bounce_frequency) * bounce_amplitude
		var bounce_scale := Vector3(1.0 + wave * 0.4, 1.0 - wave * 0.6, 1.0 + wave * 0.4)
		active_mesh.scale *= bounce_scale
		bounce_amplitude = move_toward(bounce_amplitude, 0.0, bounce_damping * delta)

	if impact_amplitude > 0.001:
		impact_time += delta
		var impact_wave := sin(impact_time * TAU * impact_frequency) * impact_amplitude
		var impact_scale := Vector3(1.0 + impact_wave * 0.35, 1.0 - impact_wave * 0.5, 1.0 + impact_wave * 0.35)
		active_mesh.scale *= impact_scale
		impact_amplitude = move_toward(impact_amplitude, 0.0, impact_damping * delta)

	if not ragdoll_active and body_collision and body_collision.shape is CapsuleShape3D:
		var cap_shape := body_collision.shape as CapsuleShape3D
		var sx := mesh.scale.x
		var sy := mesh.scale.y
		var sz := mesh.scale.z
		var radius_scale := (sx + sz) * 0.5
		cap_shape.radius = base_body_radius * radius_scale
		cap_shape.height = base_body_height * sy

	if ragdoll_body and ragdoll_shape and ragdoll_mesh:
		var sx := ragdoll_mesh.scale.x
		var sy := ragdoll_mesh.scale.y
		var sz := ragdoll_mesh.scale.z
		var radius_scale := (sx + sz) * 0.5
		ragdoll_shape.radius = RAGDOLL_BASE_RADIUS * radius_scale
		ragdoll_shape.height = RAGDOLL_BASE_HEIGHT * sy
		if ragdoll_collision:
			var col_transform := ragdoll_collision.transform
			col_transform.basis = ragdoll_mesh.transform.basis
			ragdoll_collision.transform = col_transform

	var can_recover := ragdoll_active and ragdoll_min_timer <= 0.0 and Input.is_action_just_pressed("Jump")
	if can_recover and ragdoll_body:
		body.global_transform.origin = ragdoll_body.global_transform.origin
		ragdoll_body.queue_free()
		ragdoll_body = null
		ragdoll_mesh = null
		ragdoll_collision = null
		ragdoll_shape = null
		mesh.visible = true
		body.collision_layer = original_collision_layer
		body.collision_mask = original_collision_mask
		body.velocity = Vector3.ZERO
		ragdoll_active = false

func _spawn_trail(floor_normal: Vector3) -> void:
	var trail_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = trail_size
	trail_mesh.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = trail_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	trail_mesh.material_override = mat

	var basis := Basis()
	var up := floor_normal.normalized()
	var tangent := up.cross(Vector3.FORWARD)
	if tangent.length() < 0.001:
		tangent = up.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(up).normalized()
	basis.x = tangent
	basis.y = up
	basis.z = bitangent

	var trail_transform := Transform3D()
	trail_transform.basis = basis
	var drop_height := 0.03
	trail_transform.origin = body.global_transform.origin - up * drop_height
	trail_mesh.transform = trail_transform

	trail_container.add_child(trail_mesh)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = trail_lifetime
	timer.autostart = true
	timer.connect("timeout", Callable(trail_mesh, "queue_free"))
	trail_mesh.add_child(timer)

func _start_ragdoll(hit_velocity: Vector3) -> void:
	if ragdoll_body:
		return
	ragdoll_timer = ragdoll_duration
	ragdoll_min_timer = ragdoll_min_recover_time
	ragdoll_active = true
	mesh.visible = false
	body.collision_layer = 0
	body.collision_mask = 0

	ragdoll_body = RigidBody3D.new()
	ragdoll_body.mass = 2.0
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.6
	phys_mat.bounce = 0.2
	ragdoll_body.physics_material_override = phys_mat

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = RAGDOLL_BASE_RADIUS
	shape.height = RAGDOLL_BASE_HEIGHT
	collision.shape = shape
	ragdoll_body.add_child(collision)
	ragdoll_shape = shape
	ragdoll_collision = collision

	var rag_mesh := MeshInstance3D.new()
	rag_mesh.mesh = mesh.mesh
	if mesh.material_override:
		rag_mesh.material_override = mesh.material_override
	elif mesh.mesh and mesh.mesh.get_surface_count() > 0:
		var surf_mat := mesh.mesh.surface_get_material(0)
		if surf_mat:
			rag_mesh.material_override = surf_mat
	var impact_speed := hit_velocity.length()
	var dir := hit_velocity.normalized()
	var intensity: float = impact_speed / max(0.001, jump_velocity)
	var vertical_down: float = max(0.0, -dir.y)
	var vertical_up: float = max(0.0, dir.y)
	var horizontal: float = max(0.0, 1.0 - abs(dir.y))
	var y_scale := base_mesh_scale.y * (1.0 + vertical_up * 0.8 * intensity - vertical_down * 0.8 * intensity)
	var xz_scale := base_mesh_scale.x * (1.0 + horizontal * 0.5 * intensity + vertical_down * 0.6 * intensity - vertical_up * 0.3 * intensity)
	var safe_scale: float = 0.05
	rag_mesh.scale = Vector3(
		max(xz_scale, safe_scale),
		max(y_scale, safe_scale),
		max(xz_scale, safe_scale)
	)
	rag_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ragdoll_body.add_child(rag_mesh)
	ragdoll_mesh = rag_mesh

	get_tree().current_scene.add_child(ragdoll_body)
	ragdoll_body.global_transform = body.global_transform
	ragdoll_body.linear_velocity = hit_velocity
	ragdoll_body.angular_velocity = Vector3(
		hit_velocity.z * 0.4,
		hit_velocity.x * 0.4,
		ragdoll_rng.randf_range(-2.5, 2.5)
	)
