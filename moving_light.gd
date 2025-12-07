extends DirectionalLight3D

@export_range(0.0, 90.0, 0.1) var orbit_pitch_amplitude_degrees := 35.0
@export var orbit_speed_hz := 0.5
@export var phase_offset := 0.0

var _base_rotation := Vector3.ZERO
var _time := 0.0

func _ready() -> void:
	_base_rotation = rotation

func _process(delta: float) -> void:
	_time += delta
	var angle := (phase_offset + _time) * TAU * orbit_speed_hz
	var yaw_angle := _base_rotation.y + angle
	var pitch_offset := cos(angle) * deg_to_rad(orbit_pitch_amplitude_degrees)
	var rot := _base_rotation
	rot.y = fmod(yaw_angle, TAU)
	rot.x = _base_rotation.x + pitch_offset
	rotation = rot
