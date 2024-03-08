extends RichTextEffect
class_name RichTextWaitGD

signal wait_finished()
signal char_displayed()

const bbcode: String = 'wait'

var skip: bool = false
var speed: float = 50.0
var pause_value: float = 0.45

var pauses_dict = {}
var speed_dict = {}
var last_index: int = 0
var next_char: int = 0

var half_pause: float
var pause_char: int
var half_pause_chars: Array

var current_speed: float
var current_pause: float
var last_frame_time: float
var elapsed_time: float

func init_text(char_fx: CharFXTransform) -> void:
	init_dictionary('pause', char_fx, pauses_dict)
	init_dictionary('speed', char_fx, speed_dict)
	init_pause_chars(char_fx)

	next_char = 0
	last_index = 0
	current_pause = 0
	current_speed = speed
	elapsed_time = 0.0
	last_frame_time = 0
	half_pause = pause_value / 2

	if pauses_dict != null and pauses_dict.has(0):
		current_pause = pauses_dict[0]
	elif char_fx.glyph_index == pause_char:
		current_pause += pause_value

func init_pause_chars(char_fx: CharFXTransform) -> void:
	pause_char = char_to_glyph_index(char_fx.font, '.'.unicode_at(0))

	half_pause_chars = [
		char_to_glyph_index(char_fx.font, ','.unicode_at(0)),
		char_to_glyph_index(char_fx.font, ';'.unicode_at(0)),
		char_to_glyph_index(char_fx.font, ':'.unicode_at(0))
	]

func char_to_glyph_index(font : RID, c : int) -> int:
	return TextServerManager.get_primary_interface().font_get_glyph_index(font, 1, c, 0)

func init_dictionary(code: String, char_fx: CharFXTransform, dict) -> void:
	var has_pause_positions: bool = char_fx.env.has(code + 'Positions')
	var has_pause_values: bool = char_fx.env.has(code + 'Values')

	if has_pause_positions and has_pause_values:
		var positions: Array[int]
		var values: Array[float]
		
		var tag_position = char_fx.env[code + 'Positions']
		var tag_value = char_fx.env[code + 'Values']
		
		if tag_position is float and tag_value is float:
			positions.append(int(tag_position))
			values.append(tag_value)
		elif tag_position is Array and tag_value is Array:
			for pos in tag_position:
				positions.append(int(pos))
			for val in tag_value:
				values.append(float(val))
				
		if positions.size() == values.size():
			dict.clear()
			for i in range(positions.size()):
				dict[positions[i]] = values[i]
				
func _process_custom_fx(char_fx):
	if char_fx.elapsed_time == 0 and char_fx.relative_index == 0:
		init_text(char_fx)

	var delta = char_fx.elapsed_time - last_frame_time
	last_frame_time = char_fx.elapsed_time
	elapsed_time += delta
	last_index = max(last_index, char_fx.relative_index)

	if char_fx.relative_index >= next_char:
		var absolute_index = char_fx.relative_index

		if elapsed_time > float(absolute_index) / current_speed + current_pause or skip:
			if pause_char == char_fx.glyph_index:
				current_pause += pause_value
			elif half_pause_chars.has(char_fx.glyph_index):
				current_pause += half_pause
			
			char_fx.visible = true
			next_char += 1

			if not skip:
				emit_signal('char_displayed')

			if absolute_index >= last_index:
				emit_signal('wait_finished')

			if pauses_dict != null and pauses_dict.has(absolute_index):
				current_pause += pauses_dict[absolute_index]

			if speed_dict != null and speed_dict.has(absolute_index):
				current_speed = speed_dict[absolute_index]

				if current_speed < 1:
					current_speed = speed
				elapsed_time = float(absolute_index) / current_speed + current_pause
		else:
			# character waiting to be processed
			char_fx.visible = false
	else:
		# character already processed
		char_fx.visible = true

	return true
