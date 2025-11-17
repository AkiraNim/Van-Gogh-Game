extends Resource
class_name PlayerState

@export var stars: int = 0
var item_held: Node3D = null

func add_stars() -> void:
	stars += 1
	EventBus.star_count_changed.emit(stars)
