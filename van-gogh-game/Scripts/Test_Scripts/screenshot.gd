# camera_screenshot.gd
# Anexe este script ao seu nó Camera3D

extends Camera3D

# A variável que aparecerá no inspetor para você definir o diretório de destino.
# "user://" é o diretório ideal para salvar dados do usuário, como prints e saves.
@export var save_directory: String = "user://screenshots"
@onready var buildings: Node3D = $"../Buildings"

# Esta função é chamada toda vez que há uma entrada (teclado, mouse, etc.)
func _input(event: InputEvent) -> void:
	# Verifica se a tecla Enter foi pressionada. Mude para a tecla que preferir.
	if event.is_action_pressed("ui_accept"): # "ui_accept" é Enter/Espaço por padrão
		take_screenshot()

# A função principal que tira a foto
func take_screenshot() -> void:
	# 1. Encontrar o primeiro filho do tipo Node3D para usar como nome do arquivo.
	var target_node: Node3D = null
	for child in buildings.get_children():
		if child is Node3D:
			target_node = child
			break # Para no primeiro que encontrar

	# 2. Se nenhum filho Node3D for encontrado, avise e pare a execução.
	if not target_node:
		print("Nenhum nó filho do tipo Node3D encontrado na câmera para usar como nome de arquivo.")
		return

	# 3. Garante que o diretório de destino exista.
	DirAccess.make_dir_recursive_absolute(save_directory)

	# NOME IMPORTANTE: Esperar pelo próximo quadro de processamento.
	# Isso garante que a viewport já foi renderizada com a imagem atual antes de capturá-la.
	# Sem isso, você pode pegar uma imagem preta ou do quadro anterior.
	await get_tree().process_frame

	# 4. Capturar a imagem da viewport.
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	
	# Opcional: Se sua câmera não ocupa a tela inteira, você pode querer
	# recortar a imagem para o tamanho da câmera.
	# img = img.get_rect(get_viewport().get_camera_3d().get_frustum())

	# 5. Montar o nome e o caminho completo do arquivo, garantindo que seja único.
	var base_name = target_node.name
	var file_path = save_directory.path_join(base_name + ".png")
	var counter = 1
	
	# Loop: Enquanto o arquivo no caminho 'file_path' já existir...
	while FileAccess.file_exists(file_path):
		# ...crie um novo nome com o sufixo do contador.
		var new_name = "%s_%d.png" % [base_name, counter]
		file_path = save_directory.path_join(new_name)
		# Incremente o contador para a próxima verificação, caso este também exista.
		counter += 1

	# 6. Salvar a imagem no formato PNG.
	var err = img.save_png(file_path)

	# 7. Verificar se houve erro ao salvar.
	if err == OK:
		print("Screenshot salvo com sucesso em: ", ProjectSettings.globalize_path(file_path))
	else:
		print("Falha ao salvar o screenshot. Código de erro: ", err)
