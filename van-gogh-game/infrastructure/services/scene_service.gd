extends Node
class_name SceneService

signal scene_loaded(scene_path: String)

var current_scene: Node = null

func change_scene(scene_path: String):
	if not ResourceLoader.exists(scene_path):
		push_error("SceneService: cena '%s' não encontrada." % scene_path)
		return

	if current_scene:
		current_scene.queue_free()

	var new_scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene = new_scene
	scene_loaded.emit(scene_path)
	print("🌍 Cena carregada:", scene_path)
