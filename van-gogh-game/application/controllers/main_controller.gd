extends Node
class_name MainController

@export var dialog_service: DialogController
@export var player: PlayerView
@export var zone_controller: ZoneController

var _fade_tween: Tween
var active_dialog: bool = false

func _ready() -> void:

	if not player:
		for node in get_tree().get_nodes_in_group("player"):
			if node is PlayerView:
				player = node
				break
	if not player:
		player = get_tree().get_current_scene().get_node_or_null("Player_3D")

	if not EventBus.dialog_started.is_connected(_on_dialog_started):
		EventBus.dialog_started.connect(_on_dialog_started)
	if not EventBus.dialog_ended.is_connected(_on_dialog_ended):
		EventBus.dialog_ended.connect(_on_dialog_ended)

	EventBus.player_entered_zone.connect(_on_player_entered_zone)
	EventBus.star_count_changed.connect(_on_star_count_changed)


func _on_dialog_started() -> void:
	active_dialog = true
	if player:
		player.pode_mover = false
		player.velocity = Vector3.ZERO

func _on_dialog_ended() -> void:
	active_dialog = false
	if player:
		player.pode_mover = true
	EventBus.interaction_ended.emit()


func _on_player_entered_zone(zone_name: String) -> void:
	if zone_name == "BlueZone":
		resume_control_tree(%SnowView2D)
		_fade(%SnowView2D, true, 0.4)
	else:
		_fade(%SnowView2D, false, 0.4)
		_fade_tween.finished.connect(func ():
			if is_instance_valid(%SnowView2D) and %SnowView2D.modulate.a <= 0.001:
				pause_control_tree(%SnowView2D)
		, CONNECT_ONE_SHOT)



func _fade(node: CanvasItem, to_visible: bool, duration: float = 0.4) -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	if to_visible:
		node.visible = true

	var target_a := 1.0 if to_visible else 0.0

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(node, "modulate:a", target_a, duration)
	if not to_visible:
		_fade_tween.finished.connect(func():
			if is_instance_valid(node) and node.modulate.a <= 0.001:
				node.visible = false
		)

func _set_paused_recursive(n: Node, paused: bool) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

	if n is Control:
		var c := n as Control
		if paused:
			if not c.has_meta("_prev_mouse_filter"):
				c.set_meta("_prev_mouse_filter", c.mouse_filter)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			if c.has_meta("_prev_mouse_filter"):
				c.mouse_filter = int(c.get_meta("_prev_mouse_filter"))
				c.remove_meta("_prev_mouse_filter")

	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		ap.speed_scale = 0.0 if paused else 1.0

	if n is Timer:
		var t := n as Timer
		if paused: t.stop()

	if n is GPUParticles2D or n is CPUParticles2D:
		n.emitting = not paused

	for child in n.get_children():
		_set_paused_recursive(child, paused)

func pause_control_tree(root: Control) -> void:
	_set_paused_recursive(root, true)

func resume_control_tree(root: Control) -> void:
	_set_paused_recursive(root, false)


func _on_star_count_changed(nova_contagem: int) -> void:
	return
