extends Node
class_name SaveService

const SAVE_PATH := "user://savegame.json"

func save_game(state: GameState) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveService: erro ao salvar jogo.")
		return
	file.store_string(JSON.stringify(state.to_dict()))
	file.close()
	print("💾 Jogo salvo em:", SAVE_PATH)

func load_game(state: GameState) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveService: arquivo de save inválido.")
		return false
	state.from_dict(data)
	return true

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
