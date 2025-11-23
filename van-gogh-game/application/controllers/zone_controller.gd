extends Node
class_name ZoneController

@export var zonas: Array[Area3D]
@export var lighting_service: LightingService
@export var player_path: NodePath

@export var zona_estados := {
	"ZonaVermelha": { 
		"cor": Color(0.227, 0.039, 0.039), 
		"rotacao": Vector3(-29.3, 45.7, 0),
		"musica": null
	},
	"ZonaAzul": { 
		"cor": Color(0.062, 0.141, 0.294), 
		"rotacao": Vector3(-29.3, 45.7, 0),
		"musica": null
	},
	"ZonaVerde": { 
		"cor": Color(0.051, 0.260, 0.068), 
		"rotacao": Vector3(-29.3, 45.7, 0),
		"musica": null
	},
	"ZonaAmarela": { 
		"cor": Color(0.537, 0.416, 0.018, 1.0), 
		"rotacao": Vector3(-29.3, 45.7, 0),
		"musica": null
	},
	"ZonaNeutra": { 
		"cor": Color(0.004, 0.008, 0.004), 
		"rotacao": Vector3(-3.3, 43.8, 22.5),
		"musica": null
	}
}

@export var zona_prioridades := {
	"ZonaNeutra": 10,
	"ZonaVermelha": 10,
	"ZonaAmarela": 10,
	"ZonaVerde": 10,
	"ZonaAzul": 10
}

var _player: Node3D
var zonas_atuais: Array[Area3D] = []
var zona_ativa: Area3D = null
var zona_neutra_nome: String = "ZonaNeutra"

func _ready() -> void:
	_player = get_node_or_null(player_path)

	for zona in zonas:
		if zona:
			zona.body_entered.connect(_on_body_event)
			zona.body_exited.connect(_on_body_event)

	call_deferred("_detectar_zona_inicial")

func _on_body_event(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_atualizar_zonas_atuais()
	var preferida: Area3D = _zona_preferencial()
	_atualizar_estado_ambiente(preferida)

func _atualizar_zonas_atuais() -> void:
	zonas_atuais.clear()
	if _player == null:
		return

	for zona in zonas:
		if zona and zona.get_overlapping_bodies().has(_player):
			zonas_atuais.append(zona)

func _zona_preferencial() -> Area3D:
	if zonas_atuais.is_empty():
		return null

	var melhor_zona: Area3D = zonas_atuais[0]
	var melhor_prioridade: int = zona_prioridades.get(melhor_zona.name, 0)
	var menor_distancia: float = melhor_zona.global_transform.origin.distance_to(_player.global_transform.origin)

	for z in zonas_atuais:
		var prioridade: int = zona_prioridades.get(z.name, 0)
		var distancia: float = z.global_transform.origin.distance_to(_player.global_transform.origin)
		if prioridade > melhor_prioridade or (prioridade == melhor_prioridade and distancia < menor_distancia):
			melhor_zona = z
			melhor_prioridade = prioridade
			menor_distancia = distancia

	return melhor_zona

func _atualizar_estado_ambiente(zona: Area3D) -> void:
	var zona_anterior: Area3D = zona_ativa

	if zona == null:
		if zona_anterior != null and zona_anterior.name == zona_neutra_nome:
			return
		_aplicar_zona_neutra()
		if is_instance_valid(zona_anterior):
			EventBus.emit_player_exited_zone(zona_anterior.name)
		return

	if zona_anterior == zona:
		return
	zona_ativa = zona
	if is_instance_valid(zona_anterior):
		EventBus.emit_player_exited_zone(zona_anterior.name)

	var nome_zona: String = zona_ativa.name
	if zona_estados.has(nome_zona):
		var estado: Dictionary = zona_estados[nome_zona]
		var cor: Color = estado["cor"]
		var rot: Vector3 = estado["rotacao"]
		lighting_service.transicionar(cor, rot)
		EventBus.emit_player_entered_zone(nome_zona)
	else:
		_aplicar_zona_neutra()


func _aplicar_zona_neutra() -> void:
	if not zona_estados.has(zona_neutra_nome):
		return
	var estado: Dictionary = zona_estados[zona_neutra_nome]
	var cor: Color = estado["cor"]
	var rot: Vector3 = estado["rotacao"]
	zona_ativa = null
	lighting_service.transicionar(cor, rot)
	EventBus.player_entered_zone.emit(zona_neutra_nome)

func _detectar_zona_inicial() -> void:
	if _player == null:
		return

	await get_tree().process_frame

	_atualizar_zonas_atuais()
	var zona_inicial: Area3D = _zona_preferencial()

	if zona_inicial == null:
		_aplicar_zona_neutra()
	else:
		_atualizar_estado_ambiente(zona_inicial)

func get_music_for_zone(zone_name: String) -> AudioStream:
	if zona_estados.has(zone_name):
		return zona_estados[zone_name].get("musica", null)
	return null
