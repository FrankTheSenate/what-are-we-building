extends Node3D

@export var target_path: NodePath
@export var phrase_label_path: NodePath = "PhraseLabel"
@export var prompt_label_path: NodePath = "PromptLabel"
@export var interact_distance: float = 8.0
@export var display_time: float = 6.0
@export_range(0.0, 1.0) var sinister_chance: float = 0.2
@export var phrases: PackedStringArray = [
	"Lovely weather for a bounce, isn't it?",
	"Have you tried licking the walls? They're surprisingly clean.",
	"I make the best swamp tea. Trust me.",
	"Did you see the orb? We're besties. Mostly.",
	"Mind the goo pool. It's great for skincare.",
	"If you fall, tuck and roll! Works every time.",
	"Ever raced a slime? They cheat.",
	"I'm on my lunch break. All day.",
	"Do you think the sun bounces too? Asking for a friend.",
	"I'm not lost, I'm just enjoying the detour.",
	"If you hear humming, that's me. Or the vent. Or both.",
	"I collect shiny rocks. You look like you have potential.",
	"Careful, the slime taxes are brutal this season.",
	"The orb owes me five jokes. It's behind schedule."
]
@export var sinister_phrases: PackedStringArray = [
	"My sinister, sinister, evil, dark and twisted plans proceed apace...",
	"Soon my sinister, sinister, evil, dark and twisted plans will unfold!",
	"Hush... the sinister, sinister, evil, dark and twisted plans are blooming." 
]
@export var angry_intro_phrase: String = "Ugh, slimes never know when to shut up. Leave me alone!"
@export var angry_phrases: PackedStringArray = [
	"The economy is a joke, and you're the punchline.",
	"Slimes babble while interest rates climb. Typical.",
	"Inflation's worse than your small talk.",
	"You and the economy both: red and in the gutter.",
	"If Heath Ledger's Joker met a slime, he'd walk away bored.",
	"I understood the Joker until I met you.",
	"Some men just want to watch the world burn. I just want quiet.",
	"Have you seen gas prices? Two pumps, no mercy.",
	"Cost of gas is highway robbery, and you're blocking the road.",
	"Slime chatter is worse than budget meetings.",
	"Every slime thinks they're the protagonist. Newsflash: you're not.",
	"Red markets, red mood, red goblin. Connect the dots."
]
@export var spam_limit: int = 10
@export var spam_window: float = 10.0
@export var angry_duration: float = 30.0
@export var angry_color: Color = Color(1, 0.25, 0.25)
@export var grunt_volume_db: float = -6.0
@export var angry_scale_multiplier: float = 1.25

@onready var target: Node3D = get_node_or_null(target_path)
@onready var target_body: Node3D = _get_target_body()
@onready var phrase_label: Label3D = get_node_or_null(phrase_label_path)
@onready var prompt_label: Label3D = get_node_or_null(prompt_label_path)
@onready var grunt_player: AudioStreamPlayer3D = get_node_or_null("Grunt")

var _rng := RandomNumberGenerator.new()
var _dialog_ticket: int = 0
var _interaction_times: Array[float] = []
var _angry_until: float = -1.0
var _mesh_nodes: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _material_original_colors: Dictionary = {}
var _original_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_rng.randomize()
	if phrase_label:
		phrase_label.visible = false
	if prompt_label:
		prompt_label.visible = false
	if grunt_player:
		grunt_player.volume_db = grunt_volume_db
	_original_scale = scale
	_collect_mesh_nodes()


func _process(_delta: float) -> void:
	_refresh_target_refs()
	_update_prompt()
	_check_anger_timeout()
	if Input.is_action_just_pressed("Interact"):
		_try_interact()


func _try_interact() -> void:
	if target_body == null and target == null:
		return
	var origin_node := target_body if target_body else target
	var from_target := origin_node.global_transform.origin - global_transform.origin
	from_target.y = 0.0
	if from_target.length() > interact_distance:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_register_interaction(now)
	if _is_angry():
		if _just_entered_anger(now):
			_say_phrase(angry_intro_phrase)
		else:
			_say_phrase()
	else:
		_say_phrase()


func _say_phrase(force_phrase: String = "") -> void:
	if phrase_label == null:
		return
	var phrase := force_phrase if force_phrase != "" else _pick_phrase()
	phrase_label.text = phrase
	phrase_label.visible = true
	_dialog_ticket += 1
	_start_hide_timer(_dialog_ticket)
	_play_grunt()


func _pick_phrase() -> String:
	if _is_angry() and angry_phrases.size() > 0:
		return angry_phrases[_rng.randi_range(0, angry_phrases.size() - 1)]
	if _rng.randf() < sinister_chance and sinister_phrases.size() > 0:
		return sinister_phrases[_rng.randi_range(0, sinister_phrases.size() - 1)]
	if phrases.size() > 0:
		return phrases[_rng.randi_range(0, phrases.size() - 1)]
	return "..."


func _start_hide_timer(ticket: int) -> void:
	var timer := get_tree().create_timer(display_time)
	timer.timeout.connect(func(): _on_phrase_timeout(ticket), Object.CONNECT_ONE_SHOT)


func _on_phrase_timeout(ticket: int) -> void:
	if ticket != _dialog_ticket:
		return
	if phrase_label:
		phrase_label.visible = false


func _update_prompt() -> void:
	if prompt_label == null:
		return
	var origin_node := target_body if target_body else target
	if origin_node == null:
		prompt_label.visible = false
		return
	var planar := origin_node.global_transform.origin - global_transform.origin
	planar.y = 0.0
	var in_range := planar.length() <= interact_distance
	prompt_label.visible = in_range and (phrase_label == null or not phrase_label.visible)


func _refresh_target_refs() -> void:
	if target == null and target_path != NodePath(""):
		target = get_node_or_null(target_path)
	if target_body == null:
		target_body = _get_target_body()


func _get_target_body() -> Node3D:
	if target == null:
		return null
	if target is CharacterBody3D:
		return target
	if target.has_node("CharacterBody3D"):
		return target.get_node("CharacterBody3D") as Node3D
	return null


func _register_interaction(now: float) -> void:
	_interaction_times.append(now)
	while _interaction_times.size() > 0 and now - _interaction_times[0] > spam_window:
		_interaction_times.pop_front()
	if not _is_angry() and _interaction_times.size() >= spam_limit:
		_angry_until = now + angry_duration
		_set_angry_color(true)


func _is_angry() -> bool:
	return _angry_until > Time.get_ticks_msec() / 1000.0


func _just_entered_anger(now: float) -> bool:
	# Treat current interaction as first moment of anger if we just set the timer.
	return abs(_angry_until - (now + angry_duration)) < 0.001


func _check_anger_timeout() -> void:
	if _is_angry():
		return
	if _angry_until > 0.0:
		_set_angry_color(false)
		_angry_until = -1.0


func _collect_mesh_nodes() -> void:
	var names := ["Body", "Head", "EyeL", "EyeR", "PupilL", "PupilR"]
	for n in names:
		var mesh := get_node_or_null(n)
		if mesh and mesh is MeshInstance3D:
			_mesh_nodes.append(mesh)
			if mesh.material_override and mesh.material_override is StandardMaterial3D:
				var mat := mesh.material_override as StandardMaterial3D
				_materials.append(mat)
				var key := mat.get_instance_id()
				if not _material_original_colors.has(key):
					_material_original_colors[key] = mat.albedo_color


func _set_angry_color(active: bool) -> void:
	var color: Color = angry_color if active else Color(1, 1, 1, 1)
	for mat in _materials:
		var key := mat.get_instance_id()
		if not active and _material_original_colors.has(key):
			mat.albedo_color = _material_original_colors[key]
		else:
			mat.albedo_color = color
	var target_scale: Vector3 = _original_scale * angry_scale_multiplier if active else _original_scale
	scale = target_scale


func _play_grunt() -> void:
	if grunt_player == null:
		return
	var rate: int = 48000
	var duration: float = 0.35
	var frames: Array[float] = []
	frames.resize(int(duration * rate))
	var base: float = _rng.randf_range(140.0, 220.0)
	for i in range(frames.size()):
		var t: float = float(i) / rate
		var wobble: float = sin(t * TAU * _rng.randf_range(8.0, 12.0)) * 30.0
		var env: float = clampf(1.0 - t / duration, 0.0, 1.0) * clampf(t / 0.05, 0.0, 1.0)
		frames[i] = sin((base + wobble) * TAU * t) * 0.6 * env
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = rate
	gen.buffer_length = max(0.2, duration * 1.2)
	grunt_player.stop()
	grunt_player.stream = gen
	grunt_player.play()
	var playback: AudioStreamGeneratorPlayback = grunt_player.get_stream_playback() as AudioStreamGeneratorPlayback
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
	grunt_player.stop()
