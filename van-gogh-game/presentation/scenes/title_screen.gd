extends Node

@onready var btn_play = %BtnPlay
@onready var btn_option = %BtnOption
@onready var btn_quit = %BtnQuit

@onready var menu_buttons: Array[Button] = [btn_play, btn_option, btn_quit]
@onready var game_manager = get_node("/root/GameManager")

var selected_button_index = 0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_select_button(selected_button_index)

func _unhandled_key_input(event: InputEvent):
	
	if event.is_action_pressed("ui_down"):
		selected_button_index = (selected_button_index + 1) % menu_buttons.size()
		_select_button(selected_button_index)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_up"):
		selected_button_index = (selected_button_index - 1 + menu_buttons.size()) % menu_buttons.size()
		_select_button(selected_button_index)
		get_viewport().set_input_as_handled()
	
func _select_button(index: int):
	menu_buttons[index].grab_focus()

func _on_btn_quit_pressed():
	get_tree().quit()

func _on_btn_play_pressed():
	for button in menu_buttons:
		button.disabled = true
	game_manager.request_start_game()
