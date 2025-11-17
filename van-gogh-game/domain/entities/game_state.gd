# Dentro de GameState.gd
extends Resource
class_name GameState

@export var player_stars: int = 0
@export var npc_states: Dictionary = {}
@export var current_scene: String = "res://Scenes/mainScene.tscn"

@export var conquered_zones: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"player_stars": player_stars,
		"npc_states": npc_states,
		"current_scene": current_scene,
		"conquered_zones": conquered_zones
	}

func from_dict(data: Dictionary) -> void:
	player_stars = data.get("player_stars", 0)
	npc_states = data.get("npc_states", {})
	current_scene = data.get("current_scene", current_scene)
	conquered_zones = data.get("conquered_zones", {})
