extends Resource
class_name PlayerInventory

@export var items: Array[ItemData] = []

func add_item(data: ItemData) -> void:
	if data == null:
		return
	items.append(data)
	if "inventory_item_added" in EventBus:
		EventBus.inventory_item_added.emit(data.id_item)

func remove_item_by_id(id_item: String) -> ItemData:
	for i in range(items.size()):
		var it: ItemData = items[i]
		if it and it.id_item == id_item:
			items.remove_at(i)
			if "inventory_item_removed" in EventBus:
				EventBus.inventory_item_removed.emit(id_item)
			return it
	return null

#func print_contents() -> void:
	#print(" Inventário do Player (", items.size(), " items )")
	#for it in items:
		#if it:
			#print("- ", it.id_item, " | ", it.nome)
	
func get_counts() -> Dictionary:
	var counts := {}
	for it in items:
		if it == null:
			continue
		var id := it.id_item
		if not counts.has(id):
			counts[id] = {"data": it, "qtd": 0}
		counts[id].qtd += 1
	return counts

# Imprime inventário agrupado (nome + quantidade)
#func print_grouped(label: String = "") -> void:
	#var counts := get_counts()
	#var header := " Inventário do Player"
	#if label != "":
		#header += " (" + label + ")"
	#print(header, ": ", str(counts.size()), " tipo(s)")
	#for id in counts.keys():
		#var rec = counts[id]
		#var data: ItemData = rec.data
		#var nome = (data.nome if data else id)
		#print("- ", id, " | ", nome, " x", rec.qtd)
