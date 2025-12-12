extends Node2D

var target_position: Vector2 = Vector2.ZERO
var fall_speed := 300.0
var arrived := false
@onready var sprite := $Sprite2D

# textura de fogo (efeito)
var fire_texture := load("res://Imagens/Efeitos/Fire.png")

# Texturas possíveis e índice atual (serão atribuídos pelo spawner)
var object_textures: Array = []
var tex_index := 0

# Dragging
var dragging := false
var drag_offset := Vector2.ZERO
var prev_side_left := false

func _ready():
	# inicializa prev_side_left com base na posição inicial
	var screen_mid = get_viewport_rect().size.x / 2
	prev_side_left = global_position.x < screen_mid

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if sprite.get_rect().has_point(sprite.to_local(event.position)):
				dragging = true
				drag_offset = global_position - event.position
				# garante que prev_side_left reflete a posição real no momento do início do drag
				var screen_mid = get_viewport_rect().size.x / 2
				prev_side_left = global_position.x < screen_mid
		else:
			dragging = false

func _process(delta):
	if dragging:
		# Se pressionar 'use_item' (E) enquanto segura o item, transforma se for Extintor
		if Input.is_action_just_pressed("use_item"):
			if sprite.texture and sprite.texture.resource_path == "res://Imagens/Objetos/Extintor.png":
				sprite.texture = fire_texture
				# Opcional: desativa ciclamento de texturas para este item
				tex_index = -1
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset

		# Verifica se cruzou o meio da tela enquanto segurado
		var screen_mid = get_viewport_rect().size.x / 2
		var now_left = global_position.x < screen_mid
		if now_left != prev_side_left:
			# cruzou — troca textura para a próxima
			if object_textures.size() > 0:
				tex_index = (tex_index + 1) % object_textures.size()
				sprite.texture = object_textures[tex_index]
			prev_side_left = now_left

		return

	if not arrived and target_position:
		# Move apenas na vertical para garantir queda reta (x preservado)
		var vertical_target = Vector2(global_position.x, target_position.y)
		global_position = global_position.move_toward(vertical_target, fall_speed * delta)
		if abs(global_position.y - target_position.y) < 10:
			# Para no destino vertical e permanece (não é removido)
			global_position.y = target_position.y
			arrived = true
