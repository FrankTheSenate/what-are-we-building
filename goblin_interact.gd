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
	"I'm on my lunch break. All day." 
]
@export var sinister_phrases: PackedStringArray = [
	"My sinister, sinister, evil, dark and twisted plans proceed apace...",
	"Soon my sinister, sinister, evil, dark and twisted plans will unfold!",
	"Hush... the sinister, sinister, evil, dark and twisted plans are blooming." 
]

@onready var target: Node3D = get_node_or_null(target_path)
@onready var target_body: Node3D = _get_target_body()
@onready var phrase_label: Label3D = get_node_or_null(phrase_label_path)
@onready var prompt_label: Label3D = get_node_or_null(prompt_label_path)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if phrase_label:
		phrase_label.visible = false
	if prompt_label:
		prompt_label.visible = false


func _process(_delta: float) -> void:
	_refresh_target_refs()
	_update_prompt()
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
	_say_phrase()


func _say_phrase() -> void:
	if phrase_label == null:
		return
	var phrase := _pick_phrase()
	phrase_label.text = phrase
	phrase_label.visible = true
	_start_hide_timer()


func _pick_phrase() -> String:
	if _rng.randf() < sinister_chance and sinister_phrases.size() > 0:
		return sinister_phrases[_rng.randi_range(0, sinister_phrases.size() - 1)]
	if phrases.size() > 0:
		return phrases[_rng.randi_range(0, phrases.size() - 1)]
	return "..."


func _start_hide_timer() -> void:
	var timer := get_tree().create_timer(display_time)
	timer.timeout.connect(_on_phrase_timeout, Object.CONNECT_ONE_SHOT)


func _on_phrase_timeout() -> void:
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
