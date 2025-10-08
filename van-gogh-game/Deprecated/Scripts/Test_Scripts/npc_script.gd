extends Node3D

@export var inventario: Array[ItemData]
@export var ponto_de_drop: Marker3D

func dropar_item(id_do_item: String):
	if not ponto_de_drop:
		print("ERRO: NPC '", self.name, "' não tem um PontoDeDrop configurado.")
		return

	var item_para_dropar: ItemData = null
	var item_index = -1

	for i in range(inventario.size()):
		if inventario[i].id_item == id_do_item:
			item_para_dropar = inventario[i]
			item_index = i
			break
	
	if not item_para_dropar:
		print("AVISO: NPC '", self.name, "' tentou dropar o item '", id_do_item, "' mas não o possui.")
		return
		
	var instancia_item = item_para_dropar.cena_do_item.instantiate()
	
	# CORREÇÃO: Adiciona à cena ANTES de posicionar.
	get_tree().current_scene.add_child(instancia_item)
	instancia_item.global_position = ponto_de_drop.global_position
	
	inventario.remove_at(item_index)
	
	print("NPC '", self.name, "' dropou o item '", id_do_item, "'.")
