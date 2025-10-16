extends Node

signal scene_loaded(scene_path: String)

var current_scene: Node = null

# --- ADIÇÃO CRÍTICA ---
func _ready():
	# Quando o serviço é carregado, ele precisa saber qual cena já está em execução.
	# Isso garante que a PRIMEIRA transição de cena funcione corretamente.
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)


# Função original, agora usa a função auxiliar
func change_scene(scene_path: String):
	if not ResourceLoader.exists(scene_path):
		push_error("SceneService: cena '%s' não encontrada." % scene_path)
		return

	var new_scene_resource: PackedScene = load(scene_path)
	_instantiate_and_change(new_scene_resource)
	print("🌍 Cena carregada:", scene_path)

# NOVA FUNÇÃO: Muda para uma cena que já foi carregada em memória.
func change_scene_from_resource(scene_resource: PackedScene):
	if not scene_resource:
		push_error("SceneService: Recurso de cena pré-carregado é inválido.")
		return
	
	_instantiate_and_change(scene_resource)
	print("🌍 Cena pré-carregada instanciada:", scene_resource.resource_path)

# FUNÇÃO AUXILIAR para evitar repetição de código
func _instantiate_and_change(scene_resource: PackedScene):
	if is_instance_valid(current_scene):
		current_scene.queue_free()

	var new_scene: Node = scene_resource.instantiate()
	get_tree().root.add_child(new_scene)
	current_scene = new_scene
	get_tree().current_scene = new_scene
	scene_loaded.emit(scene_resource.resource_path)
