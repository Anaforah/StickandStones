extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var settings_button: Button = $SettingsButton
var settings_popup_instance = null

func _ready() -> void:
	# Connect button presses.
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenario.tscn")

func _on_settings_pressed() -> void:
	# Only create popup if one doesn't exist
	if settings_popup_instance == null or not is_instance_valid(settings_popup_instance):
		settings_popup_instance = load("res://settings_popup.tscn").instantiate()
		add_child(settings_popup_instance)
		# Connect to know when popup is closed
		settings_popup_instance.tree_exited.connect(_on_popup_closed)

func _on_popup_closed() -> void:
	settings_popup_instance = null
