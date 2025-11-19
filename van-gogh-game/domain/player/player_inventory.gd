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
	for it in itens:
		if it:
			return
			
func get_counts() -> Dictionary:
	var counts := {}
	for it in itens:
		if it == null:
			continue
		var id := it.id_item
		if not counts.has(id):
			counts[id] = {"data": it, "qtd": 0}
		counts[id].qtd += 1
	return counts

func print_grouped(label: String = "") -> void:
	var counts := get_counts()
	var header := ""
	if label != "":
		header += " (" + label + ")"
	for id in counts.keys():
		var rec = counts[id]
		var data: ItemData = rec.data
		var nome = (data.nome if data else id)
