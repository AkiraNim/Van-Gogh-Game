# LoadingScreen.gd - Combina animação e carregamento de cena
extends Control

# --- Variáveis da UI ---
@onready var label_static: Label = $BlockBR/VBox/TextRow/LabelStatic
@onready var label_dots:   Label = $BlockBR/VBox/TextRow/LabelDots
@onready var minimum_wait_timer: Timer = $MinimumWaitTimer

# --- Variáveis da Animação de Pontos ---
var _dot_count := 0
var _max_dots := 4
var _animation_timer := 0.0
var _animation_interval := 0.35

# --- Variáveis do Carregamento de Cena ---
@onready var game_manager = get_node("/root/GameManager") # Acessa o Singleton/Autoload

var target_scene_path: String
var _is_minimum_time_finished := false
var _is_scene_loaded := false


func _ready() -> void:
	# 1. Configuração da UI
	label_static.text = "Carregando"
	label_dots.text = ""
	_reserve_dots_width()

	# 2. Configura e inicia o timer de espera mínima
	minimum_wait_timer.wait_time = 3.0
	minimum_wait_timer.timeout.connect(_on_minimum_wait_timer_timeout)
	minimum_wait_timer.start()

	# 3. Pega a cena alvo que o GameManager já definiu no estado do jogo
	target_scene_path = game_manager.state.current_scene
	
	# 4. Inicia o carregamento da cena alvo em segundo plano
	ResourceLoader.load_threaded_request(target_scene_path)
	print("⏳ Iniciando carregamento em segundo plano para: ", target_scene_path)


func _process(delta: float) -> void:
	# Anima os pontos visuais
	_animate_dots(delta)
	
	# Se a cena ainda não foi carregada, verifica o status a cada frame
	if not _is_scene_loaded:
		var status = ResourceLoader.load_threaded_get_status(target_scene_path)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_is_scene_loaded = true
			print("✅ Cena alvo carregada.")
			# Tenta mudar de cena, caso o timer já tenha terminado
			_try_to_change_scene()


# Chamado quando o timer de 3 segundos termina
func _on_minimum_wait_timer_timeout():
	_is_minimum_time_finished = true
	print("⏱️ Tempo mínimo de espera concluído.")
	# Tenta mudar de cena, caso o carregamento da cena já tenha terminado
	_try_to_change_scene()


# A função central que decide se a transição pode ocorrer
func _try_to_change_scene():
	# Só continua se AMBAS as condições forem verdadeiras
	if _is_scene_loaded and _is_minimum_time_finished:
		print("🚀 Condições atendidas! Trocando de cena...")
		# Pega o recurso da cena já carregado da memória
		var scene_resource = ResourceLoader.load_threaded_get(target_scene_path)
		# Chama uma nova função no SceneService para instanciar a cena pré-carregada
		game_manager.scene_service.change_scene_from_resource(scene_resource)


# --- Funções Auxiliares de Animação ---

func _animate_dots(delta: float):
	_animation_timer += delta
	if _animation_timer >= _animation_interval:
		_animation_timer = 0.0
		_dot_count = (_dot_count + 1) % (_max_dots + 1)
		label_dots.text = ".".repeat(_dot_count)

func _reserve_dots_width() -> void:
	var f: Font = label_dots.get_theme_font("font")
	var fs: int = label_dots.get_theme_font_size("font_size")
	if f:
		var size: Vector2 = f.get_string_size(".".repeat(_max_dots), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		label_dots.custom_minimum_size.x = ceil(size.x)
