# Anexe este script ao nó "Grass" (Node3D)
extends Node3D

@export var amplitude_deg: float = 12.0
@export var speed: float = 1.2
@export var offset_between_sprites_deg: float = 10
@export var random_initial_phase: bool = true

@export var boosted_amplitude_deg := 20.0
@export var boost_speed := 10.0

# Decaimento do boost (vale mesmo com o player parado dentro da área)
@export var boost_decay_duration: float = 2.0  # tempo ~até cair de 1.0 para ~0.37 (decay exponencial)

var _left: Node3D
var _right: Node3D

var _base_left_z: float
var _base_right_z: float
var _t: float = 0.0
var _phase0: float = 0.0

# valores padrão originais
var _base_amp: float
var _base_speed: float

# alvos “suavizados”
var _target_amp: float
var _target_speed: float

# nível de boost (0..1) que decai sempre
var _boost_level: float = 0.0

func _ready() -> void:
	_base_amp = amplitude_deg
	_base_speed = speed
	_target_amp = _base_amp
	_target_speed = _base_speed

	if has_node("TouchArea"):
		var area := $TouchArea as Area3D
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	_left = $LeftSwaySprite
	_right = $RightSwaySprite
	_base_left_z = _left.rotation.z
	_base_right_z = _right.rotation.z

	if random_initial_phase:
		_phase0 = randf() * TAU

func _on_body_entered(_b: Node) -> void:
	# Recarrega o boost e aplica amplitude de boost
	_boost_level = 1.0
	_target_amp = boosted_amplitude_deg

func _on_body_exited(_b: Node) -> void:
	# Amplitude volta ao padrão; a speed continua decaindo naturalmente
	_target_amp = _base_amp

func _process(delta: float) -> void:
	# ---- Decaimento contínuo do boost (exponencial) ----
	if boost_decay_duration > 0.0 and _boost_level > 0.0:
		_boost_level *= exp(-delta / boost_decay_duration)
	else:
		_boost_level = 0.0

	# Speed alvo é uma mistura entre base e boost conforme o nível atual
	var boosted_target = lerp(_base_speed, boost_speed, clamp(_boost_level, 0.0, 1.0))
	_target_speed = boosted_target

	# Suaviza valores atuais até os alvos
	amplitude_deg = lerp(amplitude_deg, _target_amp, 4.0 * delta)
	speed = lerp(speed, _target_speed, 4.0 * delta)

	# Animação do balanço
	_t += delta * speed
	var amp_rad := deg_to_rad(amplitude_deg)
	var phase_diff := deg_to_rad(offset_between_sprites_deg)

	var sway_left := sin(_t + _phase0) * amp_rad
	var sway_right := sin(_t + _phase0 + phase_diff) * amp_rad

	_left.rotation.z  = _base_left_z  + sway_left
	_right.rotation.z = _base_right_z + sway_right
