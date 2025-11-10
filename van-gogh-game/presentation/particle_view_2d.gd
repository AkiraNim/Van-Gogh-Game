extends PanelContainer

# === Texturas para os Sprite2D ===
@export var flake_texture: Texture2D
@export var ball_texture: Texture2D

# === Limites de instâncias ===
@export var max_flakes: int = 10
@export var max_balls: int = 10

# === Intervalos de spawn (segundos) ===
@export var flake_spawn_interval: Vector2 = Vector2(0.15, 0.45)
@export var ball_spawn_interval:  Vector2 = Vector2(0.30, 0.80)

# === Velocidades base (px/s) → sempre direita/baixo ===
@export var flake_speed_x: Vector2 = Vector2(25.0, 55.0)
@export var flake_speed_y: Vector2 = Vector2(35.0, 85.0)
@export var ball_speed_x:  Vector2 = Vector2(35.0, 70.0)
@export var ball_speed_y:  Vector2 = Vector2(55.0, 120.0)

# === Irregularidade do movimento ===
@export var drift_strength: float = 18.0
@export var drift_freq: Vector2 = Vector2(0.6, 1.2)

# === Escala opcional (1 = usa o tamanho da textura) ===
@export var flake_scale: Vector2 = Vector2(1, 1)
@export var ball_scale:  Vector2 = Vector2(1, 1)

var _time := 0.0
var _spawn_t_flake := 0.0
var _spawn_t_ball := 0.0
var _next_flake := 0.3
var _next_ball := 0.5

func _ready() -> void:
	randomize()
	_reset_spawn_times()

func _process(delta: float) -> void:
	_time += delta
	_update_spawn(delta)
	_update_movement(delta)

# -------------------- SPAWN --------------------

func _update_spawn(delta: float) -> void:
	_spawn_t_flake += delta
	_spawn_t_ball += delta

	if _spawn_t_flake >= _next_flake and _count_kind("flake") < max_flakes:
		_make_particle("flake")
		_spawn_t_flake = 0.0
		_next_flake = randf_range(flake_spawn_interval.x, flake_spawn_interval.y)

	if _spawn_t_ball >= _next_ball and _count_kind("ball") < max_balls:
		_make_particle("ball")
		_spawn_t_ball = 0.0
		_next_ball = randf_range(ball_spawn_interval.x, ball_spawn_interval.y)

func _reset_spawn_times() -> void:
	_next_flake = randf_range(flake_spawn_interval.x, flake_spawn_interval.y)
	_next_ball  = randf_range(ball_spawn_interval.x,  ball_spawn_interval.y)

func _count_kind(kind: String) -> int:
	var n := 0
	for c in $SnowLayer.get_children():
		if c is Sprite2D and c.get_meta("kind") == kind:
			n += 1
	return n

func _make_particle(kind: String) -> void:
	var tex: Texture2D = flake_texture if kind == "flake" else ball_texture
	if tex == null:
		return

	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = true
	sp.scale = flake_scale if kind == "flake" else ball_scale
	sp.set_meta("kind", kind)

	# posição inicial (um pouco acima/esquerda) para cair em diagonal
	var panel_size := size
	var start_x := randf_range(-32.0, panel_size.x * 0.4)
	var start_y := randf_range(-48.0, panel_size.y * 0.15)
	sp.position = Vector2(start_x, start_y)

	# velocidade base
	var vx := randf_range(flake_speed_x.x, flake_speed_x.y) if kind == "flake" else randf_range(ball_speed_x.x,  ball_speed_x.y)
	var vy := randf_range(flake_speed_y.x, flake_speed_y.y) if kind == "flake" else randf_range(ball_speed_y.x,  ball_speed_y.y)
	sp.set_meta("vel", Vector2(vx, vy))

	# drift por instância
	sp.set_meta("phase", randf() * TAU)
	sp.set_meta("freq",  randf_range(drift_freq.x, drift_freq.y))

	$SnowLayer.add_child(sp)

# -------------------- MOVIMENTO --------------------

func _update_movement(delta: float) -> void:
	var panel_size := size
	for c in $SnowLayer.get_children():
		if not (c is Sprite2D):
			continue

		var vel: Vector2 = c.get_meta("vel")
		var phase: float = c.get_meta("phase")
		var freq: float  = c.get_meta("freq")

		# drift irregular para “dançar”
		var drift_x := sin(_time * freq + phase) * drift_strength
		var drift_y := cos((_time + 1.7) * freq + phase) * (drift_strength * 0.35)

		var v := vel + Vector2(drift_x, drift_y)
		c.position += v * delta

		# remove quando sair da área do painel
		if c.position.x > panel_size.x + 64 or c.position.y > panel_size.y + 64:
			c.queue_free()
