extends Node
class_name ZoneController

@export var zonas: Array[Area3D]
@export var lighting_service: LightingService
@export var player_path: NodePath

# Estados de cada zona
@export var zona_estados := {
	"ZonaVermelha": { "cor": Color(0.227, 0.039, 0.039), "rotacao": Vector3(-29.3, 45.7, 0) },
	"ZonaAzul":     { "cor": Color(0.062, 0.141, 0.294), "rotacao": Vector3(-29.3, 45.7, 0) },
	"ZonaVerde":    { "cor": Color(0.051, 0.260, 0.068), "rotacao": Vector3(-29.3, 45.7, 0) },
	"ZonaAmarela":  { "cor": Color(0.314, 0.301, 0.071), "rotacao": Vector3(-29.3, 45.7, 0) },
	"ZonaNeutra":   { "cor": Color(0.004, 0.008, 0.004), "rotacao": Vector3(-29.3, 45.7, 0) }
}

# Prioridades
@export var zona_prioridades := {
	"ZonaNeutra": 10,
	"ZonaVermelha": 10,
	"ZonaAmarela": 10,
	"ZonaVerde": 10,
	"ZonaAzul": 10
}

# Variáveis internas
var _player: Node3D
var zonas_atuais: Array[Area3D] = []
var zona_ativa: Area3D = null
var zona_neutra_nome: String = "ZonaNeutra"


# ============================================================
# Inicialização
# ============================================================

func _ready() -> void:
	_player = get_node_or_null(player_path)

	for zona in zonas:
		if zona:
			zona.body_entered.connect(_on_body_event)
			zona.body_exited.connect(_on_body_event)

	# Aguarda a física estabilizar antes de detectar a zona inicial
	call_deferred("_detectar_zona_inicial")


# ============================================================
# Entrada e saída de zonas
# ============================================================

func _on_body_event(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_atualizar_zonas_atuais()
	var preferida: Area3D = _zona_preferencial()
	_atualizar_estado_ambiente(preferida)


# ============================================================
# Atualiza lista de zonas realmente sobrepostas
# ============================================================

func _atualizar_zonas_atuais() -> void:
	zonas_atuais.clear()
	if _player == null:
		return

	for zona in zonas:
		if zona and zona.get_overlapping_bodies().has(_player):
			zonas_atuais.append(zona)


# ============================================================
# Determina qual zona é preferencial
# ============================================================

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


# ============================================================
# Atualiza iluminação e emite eventos globais
# ============================================================

func _atualizar_estado_ambiente(zona: Area3D) -> void:
	# Se nada foi detectado, assume ZonaNeutra
	if zona == null:
		if zona_ativa != null and zona_ativa.name == zona_neutra_nome:
			return  # Já está neutra
		_aplicar_zona_neutra()
		return

	# Evita reprocessar a mesma zona
	if zona_ativa == zona:
		return

	zona_ativa = zona

	var nome_zona: String = zona.name
	if zona_estados.has(nome_zona):
		var estado: Dictionary = zona_estados[nome_zona]
		var cor: Color = estado["cor"]
		var rot: Vector3 = estado["rotacao"]
		lighting_service.transicionar(cor, rot)
		EventBus.player_entered_zone.emit(nome_zona)
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


# ============================================================
# Detecta em qual zona o player nasceu
# ============================================================

func _detectar_zona_inicial() -> void:
	if _player == null:
		return

	await get_tree().process_frame  # Espera um frame físico para as áreas estarem ativas

	_atualizar_zonas_atuais()
	var zona_inicial: Area3D = _zona_preferencial()

	if zona_inicial == null:
		_aplicar_zona_neutra()
	else:
		_atualizar_estado_ambiente(zona_inicial)
