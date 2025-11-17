extends Node

@export var item_repository: ItemRepository

func drop_item(npc_name: String, item_data: ItemData, drop_point: Marker3D) -> Node3D:
	if item_data == null or drop_point == null:
		return null
	var item_instance := item_data.cena_do_item.instantiate()
	
	var instance: Node3D = null
	if item_repository:
		instance = item_repository.instantiate_item(item_data.id_item)
	elif item_data.cena_do_item:
		instance = item_data.cena_do_item.instantiate()

	if instance == null:
		return null

	var root := get_tree().current_scene
	if root:
		root.add_child(instance)
		instance.global_position = drop_point.global_position

	EventBus.npc_dropped_item.emit(npc_name, item_data.id_item)
	return instance
	
	
