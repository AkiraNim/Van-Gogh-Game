extends Resource
class_name ItemData

@export var id_item: String = ""
@export var nome: String = ""
@export var descricao: String = ""
@export var tipo: String = "comum"  # Ex: "estrela", "chave", "moeda"
@export var icone: Texture2D
@export var cena_do_item: PackedScene
@export var empilhavel: bool = false
@export var max_stack: int = 1
@export var grants_star: bool = false  # opcional: util p/ lógica de estrela

func instantiate_node() -> Node3D:
	if cena_do_item:
		var n := cena_do_item.instantiate()
		return n as Node3D
	return null
