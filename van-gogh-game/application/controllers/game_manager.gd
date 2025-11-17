extends Node

@onready var save_service: SaveService = get_node("/root/SaveService")
@onready var scene_service: SceneService = get_node("/root/SceneService")
@onready var audio_service: AudioService = get_node("/root/AudioService")

@export var state: GameState

var zone_controller: ZoneController
var _paused := false

func _ready():
	if not state:
		state = GameState.new()
	if not is_instance_valid(scene_service):
		return

	EventBus.star_count_changed.connect(_on_star_count_changed)
	EventBus.zone_changed.connect(_on_zone_changed)
	EventBus.dialog_started.connect(_on_dialog_started)
	EventBus.dialog_ended.connect(_on_dialog_ended)

	scene_service.scene_loaded.connect(_on_scene_loaded)
	
	EventBus.player_entered_zone.connect(_on_player_entered_zone)
	EventBus.zone_conquered.connect(_on_zone_conquered)
	
	call_deferred("_find_zone_controller")

func _find_zone_controller():
	zone_controller = get_tree().root.find_child("ZoneController", true, false)
	if zone_controller:
		_on_player_entered_zone(zone_controller.active_zone.name if zone_controller.active_zone else zone_controller.neutral_zone_name)


# NOVO HANDLER: Chamado quando o jogador entra em uma nova zona
func _on_player_entered_zone(zone_name: String):
	if not audio_service or not zone_controller: return

	var conquest_music = _get_active_conquest_music()
	if conquest_music:
		audio_service.play_music(conquest_music)
	else:
		var zone_music = zone_controller.get_music_for_zone(zone_name)
		audio_service.play_music(zone_music)

func _on_zone_conquered(zone_name: String):
	if not state or not audio_service or not zone_controller: return
	state.conquered_zones[zone_name] = true
	_try_save_game()
	var conquest_music = zone_controller.get_music_for_zone(zone_name)
	if conquest_music:
		audio_service.play_music(conquest_music)

func _get_active_conquest_music() -> AudioStream:
	if not state or not zone_controller: return null
	for zone_name in state.conquered_zones:
		if state.conquered_zones[zone_name] == true:
			return zone_controller.get_music_for_zone(zone_name)
	return null

func goto_title_screen():
	goto_scene("res://presentation/scenes/title_screen.tscn")
func request_start_game():
	if save_service and save_service.load_game(state):
		EventBus.emit_game_loaded(state.current_scene)
	else:
		_start_new_game()

	goto_scene("res://presentation/scenes/loading_screen.tscn")

func _start_new_game():
	self.state = GameState.new()
	if save_service:
		save_service.delete_save()
	EventBus.emit_game_reset()

func _on_star_count_changed(count: int) -> void:
	state.player_stars = count
	var ok := _try_save_game()
	if ok:
		EventBus.emit_game_saved()

func _on_zone_changed(zone_name: String) -> void:
	state.current_scene = get_tree().current_scene.scene_file_path
	var ok := _try_save_game()
	if ok:
		EventBus.emit_game_saved()

func _on_dialog_started() -> void:
	return

func _on_dialog_ended() -> void:
	return

func _on_scene_loaded(scene_path: String) -> void:
	EventBus.emit_scene_changed(scene_path)

func set_pause(enable: bool):
	_paused = enable
	get_tree().paused = enable
	EventBus.emit_game_paused(enable)

func toggle_pause():
	set_pause(!_paused)

func _try_save_game() -> bool:
	if not save_service:
		EventBus.emit_save_failed("")
		return false
	save_service.save_game(state)
	return true

func save_game():
	if _try_save_game():
		EventBus.emit_game_saved()

func load_game():
	if save_service and save_service.load_game(state):
		scene_service.change_scene(state.current_scene)
		EventBus.emit_game_loaded(state.current_scene)
	else:
		EventBus.emit_save_failed("")
		
func goto_scene(path: String):
	if not is_instance_valid(scene_service):
		return
	scene_service.change_scene(path)

func reset_game():
	save_service.delete_save()
	state = GameState.new()
	scene_service.change_scene(state.current_scene)
	EventBus.emit_game_reset()
