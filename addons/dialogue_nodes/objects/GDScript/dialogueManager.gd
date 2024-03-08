@tool
@icon("res://addons/dialogue_nodes/icons/Dialogue.svg")
extends Control

# Signals
signal dialogue_started(id: String)
signal dialogue_proceeded(node_type: String)
signal dialogue_signal(value: String)
signal dialogue_ended
signal char_displayed
signal variable_changed(var_name: String, value: Variant)
signal option_selected(idx: int)

# Exported variables
@export var start_id : String = "Start"
@export var skip_input_action : String = "ui_accept"
@export var enable_transition : bool = true
@export var text_speed : float = 50.0
@export var punctuation_pause : float = 0.45

# Internal variables
var dialogue_core : Node
var dialogue_ui : Node

func initialize():
	hide()
	dialogue_core = $DialogueCore
	dialogue_ui = $DialogueUI
	
	dialogue_ui.get_node('MarginContainer/DialogueInput').initialize(skip_input_action)
	dialogue_ui.initialize(self, enable_transition, text_speed, punctuation_pause)
	dialogue_core.initialize(self, enable_transition, punctuation_pause)

func start(dialogue_data : DialogueDataGD, dialogue_id : String):
	dialogue_core.start(dialogue_data, dialogue_id)
	show()

func stop():
	dialogue_ui.display(false)
	dialogue_core.is_running = false
	hide()
	emit_signal('dialogue_ended')

func is_running():
	return dialogue_core.is_running

func add_external_variable(obj):
	dialogue_core.add_external_variables(obj)

func get_ui_manager():
	return dialogue_ui

func get_core_manager():
	return dialogue_core

func emit_dialogue_started(id):
	emit_signal('dialogue_started', id)

func emit_dialogue_proceeded(node_type):
	emit_signal('dialogue_proceeded', node_type)

func emit_dialogue_signal(value):
	emit_signal('dialogue_signal', value)

func emit_internal_variable_changed(var_name, value):
	emit_signal('variable_changed', var_name, value)

func emit_option_selected(idx):
	emit_signal('option_selected', idx)

func emit_char_displayed():
	emit_signal('char_displayed')
