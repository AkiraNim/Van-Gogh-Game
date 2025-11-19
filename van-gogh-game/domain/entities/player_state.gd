extends Resource
class_name PlayerState

@export var estrelas: int = 0
var item_segurado: Node3D = null

func adicionar_estrela() -> void:
	estrelas += 1
	EventBus.star_count_changed.emit(estrelas)
