extends Node2D

@onready var sprite_left: Sprite2D = $rock
@onready var sprite_right: Sprite2D = $roleta
@onready var switch_sound: AudioStreamPlayer2D = $switch_sound

var dragging := false
var switched := false
var side := ""

var achievement_sounds: Array[AudioStream] = []


func _ready():
	# Carrega todos os sons da pasta achievement
	_load_achievement_sounds()
	
	# Detecta automaticamente o lado inicial do sprite_left
	var screen_width = get_viewport_rect().size.x
	if sprite_left.global_position.x < screen_width / 2:
		side = "left"
	else:
		side = "right"
	
	sprite_left.visible = true
	sprite_right.visible = false


func _load_achievement_sounds():
	var dir := DirAccess.open("res://Sons/Achievement")
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
				var sound: AudioStream = load("res://Sons/Achievement/" + file_name)
				if sound:
					achievement_sounds.append(sound)
	else:
		push_error("⚠ ERRO: Pasta res://Sons/Achievement/ não encontrada!")


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if (sprite_left.visible and sprite_left.get_rect().has_point(sprite_left.to_local(event.position))) \
			or (sprite_right.visible and sprite_right.get_rect().has_point(sprite_right.to_local(event.position))):
				dragging = true
		else:
			dragging = false


func _process(_delta):
	if dragging:
		var mouse_pos = get_global_mouse_position()
		
		if not switched:
			# Movimento normal antes da troca
			if sprite_left.visible:
				sprite_left.global_position = mouse_pos
			else:
				sprite_right.global_position = mouse_pos
			
			_check_switch(mouse_pos)
		else:
			# Depois da troca: bloquear movimento do outro lado
			var screen_width = get_viewport_rect().size.x

			if side == "left":
				mouse_pos.x = max(screen_width / 2, mouse_pos.x)
			else:
				mouse_pos.x = min(screen_width / 2, mouse_pos.x)

			if sprite_right.visible:
				sprite_right.global_position = mouse_pos
			else:
				sprite_left.global_position = mouse_pos


func _check_switch(mouse_pos: Vector2) -> void:
	var screen_width = get_viewport_rect().size.x

	if switched:
		return  # nunca troca duas vezes

	if sprite_left.visible:
		if side == "left" and mouse_pos.x >= screen_width / 2:
			_do_switch()
		elif side == "right" and mouse_pos.x <= screen_width / 2:
			_do_switch()


func _do_switch() -> void:
	var current_pos = (sprite_left if sprite_left.visible else sprite_right).global_position

	sprite_left.visible = not sprite_left.visible
	sprite_right.visible = not sprite_right.visible

	if sprite_left.visible:
		sprite_left.global_position = current_pos
	else:
		sprite_right.global_position = current_pos

	switched = true

	# 🔊 SOM RANDOM
	if achievement_sounds.size() > 0:
		var random_sound = achievement_sounds[randi() % achievement_sounds.size()]
		switch_sound.stream = random_sound
		switch_sound.play()
