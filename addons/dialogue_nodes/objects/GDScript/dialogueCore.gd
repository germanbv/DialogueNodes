@tool
extends Node

var is_running : bool
var dialogue_ui
var dialogue_manager
var dialogue_data : DialogueDataGD
var variables : Dictionary
var bbcode_regex : RegEx
var enable_transition: bool
var punctuation_pause : float

func initialize(_dialogue_manager, _enable_transition, _punctuation_pause: float) -> void:
	bbcode_regex = RegEx.new()
	bbcode_regex.compile('\\n|\\[img\\].*?\\[\\/img\\]|\\[.*?\\]')

	dialogue_manager = _dialogue_manager
	enable_transition = _enable_transition
	punctuation_pause = _punctuation_pause
	dialogue_ui = dialogue_manager.get_ui_manager()

func start(dialogue_data: DialogueDataGD, start_id: String) -> void:
	self.dialogue_data = dialogue_data

	if error_checks(start_id):
		return

	is_running = true
	init_variables()
	init_character_list()
	process_node(dialogue_data.Starts[start_id])
	dialogue_manager.emit_dialogue_started(start_id)

func end_dialogue():
	process_node('END')

func error_checks(start_id: String) -> bool:
	if dialogue_data == null:
		printerr('DialogueCore: No dialogue data!')
		return true
	elif not dialogue_data.Starts.has(start_id):
		printerr(dialogue_data.FileName + ': StartID \"' + start_id + '\" is not present!')
		return true
	elif dialogue_ui == null:
		printerr('DialogueCore: DialogueUI was not found!')
		return true
	return false

func init_variables() -> void:
	if dialogue_data.Variables != null:
		variables = variables if variables != null else {}
		variables.clear()

		for variable in dialogue_data.Variables.keys():
			var dict = {}
			dict['type'] = dialogue_data.Variables[variable]['type']
			dict['value'] = dialogue_data.Variables[variable]['value']
			variables[variable] = dict

func init_character_list() -> void:
	if dialogue_data.Characters != '' and dialogue_data.Characters != null:
		var res = ResourceLoader.load(dialogue_data.Characters, '', ResourceLoader.CACHE_MODE_REPLACE)
		if res != null:
			var characterList = CharacterListGD.new()
			var characters = res.get('Characters')
			
			for char in characters:
				var characterGD = CharacterGD.new()
				characterGD.name = char.Name
				characterGD.image = char.Image
				characterGD.color = char.Color
				characterList.characters.append(characterGD)
			dialogue_ui.set_character_list(characterList)
		else:
			printerr('Invalid Character File!')

func process_text(text: String, is_dialogue: bool = true) -> String:
	if text.is_empty() and is_dialogue:
		text = ' '

	if text.find('{{') != -1:
		if variables != null:
			for key in variables.keys():
				var key_code = '{{' + str(key) + '}}'

				if text.contains(key_code):
					var formatted_value: String
					if (variables[key]['value'] is float):
						formatted_value = '%0.2f' % variables[key]['value']
					else:
						formatted_value = str(variables[key]['value'])
						
					text = text.replace(key_code, formatted_value)

	text = text.replace('[br]', '\n')

	if is_dialogue and enable_transition:
		text = process_transition_fx(text)

	return text

func process_node(node_id: String) -> void:
	if node_id == 'END' or not is_running:
		dialogue_manager.stop()
		return

	var type = node_id.split('_')[0]

	match type:
		'0':
			# Start
			dialogue_ui.display(true)
			var link_value = dialogue_data.Nodes[node_id]['link']
			process_node(link_value)
		'1':
			# Dialogue
			dialogue_ui.set_dialogue(dialogue_data.Nodes[node_id])
		'3':
			# Signal
			var dict = dialogue_data.Nodes[node_id]
			var signal_value = dict.get('signalValue', null)
			var link = dict.get('link', null)
			dialogue_manager.emit_dialogue_signal(signal_value)
			process_node(link)
		'4':
			# Set
			var var_dict = dialogue_data.Nodes[node_id]
			var value = var_dict['value']
			var operator_variant = var_dict['type']
			var var_name = var_dict['variable']
			var var_link = var_dict['link']
			if set_variable(var_name, value, operator_variant):
				dialogue_manager.emit_internal_variable_changed(var_name, variables[var_name]['value'])
			process_node(var_link)
		'5':
			# Condition
			var result = check_condition(dialogue_data.Nodes[node_id])
			var link_condition = dialogue_data.Nodes[node_id][str(result).to_lower()]
			process_node(link_condition)
		_:
			if dialogue_data.Nodes[node_id]['link']:
				var default_link = dialogue_data.Nodes[node_id]['link']
				process_node(default_link)
			else:
				dialogue_manager.stop()

	dialogue_manager.emit_dialogue_proceeded(type)
	

func set_variable(var_name: Variant, value: Variant, operator_int: int = 0) -> bool:
	if not check_value_types(var_name, value):
		return false
		
	match operator_int:
		0: # =
			variables[var_name]['value'] = value
			return true
		1, 2, 3, 4: # +=, -=, *=, /=
			if value is int:
				var current_value = variables[var_name]['value'] if variables.has(var_name) else 0
				var factor_int = value
				match operator_int:
					1: variables[var_name]['value'] = current_value + factor_int
					2: variables[var_name]['value'] = current_value - factor_int
					3: variables[var_name]['value'] = current_value * factor_int
					4: variables[var_name]['value'] = int(float(current_value) / factor_int) if factor_int != 0 else 0
					_: variables[var_name]['value']
				return true
			elif value is float:
				var float_value = float(variables[var_name]['value']) if variables.has(var_name) else 0.0
				var value_float = value
				match operator_int:
					1: variables[var_name]['value'] = float_value + value_float
					2: variables[var_name]['value'] = float_value - value_float
					3: variables[var_name]['value'] = float_value * value_float
					4: variables[var_name]['value'] = float_value / value_float if value_float != 0.0 else 0.0
					_: variables[var_name]['value']
				return true
			elif value is String and operator_int == 1:
				var string_value = variables[var_name]['value'] if variables.has(var_name) else ''
				variables[var_name]['value'] = string_value + value
				return true
			else:
				var op
				match operator_int:
					1: op = '+'
					2: op = '-'
					3: op = '*'
					4: op = '/'
					_: op = 'invalid'
				printerr(dialogue_data.FileName + ': \'' + var_name + '\' is of type \'' + variables[var_name]['value'].get_type_name() + '\' and \'' + str(value) + '\' is of type \'' + value.get_type_name() + '\', they can\'t be used with the operator \'' + op + '\'')
				return false
		_: # default
			printerr(dialogue_data.FileName + ': ' + var_name + ' comes with an invalid operator, review the dialogueData file or the dialogue nodes plugin')
			return false

func check_value_types(var_name: Variant, value) -> bool:
	if typeof(variables[var_name]['value']) == typeof(value):
		return true
	else:
		printerr('ERROR: The variable ' + str(var_name) + ' is of type ' + type_string(typeof(variables[var_name]['value'])).to_upper() + ', you are attempting to assign it a value of type ' + type_string(typeof(value)).to_upper())
		return false

func check_condition(condition_dict: Dictionary) -> bool:
	var operator_int = condition_dict['operator']
	var var_name = condition_dict['value1']
	var value = condition_dict['value2']
	return check_internal_condition(var_name, value, operator_int)

func check_internal_condition(var_name: Variant, value: Variant, operator_int: int) -> bool:
	if not variables.has(var_name):
		printerr('WARNING: The variable ' + var_name + ' is not part of the internal variables dictionary')
		return false
	elif value is String:
		var string_value = value
		if string_value.begins_with('{{') and string_value.ends_with('}}'):
			string_value = string_value.substr(2, string_value.length() - 4)
			if variables.has(string_value):
				value = variables[string_value]['value']

	if typeof(variables[var_name]['value']) != typeof(value):
		printerr('WARNING: The variable ' + var_name.to_upper() + ' is of type ' + type_string(typeof(variables[var_name]['value'])).to_upper() + ' and you are comparing it against a variable of type ' + type_string(typeof(value)).to_upper())
		return false

	match typeof(value):
		TYPE_STRING:
			match operator_int:
				0: return variables[var_name]['value'] == value
				1: return variables[var_name]['value'] != value
				_: return false
		TYPE_BOOL:
			match operator_int:
				0: return variables[var_name]['value'] == value
				1: return variables[var_name]['value'] != value
				_: return false
		TYPE_INT:
			match operator_int:
				0: return variables[var_name]['value'] == value
				1: return variables[var_name]['value'] != value
				2: return variables[var_name]['value'] > value
				3: return variables[var_name]['value'] < value
				4: return variables[var_name]['value'] >= value
				5: return variables[var_name]['value'] <= value
				_: return false
		TYPE_FLOAT:
			match operator_int:
				0: return variables[var_name]['value'] == value
				1: return variables[var_name]['value'] != value
				2: return variables[var_name]['value'] > value
				3: return variables[var_name]['value'] < value
				4: return variables[var_name]['value'] >= value
				5: return variables[var_name]['value'] <= value
				_: return false
		_: return false

func process_transition_fx(text: String) -> String:
	var tags := []
	text = sanitize_custom_tags('pause', text, tags)
	text = sanitize_custom_tags('speed', text, tags)
	text = setup_wait_tag(text, tags)
	return text
	
func setup_wait_tag(text: String, tags: Array) -> String:
	text = '[wait]' + text
	var open_tag_end = text.find(']', 0)
	var insert_text = ''

	for s in tags:
		insert_text += ' ' + s

	return text.insert(open_tag_end, insert_text)
	
func sanitize_custom_tags(code_tag: String, text: String, tags: Array) -> String:
	var code = '[' + code_tag + '=';
	var open_tag_index = text.find(code, 0)
	
	if open_tag_index != -1:
		var pauses_dict = {}

		while open_tag_index != -1:
			var end_tag_index = text.find(']', open_tag_index)
			if end_tag_index != -1:
				var start = open_tag_index + code.length()
				var length = end_tag_index - start

				if length > 0:
					var tag_value_str = text.substr(start, length)
					var tag_value = tag_value_str.to_float()
					
					if tag_value != null:
						pauses_dict[open_tag_index] = tag_value
						text = text.erase(open_tag_index, end_tag_index - open_tag_index + 1)
						open_tag_index = text.find(code, open_tag_index)
					else:
						printerr('DialogueCore: Impossible to get ${code_tag} value at index ${open_tag_index}')
						open_tag_index = -1
				else:
					open_tag_index = -1

		if pauses_dict.size() > 0:
			var positions_tag = code_tag + 'Positions=' + ','.join(pauses_dict.keys())
			var values_tag = code_tag + 'Values=' + ','.join(pauses_dict.values())

			tags.append(positions_tag)
			tags.append(values_tag)

	return text
