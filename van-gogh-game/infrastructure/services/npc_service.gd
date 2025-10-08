extends Node
class_name NpcService

@export var item_repository: ItemRepository

func dropar_item(item_data: ItemData, ponto_drop: Marker3D) -> Node3D:
	if item_data == null or ponto_drop == null:
		return null

	var instancia: Node3D = null
	if item_repository != null:
		instancia = item_repository.instantiate_item(item_data.id_item)
	elif item_data.cena_do_item:
		instancia = item_data.cena_do_item.instantiate()

	if instancia == null:
		push_warning("NpcService: falha ao instanciar item '%s'." % item_data.id_item)
		return null

	get_tree().current_scene.add_child(instancia)
	instancia.global_position = ponto_drop.global_position

	var npc_name: String = "NPC"
	if get_parent():
		npc_name = str(get_parent().name)  # evita StringName vs String

	EventBus.npc_dropped_item.emit(npc_name, item_data.id_item)
	return instancia
