extends Node3D

@export var target_path: NodePath
@export var desired_distance: float = 7.5
@export var min_distance: float = 2.0
@export var move_speed: float = 1.75
@export var height_offset: float = 1.5
@export var name_label_path: NodePath = "NameLabel"
@export var possible_names: PackedStringArray = [
	"Harold",
	"Edgar",
	"Alfred",
	"Cedric",
	"Godric",
	"Wilfred",
	"Osric",
	"Edwin",
	"Cuthbert",
	"Aldric"
]
@export var scream_volume_db: float = 8.0
@export var sob_volume_db: float = -1.0

@onready var target: Node3D = get_node_or_null(target_path)
@onready var target_body: Node3D = target.get_node_or_null("CharacterBody3D") if target else null
@onready var scream_player: AudioStreamPlayer3D = $Scream
@onready var sob_player: AudioStreamPlayer3D = $Sob
@onready var name_label: Label3D = get_node_or_null(name_label_path)

var _reacting: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_assign_random_name()

	var speed_val: float = _get_target_speed()
	if speed_val > 0.01:
		move_speed = speed_val * 0.5
	scream_player.volume_db = scream_volume_db
	sob_player.volume_db = sob_volume_db

	var follow_node := target_body if target_body else target
	if follow_node:
		var start_origin: Vector3 = follow_node.global_transform.origin + Vector3(desired_distance, height_offset, 0.0)
		global_transform.origin = start_origin


func _physics_process(delta: float) -> void:
	if target == null and target_body == null:
		return

	var follow_node := target_body if target_body else target
	if follow_node == null:
		return

	var target_pos: Vector3 = follow_node.global_transform.origin + Vector3(0.0, height_offset, 0.0)
	var to_target: Vector3 = target_pos - global_transform.origin
	var dist: float = to_target.length()

	var move_vec: Vector3 = Vector3.ZERO
	if dist > 0.01:
		var dir: Vector3 = to_target.normalized()
		var delta_dist: float = dist - desired_distance
		if abs(delta_dist) > 0.05:
			var signed_dir: Vector3 = dir * signf(delta_dist)
			var step_mag: float = min(abs(delta_dist), move_speed * delta)
			move_vec = signed_dir * step_mag

	global_transform.origin += move_vec

	if not _reacting and dist <= min_distance:
		_reacting = true
		_play_reaction()


func _play_reaction() -> void:
	await _play_scream()
	await _play_sob()
	_reacting = false


func _play_scream() -> void:
	var rate: int = 48000
	var duration: float = 1.0
	var frames: Array[float] = []
	frames.resize(int(duration * rate))
	for i in range(frames.size()):
		var t: float = float(i) / rate
		var tone: float = lerpf(700.0, 1200.0, t / duration)
		var vibrato: float = sin(t * TAU * 8.0) * 40.0
		var envelope: float = clampf(t / 0.08, 0.0, 1.0)
		frames[i] = sin((tone + vibrato) * TAU * t) * 0.9 * envelope
	await _play_frames(scream_player, frames, rate, duration)


func _play_sob() -> void:
	var rate: int = 48000
	var duration: float = 1.4
	var frames: Array[float] = []
	frames.resize(int(duration * rate))
	for i in range(frames.size()):
		var t: float = float(i) / rate
		var tone: float = lerpf(280.0, 140.0, t / duration)
		var wobble: float = sin(t * TAU * 5.5) * 18.0
		var envelope: float = clampf(1.0 - (t / duration) * 0.8, 0.0, 1.0)
		frames[i] = sin((tone + wobble) * TAU * t) * 0.6 * envelope
	await _play_frames(sob_player, frames, rate, duration)


func _play_frames(player: AudioStreamPlayer3D, frames: Array[float], sample_rate: int, duration: float) -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = max(0.2, duration * 1.2)
	player.stop()
	player.stream = null
	player.stream = gen
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var idx: int = 0
	var total: int = frames.size()
	while idx < total:
		var chunk: int = min(256, total - idx)
		while not playback.can_push_buffer(chunk):
			await get_tree().process_frame
		for j in range(chunk):
			var sample: float = frames[idx + j]
			playback.push_frame(Vector2(sample, sample))
		idx += chunk

	await get_tree().create_timer(duration).timeout
	player.stop()


func _assign_random_name() -> void:
	if name_label == null or possible_names.is_empty():
		return
	var idx := _rng.randi_range(0, possible_names.size() - 1)
	name_label.text = possible_names[idx]


func _get_target_speed() -> float:
	if target == null:
		return move_speed
	var speed_prop: Variant = target.get("speed")
	if typeof(speed_prop) == TYPE_FLOAT or typeof(speed_prop) == TYPE_INT:
		return float(speed_prop)
	return move_speed
