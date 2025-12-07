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
@export var vertical_squash_amount := 0.6
@export var vertical_squash_smoothness := 14.0
@export var bounce_frequency := 9.0
@export var bounce_damping := 6.5

@onready var body: CharacterBody3D = $CharacterBody3D
@onready var camera: Camera3D = $CharacterBody3D/Camera3D
@onready var mesh: MeshInstance3D = $CharacterBody3D/MeshInstance3D

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

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_offset = camera.transform.origin
	base_mesh_scale = mesh.scale

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		camera_yaw -= motion.relative.x * mouse_sensitivity
		camera_pitch = clamp(camera_pitch - motion.relative.y * mouse_sensitivity, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	prev_vertical_velocity = body.velocity.y
	var velocity := body.velocity

	var was_on_floor := body.is_on_floor()

	if not body.is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("Jump"):
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
	if direction != Vector3.ZERO:
		target_velocity = direction.normalized() * speed

	var accel_rate := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, accel_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel_rate * delta)

	body.velocity = velocity
	body.move_and_slide()

	var yaw_basis := Basis(Vector3.UP, camera_yaw)
	var pitch_basis := Basis(Vector3.RIGHT, camera_pitch)
	var orbit_offset := yaw_basis * pitch_basis * camera_offset
	var cam_transform: Transform3D = camera.transform
	cam_transform.origin = orbit_offset
	camera.transform = cam_transform
	camera.look_at(body.global_transform.origin, Vector3.UP)

	var current_velocity := body.velocity
	var horizontal_velocity := Vector3(current_velocity.x, 0.0, current_velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var tilt_dir := horizontal_velocity.normalized() if horizontal_speed > 0.001 else Vector3.ZERO

	var tilt_axis := tilt_dir.cross(Vector3.UP)
	var tilt_quat := Quaternion.IDENTITY
	if tilt_axis.length() > 0.001:
		var speed_ratio := clampf(horizontal_speed / speed, 0.0, 1.0)
		var tilt_angle := tilt_max_radians * speed_ratio
		tilt_quat = Quaternion(tilt_axis.normalized(), tilt_angle)

	var current_quat := mesh.transform.basis.get_rotation_quaternion()
	var lerp_amount := clampf(delta * tilt_smoothness, 0.0, 1.0)
	var blended_quat := current_quat.slerp(tilt_quat, lerp_amount)
	var mesh_transform := mesh.transform
	mesh_transform.basis = Basis(blended_quat)
	mesh.transform = mesh_transform

	var moving := horizontal_speed > 0.05
	if moving:
		pulse_time += delta
		var pulse := 1.0 + sin(pulse_time * TAU * pulse_speed) * pulse_amount
		mesh.scale = base_mesh_scale * pulse
	else:
		pulse_time = 0.0
		mesh.scale = base_mesh_scale

	var vertical_ratio: float = clampf(body.velocity.y / jump_velocity, -2.5, 2.5)
	var squash: float = vertical_ratio * vertical_squash_amount
	var target_scale := Vector3(
		base_mesh_scale.x * (1.0 + squash * 0.6),
		base_mesh_scale.y * (1.0 - squash),
		base_mesh_scale.z * (1.0 + squash * 0.6)
	)
	var squash_lerp := clampf(delta * vertical_squash_smoothness, 0.0, 1.0)
	mesh.scale = mesh.scale.lerp(target_scale, squash_lerp)

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
		mesh.scale = mesh.scale.lerp(impact_scale, clampf(delta * vertical_squash_smoothness * 3.0, 0.0, 1.0))
		landed_velocity = move_toward(landed_velocity, 0.0, impact_strength * 4.5 * delta)

	if bounce_amplitude > 0.001:
		bounce_time += delta
		var wave := sin(bounce_time * TAU * bounce_frequency) * bounce_amplitude
		var bounce_scale := Vector3(1.0 + wave * 0.4, 1.0 - wave * 0.6, 1.0 + wave * 0.4)
		mesh.scale *= bounce_scale
		bounce_amplitude = move_toward(bounce_amplitude, 0.0, bounce_damping * delta)
