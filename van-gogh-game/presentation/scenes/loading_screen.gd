extends Control

@onready var label_static: Label = $BlockBR/VBox/TextRow/LabelStatic
@onready var label_dots:   Label = $BlockBR/VBox/TextRow/LabelDots
@onready var minimum_wait_timer: Timer = $MinimumWaitTimer

var _dot_count := 0
var _max_dots := 4
var _animation_timer := 0.0
var _animation_interval := 0.35

@onready var game_manager = get_node("/root/GameManager") # Acessa o Singleton/Autoload

var target_scene_path: String
var _is_minimum_time_finished := false
var _is_scene_loaded := false


func _ready() -> void:
	label_static.text = "Carregando"
	label_dots.text = ""
	_reserve_dots_width()

	minimum_wait_timer.wait_time = 3.0
	minimum_wait_timer.timeout.connect(_on_minimum_wait_timer_timeout)
	minimum_wait_timer.start()

	target_scene_path = game_manager.state.current_scene
	
	# 4. Inicia o carregamento da cena alvo em segundo plano
	ResourceLoader.load_threaded_request(target_scene_path)


func _process(delta: float) -> void:
	_animate_dots(delta)
	
	if not _is_scene_loaded:
		var status = ResourceLoader.load_threaded_get_status(target_scene_path)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_is_scene_loaded = true
			_try_to_change_scene()


# Chamado quando o timer de 3 segundos termina
func _on_minimum_wait_timer_timeout():
	_is_minimum_time_finished = true
	_try_to_change_scene()


func _try_to_change_scene():
	if _is_scene_loaded and _is_minimum_time_finished:
		var scene_resource = ResourceLoader.load_threaded_get(target_scene_path)
		game_manager.scene_service.change_scene_from_resource(scene_resource)

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
