extends Node

# --- Referências aos Serviços (Singletons) ---
# Removido @export. Agora pegamos os singletons pelo seu caminho absoluto.
# Garanta que os nomes ("SaveService", "SceneService", "AudioService") 
# correspondam EXATAMENTE aos nomes que você configurou em Projeto -> Configurações do Projeto -> Autoload.
@onready var save_service: SaveService = get_node("/root/SaveService")
@onready var scene_service: SceneService = get_node("/root/SceneService")
@onready var audio_service: AudioService = get_node("/root/AudioService")
# Se você tiver um AudioService, faça o mesmo:
# @onready var audio_service: AudioService = get_node("/root/AudioService")

@export var state: GameState

var zone_controller: ZoneController
var _paused := false

func _ready():
	print("🎮 GameManager iniciado.")
	if not state:
		state = GameState.new()

	# Esta verificação agora é mais robusta.
	if not is_instance_valid(scene_service):
		push_error("GameManager: Não foi possível encontrar o Singleton 'SceneService'. Verifique o nome em Autoload.")
		return

	# conectar eventos do sistema (seu código original)
	EventBus.star_count_changed.connect(_on_star_count_changed)
	EventBus.zone_changed.connect(_on_zone_changed)
	EventBus.dialog_started.connect(_on_dialog_started)
	EventBus.dialog_ended.connect(_on_dialog_ended)

	# conectar retorno do scene_service
	scene_service.scene_loaded.connect(_on_scene_loaded)
	
	EventBus.player_entered_zone.connect(_on_player_entered_zone)
	EventBus.zone_conquered.connect(_on_zone_conquered)
	
	# Encontra o ZoneController na cena atual
	call_deferred("_find_zone_controller")

func _find_zone_controller():
	zone_controller = get_tree().root.find_child("ZoneController", true, false)
	# Dispara a lógica de música para a zona inicial
	if zone_controller:
		_on_player_entered_zone(zone_controller.zona_ativa.name if zone_controller.zona_ativa else zone_controller.zona_neutra_nome)


# NOVO HANDLER: Chamado quando o jogador entra em uma nova zona
func _on_player_entered_zone(zone_name: String):
	if not audio_service or not zone_controller: return

	# 1. VERIFICA SE HÁ UMA MÚSICA DE CONQUISTA ATIVA
	var conquest_music = _get_active_conquest_music()
	if conquest_music:
		# Se houver, toca a música de conquista e ignora a da zona atual
		audio_service.play_music(conquest_music)
	else:
		# Se não, toca a música normal da zona em que o jogador entrou
		var zone_music = zone_controller.get_music_for_zone(zone_name)
		audio_service.play_music(zone_music)


# NOVO HANDLER: Chamado quando um evento de jogo conquista uma zona
func _on_zone_conquered(zone_name: String):
	if not state or not audio_service or not zone_controller: return

	print("🏆 Zona '%s' foi conquistada!" % zone_name)
	
	# 1. ATUALIZA O ESTADO DO JOGO
	state.conquered_zones[zone_name] = true
	
	# 2. SALVA O PROGRESSO
	_try_save_game()
	
	# 3. MUDA A MÚSICA IMEDIATAMENTE
	# Pega a música da zona que acabamos de conquistar
	var conquest_music = zone_controller.get_music_for_zone(zone_name)
	if conquest_music:
		audio_service.play_music(conquest_music)

# NOVA FUNÇÃO AUXILIAR: Encontra a música da primeira zona conquistada
func _get_active_conquest_music() -> AudioStream:
	if not state or not zone_controller: return null
	
	# Itera sobre as zonas conquistadas no estado do jogo
	for zone_name in state.conquered_zones:
		if state.conquered_zones[zone_name] == true:
			# Se encontrar uma, retorna a música correspondente do ZoneController
			return zone_controller.get_music_for_zone(zone_name)
			
	# Se nenhuma zona foi conquistada, retorna nulo
	return null

func goto_title_screen():
	goto_scene("res://presentation/scenes/title_screen.tscn")

# --- LÓGICA DE INÍCIO DE JOGO (do prompt anterior, já está correto) ---
func request_start_game():
	if save_service and save_service.load_game(state):
		print("✅ Save encontrado. Carregando estado do jogo.")
		EventBus.emit_game_loaded(state.current_scene)
	else:
		print("ℹ️ Nenhum save encontrado ou save inválido. Iniciando novo jogo.")
		_start_new_game()

	goto_scene("res://presentation/scenes/loading_screen.tscn")

func _start_new_game():
	self.state = GameState.new()
	if save_service:
		save_service.delete_save()
	EventBus.emit_game_reset()


# O resto do seu script GameManager.gd permanece exatamente o mesmo
# ... (goto_scene, _on_star_count_changed, etc.) ...
# --- CONTROLE DE ESTADO ---
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
	print("Dialogo iniciou")

func _on_dialog_ended() -> void:
	print("Dialogo finalizou")

func _on_scene_loaded(scene_path: String) -> void:
	EventBus.emit_scene_changed(scene_path)

# --- PAUSA ---
func set_pause(enable: bool):
	_paused = enable
	get_tree().paused = enable
	EventBus.emit_game_paused(enable)
	print("⏸️ Jogo pausado:", enable)

func toggle_pause():
	set_pause(!_paused)

# --- SAVE/LOAD ---
func _try_save_game() -> bool:
	if not save_service:
		EventBus.emit_save_failed("SaveService ausente.")
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
		EventBus.emit_save_failed("Falha ao carregar jogo.")
		
# --- MUDANÇA DE CENA ---
func goto_scene(path: String):
	if not is_instance_valid(scene_service):
		push_error("GameManager: SceneService não definido.")
		return
	scene_service.change_scene(path)
	# EventBus.emit_scene_changed(path) # Descomente se precisar

# --- RESET ---
func reset_game():
	save_service.delete_save()
	state = GameState.new()
	scene_service.change_scene(state.current_scene)
	EventBus.emit_game_reset()
