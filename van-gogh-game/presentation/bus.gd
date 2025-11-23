extends CharacterBody3D

@export var speed: float = 3.0
var can_move: bool = false
var move_blocked: bool = false
@onready var path_follow: PathFollow3D = get_parent()

func _physics_process(delta: float) -> void:
	if can_move and move_blocked == false:
		path_follow.progress += speed * delta
