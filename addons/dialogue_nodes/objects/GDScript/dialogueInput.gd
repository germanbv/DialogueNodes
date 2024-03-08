@tool
extends Control

var skip_input_action: String
var dialogue_ui: Node
var is_running: bool

func initialize(skip_input: String):
	skip_input_action = skip_input
	dialogue_ui =  get_parent().get_parent()
	
	if (dialogue_ui == null):
		printerr("dialogueInput.gd: Impossible to find DialogueUI")
	else:
		is_running = true

func _gui_input(event):
	if not is_running:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dialogue_ui.on_dialogue_input()

func _unhandled_input(event):
	if not is_running:
		return
	if event.is_action_pressed(skip_input_action):
		print("test")
		dialogue_ui.on_dialogue_input()

