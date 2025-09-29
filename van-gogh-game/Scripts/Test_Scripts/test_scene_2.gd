extends Node3D

# (todas as suas outras variáveis @export permanecem aqui)
# ---
@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D
@export_group("Cores das Zonas")
@export var cor_zona_vermelha: Color = Color("ff4d4d")
@export var cor_zona_azul: Color = Color("4d89ff")
@export var cor_zona_verde: Color = Color("4dff5b")
@export var cor_zona_amarela: Color = Color("fff64d")
@export var cor_neutra: Color = Color.WHITE
@export var cor_padrao: Color = Color.WHITE
@export_group("Rotações da DirectionalLight (em Graus)")
@export var rotacao_zona_vermelha: Vector3 = Vector3(-90, 0, 0)
@export var rotacao_zona_azul: Vector3 = Vector3(-45, 45, 0)
@export var rotacao_zona_verde: Vector3 = Vector3(-45, -45, 0)
@export var rotacao_zona_amarela: Vector3 = Vector3(-90, 90, 0)
@export var rotacao_neutra: Vector3 = Vector3(-60, 0, 0)
@export var rotacao_padrao: Vector3 = Vector3(-60, 0, 0)
@export_group("Zonas (Area3D)")
@export var zona_vermelha: Area3D
@export var zona_azul: Area3D
@export var zona_verde: Area3D
@export var zona_amarela: Area3D
@export var zona_neutra: Area3D

# >>> A NOVA VARIÁVEL QUE VOCÊ ADICIONOU E CONECTOU <<<
@export var area_do_patrulheiro_para_teste: Area3D

var zonas_atuais: Array[Area3D] = []
var cor_tween: Tween
var rotacao_tween: Tween


func _ready():
	var todas_as_zonas = [zona_vermelha, zona_azul, zona_verde, zona_amarela, zona_neutra]
	for zona in todas_as_zonas:
		if zona:
			zona.area_entered.connect(_on_area_entered.bind(zona))
			zona.area_exited.connect(_on_area_exited.bind(zona))
			
	# >>> VAMOS CHAMAR NOSSA NOVA FUNÇÃO DE DIAGNÓSTICO <<<
	_diagnosticar_configuracoes()


# >>>>>>>>>>>> NOVA FUNÇÃO DE DIAGNÓSTICO <<<<<<<<<<<<<<
func _diagnosticar_configuracoes():
	print("--- INICIANDO DIAGNÓSTICO DE COLISÃO ---")
	
	# Verifica o Patrulheiro
	if not is_instance_valid(area_do_patrulheiro_para_teste):
		print("!!! ERRO CRÍTICO: 'Area Do Patrulheiro Para Teste' não foi conectada no Inspetor!")
	else:
		print("\n--- VERIFICANDO O PATRULHEIRO ---")
		var p_area = area_do_patrulheiro_para_teste
		print("Nome do Nó: {p_area.name}")
		
		print("Propriedade 'Monitorable': {p_area.monitorable}")
		print("Camada de Colisão (Layer): {p_area.collision_layer}")
		print("Máscara de Colisão (Mask): {p_area.collision_mask}")
		var p_shape = p_area.get_child(0) if p_area.get_child_count() > 0 else null
		print("Tem CollisionShape? {'SIM' if p_shape else 'NÃO'}")

	# Verifica as Zonas
	print("\n--- VERIFICANDO AS ZONAS ---")
	var todas_as_zonas = [zona_vermelha, zona_azul, zona_verde, zona_amarela, zona_neutra]
	for zona in todas_as_zonas:
		if not is_instance_valid(zona):
			print("AVISO: Uma das zonas não foi conectada no inspetor.")
			continue # Pula para a próxima
			
		print("\n- Zona: {zona.name}")
		print("  Propriedade 'Monitoring': {zona.monitoring}")
		print("  Camada de Colisão (Layer): {zona.collision_layer}")
		print("  Máscara de Colisão (Mask): {zona.collision_mask}")
		var z_shape = zona.get_child(0) if zona.get_child_count() > 0 else null
		print("  Tem CollisionShape? {'SIM' if z_shape else 'NÃO'}")

	print("\n--- FIM DO DIAGNÓSTICO ---")


# (O resto do seu código permanece exatamente o mesmo daqui para baixo)

func _on_area_entered(area: Area3D, zona: Area3D):
	if area.is_in_group("player"):
		print("ENTROU na zona: {zona.name}")
		if not zonas_atuais.has(zona):
			zonas_atuais.push_back(zona)
		_atualizar_estado_ambiente()

# ... (resto do seu código)
func _on_area_exited(area: Area3D, zona: Area3D):
	if area.is_in_group("player"):
		print("SAIU da zona: {zona.name}")
		if zonas_atuais.has(zona):
			zonas_atuais.erase(zona)
		_atualizar_estado_ambiente()

func _atualizar_estado_ambiente():
	if zonas_atuais.has(zona_neutra):
		_iniciar_transicao(cor_neutra, rotacao_neutra)
	elif zonas_atuais.has(zona_vermelha):
		_iniciar_transicao(cor_zona_vermelha, rotacao_zona_vermelha)
	elif zonas_atuais.has(zona_azul):
		_iniciar_transicao(cor_zona_azul, rotacao_zona_azul)
	elif zonas_atuais.has(zona_verde):
		_iniciar_transicao(cor_zona_verde, rotacao_zona_verde)
	elif zonas_atuais.has(zona_amarela):
		_iniciar_transicao(cor_zona_amarela, rotacao_zona_amarela)
	else:
		_iniciar_transicao(cor_padrao, rotacao_padrao)

func _iniciar_transicao(cor_alvo: Color, rotacao_alvo_graus: Vector3):
	_transicionar_cor(cor_alvo)
	_transicionar_rotacao(rotacao_alvo_graus)

func _transicionar_cor(cor_alvo: Color):
	if cor_tween and cor_tween.is_running(): cor_tween.kill()
	cor_tween = create_tween()
	cor_tween.tween_property(world_environment.environment, "ambient_light_color", cor_alvo, 1.5).set_trans(Tween.TRANS_SINE)

func _transicionar_rotacao(rotacao_alvo_graus: Vector3):
	if not directional_light: return
	if rotacao_tween and rotacao_tween.is_running(): rotacao_tween.kill()
	rotacao_tween = create_tween()
	rotacao_tween.tween_property(directional_light, "rotation_degrees", rotacao_alvo_graus, 1.5).set_trans(Tween.TRANS_SINE)
