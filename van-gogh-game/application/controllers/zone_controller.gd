extends Node
class_name ZoneController

@export var zonas: Array[Area3D]
@export var zona_estados: Dictionary
@export var lighting_service: LightingService

var zonas_atuais: Array[Area3D] = []

func _ready():
	for zona in zonas:
		if not zona:
			continue
		zona.body_entered.connect(_on_body_entered.bind(zona))
		zona.body_exited.connect(_on_body_exited.bind(zona))

func _on_body_entered(body: Node, zona: Area3D) -> void:
	if body.is_in_group("player") and not zonas_atuais.has(zona):
		zonas_atuais.push_back(zona)
		_atualizar_estado_ambiente(zona)

func _on_body_exited(body: Node, zona: Area3D) -> void:
	if body.is_in_group("player") and zonas_atuais.has(zona):
		zonas_atuais.erase(zona)
		_atualizar_estado_ambiente(null)

func _atualizar_estado_ambiente(zona: Area3D) -> void:
	var nome_zona := "nenhuma"
	var estado: ZoneState = null

	if zona and zona.name in zona_estados:
		nome_zona = zona.name
		estado = zona_estados[nome_zona]

	if estado:
		lighting_service.transicionar(estado.cor, estado.rotacao)
	else:
		lighting_service.transicionar(Color(0.02, 0.02, 0.02), Vector3.ZERO)

	EventBus.player_entered_zone.emit(nome_zona)
