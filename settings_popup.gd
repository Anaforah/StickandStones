extends Control

@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var close_top_button: Button = $Panel/VBoxContainer/ScrollContainer/ContentVBox/HeaderHBox/CloseTopButton
@onready var volume_slider: HSlider = $Panel/VBoxContainer/ScrollContainer/ContentVBox/VolumeContainer/VolumeSlider
@onready var volume_value: Label = $Panel/VBoxContainer/ScrollContainer/ContentVBox/VolumeContainer/VolumeValue

var music_player = null

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	close_top_button.pressed.connect(_on_close_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	# Find music player - can be in MainMenu or scenario
	var root = get_tree().get_root()
	
	# Try MainMenu first
	var main_menu = root.get_node_or_null("MainMenu")
	if main_menu:
		music_player = main_menu.get_node_or_null("BackgroundMusic")
	
	# If not found, try scenario (which should be called "scenario")
	if music_player == null:
		var scenario = root.get_node_or_null("scenario")
		if scenario:
			music_player = scenario.get_node_or_null("Ambient sound")
	
	# Set initial volume
	if music_player:
		volume_slider.value = music_player.volume_db
		_update_volume_display(music_player.volume_db)

func _on_close_pressed() -> void:
	# Notify parent before closing
	var parent = get_parent()
	while parent:
		if parent.has_method("_on_popup_closed"):
			parent._on_popup_closed()
			break
		parent = parent.get_parent()
	queue_free()

func _on_volume_changed(value: float) -> void:
	_update_volume_display(value)
	
	# Update music volume
	if music_player:
		music_player.volume_db = value

func _update_volume_display(db_value: float) -> void:
	# Transform dB to visual scale centered at -15 dB = 0
	# -40 dB = -25, -15 dB = 0, 0 dB = +15
	var display_value = int(db_value + 15)
	
	if display_value > 0:
		volume_value.text = "+" + str(display_value)
	elif display_value == 0:
		volume_value.text = "0"
	else:
		volume_value.text = str(display_value)
