extends Node

signal scene_loaded(scene_path: String)

var current_scene: Node = null

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)


func change_scene(scene_path: String):
	if not ResourceLoader.exists(scene_path):
		return

	var new_scene_resource: PackedScene = load(scene_path)
	_instantiate_and_change(new_scene_resource)

# NOVA FUNÇÃO: Muda para uma cena que já foi carregada em memória.
func change_scene_from_resource(scene_resource: PackedScene):
	if not scene_resource:
		return
	
	_instantiate_and_change(scene_resource)

func _instantiate_and_change(scene_resource: PackedScene):
	if is_instance_valid(current_scene):
		current_scene.queue_free()

	var new_scene: Node = scene_resource.instantiate()
	get_tree().root.add_child(new_scene)
	current_scene = new_scene
	get_tree().current_scene = new_scene
	scene_loaded.emit(scene_resource.resource_path)
