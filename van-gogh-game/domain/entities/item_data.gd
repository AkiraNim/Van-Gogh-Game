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
