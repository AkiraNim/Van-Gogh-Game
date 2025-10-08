extends Node

@export var item_repository: ItemRepository

# Instancia e posiciona o item no mundo, sem depender de NpcEntity
func dropar_item(item_data: ItemData, ponto_drop: Marker3D) -> Node3D:
	if item_data == null or ponto_drop == null:
		return null

	var instancia: Node3D = null
	if item_repository:
		instancia = item_repository.instantiate_item(item_data.id_item)
	elif item_data.cena_do_item:
		instancia = item_data.cena_do_item.instantiate()

	if instancia == null:
		push_warning("NpcService: falha ao instanciar item '%s'." % item_data.id_item)
		return null

	var root := get_tree().current_scene
	if root:
		root.add_child(instancia)
		instancia.global_position = ponto_drop.global_position

	EventBus.npc_dropped_item.emit(item_data.id_item)
	return instancia
