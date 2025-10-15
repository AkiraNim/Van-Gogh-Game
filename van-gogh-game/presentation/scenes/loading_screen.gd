# LoadingScreen.gd (Godot 4.x)
extends Control

@onready var label_static: Label = $BlockBR/VBox/TextRow/LabelStatic
@onready var label_dots:   Label = $BlockBR/VBox/TextRow/LabelDots

var _dot_count := 0
var _max_dots := 4
var _timer := 0.0
var _interval := 0.35

func _ready() -> void:
	label_static.text = "Carregando"  # sempre fixo
	label_dots.text = ""              # só os pontos animados
	_reserve_dots_width()             # evita “pular” layout quando os pontos crescem

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _interval:
		_timer = 0.0
		_dot_count = (_dot_count + 1) % (_max_dots + 1)
		# Atualiza SOMENTE o label de pontos
		label_dots.text = ".".repeat(_dot_count)

# Mantém largura fixa suficiente para 4 pontos, evitando “tremida” na UI
func _reserve_dots_width() -> void:
	var f: Font = label_dots.get_theme_font("font")
	var fs: int = label_dots.get_theme_font_size("font_size")
	if f:
		var size: Vector2 = f.get_string_size(".".repeat(_max_dots), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		label_dots.custom_minimum_size.x = ceil(size.x)
