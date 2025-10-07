extends Node
class_name ItemRepository

@export var itens: Array[ItemData] = []

func get_item_data(id_item: String) -> ItemData:
	for it in itens:
		if it.id_item == id_item:
			return it
	return null

func instantiate_item(id_item: String) -> Node3D:
	var data := get_item_data(id_item)
	if data and data.cena_do_item:
		var node := data.cena_do_item.instantiate()
		if node is Node3D:
			node.name = data.nome
			return node
	return null
