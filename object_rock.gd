extends Node2D

@onready var sprite_left: Sprite2D = $rock
@onready var sprite_right: Sprite2D = $roleta
@onready var switch_sound: AudioStreamPlayer2D = $switch_sound

var switched := false
var side := ""

var achievement_sounds: Array[AudioStream] = []
var object_textures: Array[Texture2D] = []
var next_object_index := 0

# 🔥 PRELOAD DO ITEM QUE VAI CAIR
var item_scene: PackedScene = preload("res://ItemFall.tscn")

func _ready():
	# Carrega todos os sons da pasta achievement
	_load_achievement_sounds()
	_load_object_textures()
	
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

func _load_object_textures():
	var dir := DirAccess.open("res://Imagens/Objetos")
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".webp"):
				var tex := load("res://Imagens/Objetos/" + file_name)
				if tex:
					object_textures.append(tex)
		# garante que o índice comece em zero após carregar
		next_object_index = 0
	else:
		push_error("⚠ ERRO: Pasta res://Imagens/Objetos/ não encontrada!")

func _input(event):
	# Tecla R, SPACE ou T para spawnar item
	if event is InputEventKey and event.pressed and not event.echo:
		print("Tecla pressionada: ", event.keycode, " (R=82, SPACE=32, T=84)")
		# Múltiplas teclas para spawnar
		if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_T:
			print("🔥 SPAWNING ITEM!")
			_spawn_single_item()


func _process(_delta):
	# Verifica se a pedra cruzou para o outro lado
	if not switched:
		var screen_width = get_viewport_rect().size.x
		var current_sprite = sprite_left if sprite_left.visible else sprite_right
		var current_x = current_sprite.global_position.x
		
		# Se começou no lado esquerdo e cruzou para o direito
		if side == "left" and current_x >= screen_width / 2:
			_do_switch()
		# Se começou no lado direito e cruzou para o esquerdo
		elif side == "right" and current_x <= screen_width / 2:
			_do_switch()


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
	
	# 🎯 ADICIONAR PONTOS AO SCORE GLOBAL
	_add_switch_points()


# ------------------------------------------------------------
# 🔥 NOVA FUNÇÃO — CRIA O ITEM QUE CAI ATÉ O PERSONAGEM
# ------------------------------------------------------------
func _spawn_falling_item():
	var item = item_scene.instantiate()

	# 🔥 Atribuir textura aleatória ao item e ajustar escala para combinar com a roleta
	if object_textures.size() > 0 and item.has_node("Sprite2D"):
		var sprite = item.get_node("Sprite2D")
		var rand_idx = randi() % object_textures.size()
		sprite.texture = object_textures[rand_idx]

		# passa referências para o item controlar troca de texturas ao cruzar a tela
		item.object_textures = object_textures
		item.tex_index = rand_idx

		if sprite_right.texture and sprite.texture:
			var desired = sprite_right.texture.get_size() * sprite_right.scale
			var current = sprite.texture.get_size()
			if current.x > 0 and current.y > 0:
				var rx = desired.x / current.x
				var ry = desired.y / current.y
				var r = min(rx, ry)
				sprite.scale = Vector2(r, r)
		else:
			sprite.scale = sprite_right.scale
	else:
		print("⚠ Nenhuma textura encontrada ou o item não tem Sprite2D!")

	# Começa um pouco acima da roleta (mesma coluna X) — evita posições aleatórias
	var spawn_y = sprite_right.global_position.y - 300
	add_child(item)
	item.global_position = Vector2(sprite_right.global_position.x, spawn_y)

	# Descobrir qual player clicou
	var screen_mid = get_viewport_rect().size.x / 2
	var roleta_x = sprite_right.global_position.x

	var target: Node2D = null

	# Roleta do lado esquerdo → player1
	if roleta_x < screen_mid and get_parent().has_node("player1"):
		target = get_parent().get_node("player1")

	# Roleta do lado direito → player2
	elif roleta_x >= screen_mid and get_parent().has_node("player2"):
		target = get_parent().get_node("player2")

	# Se encontrou o player, define destino vertical (mesma x do spawn)
	if target:
		item.target_position = Vector2(sprite_right.global_position.x, target.global_position.y)
	else:
		# fallback
		item.target_position = Vector2(sprite_right.global_position.x, sprite_right.global_position.y + 300)

	# item já adicionado e posição global definida


# ------------------------------------------------------------
# 🔥 SPAWN ALL: cria um item para cada textura encontrada em Imagens/Objetos
# ------------------------------------------------------------
func _spawn_single_item(spawn_position: Vector2 = Vector2.ZERO):
	# Spawn permitidos em cliques consecutivos — permite múltiplos itens simultâneos

	if object_textures.size() == 0:
		print("⚠ Nenhuma textura em 'Imagens/Objetos' para spawnar.")
		return

	var screen_mid = get_viewport_rect().size.x / 2
	# Se não recebeu posição, usa a posição da sprite_right original
	var roleta_x = spawn_position.x if spawn_position != Vector2.ZERO else sprite_right.global_position.x

	# escolhe textura aleatória (totalmente random)
	var random_index = randi() % object_textures.size()
	var tex = object_textures[random_index]

	var item = item_scene.instantiate()

	# passa referências para o item controlar troca de texturas ao cruzar a tela
	item.object_textures = object_textures
	# armazena o índice aleatório
	item.tex_index = random_index

	# Adicionar pontos ao interagir com a roleta via teclado
	_add_interaction_points()

	# seta a textura no Sprite2D se existir e ajusta escala
	if item.has_node("Sprite2D"):
		var s = item.get_node("Sprite2D")
		s.texture = tex

		# Ajusta escala para ficar do tamanho da rocha/roleta mantendo aspecto
		if sprite_right.texture and s.texture:
			var desired = sprite_right.texture.get_size() * sprite_right.scale
			var current = s.texture.get_size()
			if current.x > 0 and current.y > 0:
				var rx = desired.x / current.x
				var ry = desired.y / current.y
				var r = min(rx, ry)
				s.scale = Vector2(r, r)
		else:
			# fallback: copiar escala do sprite_right se disponível
			s.scale = sprite_right.scale

	# posiciona no topo da tela, alinhado horizontalmente com a roleta (vem de cima)
	# posiciona um pouco acima da roleta (mesma coluna X) para garantir queda vertical
	var spawn_y = sprite_right.global_position.y - 300
	add_child(item)
	item.global_position = Vector2(roleta_x, spawn_y)
	
	# Descongelar para permitir queda
	item.freeze = false
	item.gravity_scale = 1.0

	# Define destino: mantém x da roleta (queda vertical) e y do "chão" (player)
	var target: Node2D = null
	if roleta_x < screen_mid and get_parent().has_node("player1"):
		target = get_parent().get_node("player1")
	elif roleta_x >= screen_mid and get_parent().has_node("player2"):
		target = get_parent().get_node("player2")

	if target:
		item.target_position = Vector2(roleta_x, target.global_position.y)
	else:
		item.target_position = Vector2(roleta_x, sprite_right.global_position.y + 300)

func _add_switch_points() -> void:
	# Placeholder para futuros pontos (ScoreLabel não existe na cena atual)
	pass

func _add_interaction_points() -> void:
	# Placeholder para futuros pontos (ScoreLabel não existe na cena atual)
	pass
