# Script no StaticBody3D

@tool
extends StaticBody3D

func _process(delta):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	# A lógica abaixo calcula a rotação necessária para encarar a câmera.
	# Esta rotação será aplicada ao StaticBody3D.
	# Podemos considerar esta a "rotação de billboard".
	
	var camera_position = camera.global_position
	var look_at_target = camera_position
	look_at_target.y = global_position.y
	
	# A função look_at() aplica a rotação de billboard ao StaticBody3D.
	look_at(look_at_target, Vector3.UP)
	
	# O "Valor Novo" final do seu sprite/colisão será a combinação automática
	# da rotação deste corpo (billboard) com a rotação do nó "Pivo" ("Valor Pensado").
