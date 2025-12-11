extends RigidBody2D

@onready var sprite_left: Sprite2D = $rock
@onready var sprite_right: Sprite2D = $roleta
@onready var switch_sound: AudioStreamPlayer2D = $switch_sound

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


# -----------------------------
# MÉTODOS PÚBLICOS PARA SER CHAMADOS PELO PLAYER
# -----------------------------

func do_switch():
	# Troca os sprites e toca som
	var current_pos = (sprite_left if sprite_left.visible else sprite_right).global_position

	sprite_left.visible = not sprite_left.visible
	sprite_right.visible = not sprite_right.visible

	if sprite_left.visible:
		sprite_left.global_position = current_pos
	else:
		sprite_right.global_position = current_pos

	switched = true

	# 🔊 toca som aleatório
	if achievement_sounds.size() > 0:
		var random_sound = achievement_sounds[randi() % achievement_sounds.size()]
		switch_sound.stream = random_sound
		switch_sound.play()


func move_to(new_pos: Vector2):
	global_position = new_pos


func set_visible_left(left_visible: bool):
	sprite_left.visible = left_visible
	sprite_right.visible = not left_visible
