extends Node

var _nodes: Dictionary = {}


func _ready() -> void:
	if get_tree().has_signal("current_scene_changed"):
		get_tree().connect("current_scene_changed", Callable(self, "_on_scene_changed"))

func register_node(name: String, node: Node) -> void:
	if name == "" or node == null:
		return
	var weak: WeakRef = weakref(node)
	_nodes[name] = weak


func unregister_node(name: String) -> void:
	if name == "":
		return
	_nodes.erase(name)


func get_node_ref(name: String) -> Node:
	if name == "":
		return null
	if not _nodes.has(name):
		return null
	var ref: WeakRef = _nodes[name]
	var obj: Object = ref.get_ref()
	if obj == null or not is_instance_valid(obj):
		_nodes.erase(name)
		return null
	return obj


func _on_scene_changed(_node: Node) -> void:
	_nodes.clear()
