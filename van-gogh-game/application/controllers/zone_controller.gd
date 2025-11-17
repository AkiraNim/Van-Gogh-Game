extends Node
class_name ZoneController

@export var zones: Array[Area3D]
@export var lighting_service: LightingService
@export var player_path: NodePath

# Estados de cada zone
@export var state_zones := {
	"RedZone": { 
		"color": Color(0.227, 0.039, 0.039), 
		"rotation": Vector3(-29.3, 45.7, 0),
		"music": null
	},
	"BlueZone": { 
		"color": Color(0.062, 0.141, 0.294), 
		"rotation": Vector3(-29.3, 45.7, 0),
		"music": null
	},
	"GreenZone": { 
		"color": Color(0.051, 0.260, 0.068), 
		"rotation": Vector3(-29.3, 45.7, 0),
		"music": null
	},
	"YellowZone": { 
		"color": Color(0.537, 0.416, 0.018, 1.0), 
		"rotation": Vector3(-29.3, 45.7, 0),
		"music": null
	},
	"NeutralZone": { 
		"color": Color(0.004, 0.008, 0.004), 
		"rotation": Vector3(-29.3, 45.7, 0),
		"music": null
	}
}

# Prioridades
@export var priority_zones := {
	"NeutralZone": 10,
	"RedZone": 10,
	"YellowZone": 10,
	"GreenZone": 10,
	"BlueZone": 10
}

var _player: Node3D
var actual_zones: Array[Area3D] = []
var active_zone: Area3D = null
var neutral_zone_name: String = "NeutralZone"


func _ready() -> void:
	_player = get_node_or_null(player_path)

	for zone in zones:
		if zone:
			zone.body_entered.connect(_on_body_event)
			zone.body_exited.connect(_on_body_event)

	call_deferred("_detect_initial_zone")

func _on_body_event(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_update_actual_zones()
	var preferred: Area3D = _preferencial_zone()
	update_enviroment_state(preferred)

func _update_actual_zones() -> void:
	actual_zones.clear()
	if _player == null:
		return

	for zone in zones:
		if zone and zone.get_overlapping_bodies().has(_player):
			actual_zones.append(zone)

func _preferencial_zone() -> Area3D:
	if actual_zones.is_empty():
		return null

	var best_zone: Area3D = actual_zones[0]
	var best_priority: int = priority_zones.get(best_zone.name, 0)
	var best_distance: float = best_zone.global_transform.origin.distance_to(_player.global_transform.origin)

	for z in actual_zones:
		var prioridade: int = priority_zones.get(z.name, 0)
		var distancia: float = z.global_transform.origin.distance_to(_player.global_transform.origin)
		if prioridade > best_priority or (prioridade == best_priority and distancia < best_distance):
			best_zone = z
			best_priority = prioridade
			best_distance = distancia

	return best_zone

func update_enviroment_state(zone: Area3D) -> void:
	
	var previus_zone: Area3D = active_zone

	if zone == null:
		if previus_zone != null and previus_zone.name == neutral_zone_name:
			return  # Já está neutra
		_apply_neutral_zone()
		if is_instance_valid(previus_zone):
			EventBus.emit_player_exited_zone(previus_zone.name)
		return

	if previus_zone == zone:
		return

	active_zone = zone
	
	if is_instance_valid(previus_zone):
		EventBus.emit_player_exited_zone(previus_zone.name)
		
	var nome_zone: String = active_zone.name
	if state_zones.has(nome_zone):
		var state: Dictionary = state_zones[nome_zone]
		var color: Color = state["color"]
		var rot: Vector3 = state["rotation"]
		lighting_service.transition(color, rot)
		EventBus.emit_player_entered_zone(nome_zone) # Este sinal já existia e está colorreto
	else:
		_apply_neutral_zone()


func _apply_neutral_zone() -> void:
	if not state_zones.has(neutral_zone_name):
		return
	var state: Dictionary = state_zones[neutral_zone_name]
	var color: Color = state["color"]
	var rot: Vector3 = state["rotation"]
	active_zone = null
	lighting_service.transition(color, rot)
	EventBus.player_entered_zone.emit(neutral_zone_name)

func _detect_initial_zone() -> void:
	if _player == null:
		return

	await get_tree().process_frame  # Espera um frame físico para as áreas estarem ativas

	_update_actual_zones()
	var zone_inicial: Area3D = _preferencial_zone()

	if zone_inicial == null:
		_apply_neutral_zone()
	else:
		update_enviroment_state(zone_inicial)

func get_music_for_zone(zone_name: String) -> AudioStream:
	if state_zones.has(zone_name):
		return state_zones[zone_name].get("music", null)
	return null
