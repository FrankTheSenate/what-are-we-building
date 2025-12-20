extends Area3D

signal collected(definition: Dictionary, body: Node)

@export var bob_height := 0.35
@export var bob_speed_hz := 0.8
@export var spin_speed_hz := 0.9

var definition: Dictionary = {}

var _base_height := 0.0
var _time := 0.0
var _consumed := false

func _ready() -> void:
	monitoring = true
	monitorable = true
	connect("body_entered", _on_body_entered)
	_base_height = global_transform.origin.y
	_build_visuals()


func _physics_process(delta: float) -> void:
	_time += delta
	var offset := sin(_time * TAU * bob_speed_hz) * bob_height
	var xf := transform
	xf.origin.y = _base_height + offset
	transform = xf
	rotate_y(TAU * spin_speed_hz * delta)


func _build_visuals() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	collision.shape = shape
	add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	mesh_instance.mesh = sphere

	var color: Color = definition.get("color", Color(1, 0.7, 0.25, 1))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.7
	mat.roughness = 0.2
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	var label := Label3D.new()
	label.text = str(definition.get("name", "???"))
	label.billboard = 1
	label.fixed_size = true
	label.font_size = 13
	label.outline_size = 3
	label.no_depth_test = true
	label.modulate = Color(1, 1, 1, 1)
	label.outline_modulate = color.darkened(0.4)
	label.transform.origin = Vector3(0, 0.95, 0)
	add_child(label)


func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if not (body is CharacterBody3D):
		return
	_consumed = true
	monitoring = false
	monitorable = false
	collected.emit(definition, body)
	queue_free()
