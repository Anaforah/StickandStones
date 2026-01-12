extends CanvasLayer

signal permission_granted
signal permission_denied

@onready var allow_button: Button = $Control/Panel/VBoxContainer/ButtonContainer/AllowButton
@onready var deny_button: Button = $Control/Panel/VBoxContainer/ButtonContainer/DenyButton

func _ready() -> void:
	allow_button.pressed.connect(_on_allow_pressed)
	deny_button.pressed.connect(_on_deny_pressed)

func _on_allow_pressed() -> void:
	permission_granted.emit()
	queue_free()

func _on_deny_pressed() -> void:
	permission_denied.emit()
	queue_free()
