@tool
extends Control

@export var nextIcon = load('res://addons/dialogue_nodes/icons/Play.svg')
@export var speakerTxtColor = Color(1, 1, 1)
@export var hidePortrait : bool
@export var speaker : Label
@export var speakerPortrait : TextureRect
@export var dialogue : RichTextLabel
@export var optionsButtons : Array[Button]

var dialogueCore
var dialogueManager
var characterList : CharacterListGD
var signalsDict : Dictionary
var optionsContainer : BoxContainer
var transitionEffect : RichTextEffect

func initialize(_dialogueManager, enable_transition: bool, textSpeed, punctuationPause):
	hide()
	dialogueManager = _dialogueManager
	dialogueCore = dialogueManager.get_core_manager()
	signalsDict = {}
	optionsContainer = optionsButtons[0].get_parent()
	init_transition_fx(enable_transition, textSpeed, punctuationPause)
	init_custom_effects()
	reset_values()

func display(toggle):
	visible = toggle
	if not toggle:
		reset_values()
		characterList = null

func set_character_list(_characterList):
	characterList = _characterList

func set_dialogue(dict):
	reset_values()
	set_speaker(dict)
	dialogue.text = dialogueCore.process_text(dict['dialogue'])
	dialogue.get_v_scroll_bar().value = 0
	
	if transitionEffect is RichTextWaitGD:
		transitionEffect.skip = false
		
	set_options(dict)

func on_dialogue_input():
	if transitionEffect is RichTextWaitGD:
			transitionEffect.skip = true
	optionsContainer.show()

func grab_first_option_focus():
	optionsButtons[0].grab_focus()

func init_custom_effects():
	dialogue.install_effect(RichTextColorModGD.new())
	dialogue.install_effect(RichTextCussGD.new())
	dialogue.install_effect(RichTextGhostGD.new())
	dialogue.install_effect(RichTextHeartGD.new())
	dialogue.install_effect(RichTextJumpGD.new())
	dialogue.install_effect(RichTextL33TGD.new())
	dialogue.install_effect(RichTextNervousGD.new())
	dialogue.install_effect(RichTextNumberGD.new())
	dialogue.install_effect(RichTextRainGD.new())
	dialogue.install_effect(RichTextSparkleGD.new())
	dialogue.install_effect(RichTextWooGD.new())
	dialogue.install_effect(RichTextUwuGD.new())

func init_transition_fx(enable_transition: bool, textSpeed, punctuationPause):
	if enable_transition:
		transitionEffect = RichTextWaitGD.new()
		transitionEffect.speed = textSpeed
		transitionEffect.pause_value = punctuationPause
		transitionEffect.connect('wait_finished', show_options)
		transitionEffect.connect('char_displayed', reveal_char)
		dialogue.install_effect(transitionEffect)
		
func set_speaker(dict):
	if 'speaker' in dict:
		var speakerValue = dict['speaker']
		if characterList != null and typeof(speakerValue) == TYPE_INT:
			var idx = speakerValue
			if idx > -1 and idx < characterList.characters.size():
				speaker.text = characterList.characters[idx].name
				speaker.modulate = characterList.characters[idx].color
				if not hidePortrait and characterList.characters[idx].image != null:
					speakerPortrait.texture = characterList.characters[idx].image
	speakerPortrait.visible = not hidePortrait and speakerPortrait.texture != null
	speaker.visible = speaker.text != ''

func set_options(dict):
	hide_options()
	if 'options' in dict:
		var optionsDict = dict['options']
		var optionsVisibleCount = 0
		
		for idx in optionsDict.keys():
			var option = optionsButtons[idx]
			var idxValue = optionsDict[idx]
			var link = idxValue['link']
			
			option.text = dialogueCore.process_text(idxValue['text'], false)
			
			var pressOption = Callable(self, 'on_option_pressed')
			pressOption = pressOption.bind(idxValue, link)
			connect_options_signals(option, pressOption)
			
			var hasCondition = 'condition' in idxValue
			if hasCondition and len(idxValue['condition']) > 0:
				option.visible = dialogueCore.check_condition(idxValue['condition'])
			else:
				option.show()
			if option.visible:
				optionsVisibleCount += 1
		if optionsVisibleCount == 0:
			optionsButtons[0].text = ''
			optionsButtons[0].icon = nextIcon
			var proceedCallable = Callable(self, 'end_dialogue_core')
			connect_options_signals(optionsButtons[0], proceedCallable)
			optionsButtons[0].show()
		if len(optionsDict) == 1 and optionsButtons[0].text == '':
			optionsButtons[0].icon = nextIcon
		if transitionEffect == null:
			show_options()

func end_dialogue_core():
	dialogueCore.end_dialogue()

func hide_options():
	optionsContainer.hide()
	for btn in optionsButtons:
		btn.icon = null
		btn.hide()

func show_options():
	if optionsContainer.is_inside_tree():
		for btn in optionsButtons:
			if btn.visible:
				btn.grab_focus()
				break
		optionsContainer.show()

func reveal_char():
	dialogueManager.emit_char_displayed()

func connect_options_signals(button, newCallable):
	if button in signalsDict.keys():
		var containedCallable = signalsDict[button]
		if button.is_connected('pressed', containedCallable):
			button.disconnect('pressed', containedCallable)
			signalsDict.erase(button)

	button.connect('pressed', newCallable)
	signalsDict[button] = newCallable

func disconnect_options_signals():
	if signalsDict == null or signalsDict.size() <= 0:
		return
	for button in signalsDict:
		var value = signalsDict[button]
		if button.is_connected('pressed', value):
			button.disconnect('pressed', value)
	signalsDict.clear()

func reset_values():
	disconnect_options_signals()
	speaker.text = ''
	dialogue.text = ''
	speaker.modulate = speakerTxtColor
	speakerPortrait.texture = null

func on_option_pressed(idx, link):
	dialogueManager.emit_option_selected(idx)
	dialogueCore.process_node(link)
