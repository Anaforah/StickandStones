extends Control

@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var volume_slider: HSlider = $Panel/VBoxContainer/ScrollContainer/ContentVBox/VolumeContainer/VolumeSlider
@onready var volume_value: Label = $Panel/VBoxContainer/ScrollContainer/ContentVBox/VolumeContainer/VolumeValue

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	# Set initial volume from main menu music
	var main_menu = get_tree().get_root().get_node("MainMenu")
	if main_menu:
		var music = main_menu.get_node("BackgroundMusic")
		if music:
			volume_slider.value = music.volume_db
			_update_volume_display(music.volume_db)

func _on_close_pressed() -> void:
	queue_free()

func _on_volume_changed(value: float) -> void:
	_update_volume_display(value)
	
	# Update music volume in main menu
	var main_menu = get_tree().get_root().get_node("MainMenu")
	if main_menu:
		var music = main_menu.get_node("BackgroundMusic")
		if music:
			music.volume_db = value

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
