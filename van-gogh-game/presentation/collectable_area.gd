# presentation/collectable_area.gd
extends Area3D
class_name CollectableArea

@export var id_item: String = ""  # identifica qual item este area representa
var _player: Node = null
var _coletado: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Opcionalmente: definir input handling ativo apenas quando jogador presente
	set_process_input(false)

func _on_body_entered(body: Node) -> void:
	# Assumindo que o “player view” ou personagem do jogador é de um tipo específico
	if body.is_in_group("player") or body is PlayerView:
		_player = body
		# permitir receber input agora
		set_process_input(true)

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		set_process_input(false)

func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if _coletado:
		return
	if event.is_action_pressed("ui_accept"):
		_coletado = true
		# emitir sinal para camada superior
		EventBus.item_collected.emit(id_item, self)
