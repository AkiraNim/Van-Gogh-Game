extends Resource
class_name PlayerInventory

@export var itens: Array[ItemData] = []

func add_item(data: ItemData) -> void:
	if data == null:
		return
	itens.append(data)
	if "inventory_item_added" in EventBus:
		EventBus.inventory_item_added.emit(data.id_item)

func remove_item_by_id(id_item: String) -> ItemData:
	for i in range(itens.size()):
		var it: ItemData = itens[i]
		if it and it.id_item == id_item:
			itens.remove_at(i)
			if "inventory_item_removed" in EventBus:
				EventBus.inventory_item_removed.emit(id_item)
			return it
	return null

func print_contents() -> void:
	print("📦 Inventário do Player (", itens.size(), " itens )")
	for it in itens:
		if it:
			print("- ", it.id_item, " | ", it.nome)
