extends Node2D

@onready var sprite_left: Sprite2D = $rock
@onready var sprite_right: Sprite2D = $roleta

var dragging := false
var switched := false  # controla se a troca já aconteceu
var side := ""        # lado inicial do sprite: "left" ou "right"

func _ready():
	# Detecta automaticamente em qual lado o sprite_left está
	var screen_width = get_viewport_rect().size.x
	if sprite_left.global_position.x < screen_width / 2:
		side = "left"
	else:
		side = "right"
	
	sprite_left.visible = true
	sprite_right.visible = false

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if (sprite_left.visible and sprite_left.get_rect().has_point(sprite_left.to_local(event.position))) \
			or (sprite_right.visible and sprite_right.get_rect().has_point(sprite_right.to_local(event.position))):
				dragging = true
		else:
			dragging = false

func _process(delta):
	if dragging:
		var mouse_pos = get_global_mouse_position()
		
		if not switched:
			# Arrasta o sprite visível normalmente
			sprite_left.global_position = mouse_pos if sprite_left.visible else sprite_right.global_position
			_check_switch(mouse_pos)
		else:
			# Depois de trocar, limita o movimento ao lado correspondente
			var screen_width = get_viewport_rect().size.x
			if side == "left":
				# Sprite inicial à esquerda: depois de troca, travado no lado direito
				mouse_pos.x = max(screen_width / 2, mouse_pos.x)
			else:
				# Sprite inicial à direita: depois de troca, travado no lado esquerdo
				mouse_pos.x = min(screen_width / 2, mouse_pos.x)
			
			if sprite_right.visible:
				sprite_right.global_position = mouse_pos
			else:
				sprite_left.global_position = mouse_pos

func _check_switch(mouse_pos: Vector2) -> void:
	var screen_width = get_viewport_rect().size.x

	if sprite_left.visible:
		if side == "left" and mouse_pos.x >= screen_width / 2:
			_do_switch()
		elif side == "right" and mouse_pos.x <= screen_width / 2:
			_do_switch()

func _do_switch() -> void:
	var current_pos = (sprite_left if sprite_left.visible else sprite_right).global_position
	
	sprite_left.visible = not sprite_left.visible
	sprite_right.visible = not sprite_right.visible
	
	# Mantém posição do novo sprite
	if sprite_left.visible:
		sprite_left.global_position = current_pos
	else:
		sprite_right.global_position = current_pos
	
	switched = true
