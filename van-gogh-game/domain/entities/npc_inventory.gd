extends Resource
class_name NpcInventory

@export var itens: Array[ItemData] = []

func has_item(id_item: String) -> bool:
	for i in itens:
		if i.id_item == id_item:
			return true
	return false

func remove_item(id_item: String) -> ItemData:
	for i in range(itens.size()):
		if itens[i].id_item == id_item:
			return itens.pop_at(i)
	return null
