extends Node2D

@onready var sprite_left: Sprite2D = $rock
@onready var sprite_right: Sprite2D = $roleta
@onready var switch_sound: AudioStreamPlayer2D = $switch_sound

var dragging := false
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
	# Verificar teclas E e P apenas quando estiver a pressionar a roleta (dragging)
	if event is InputEventKey:
		if event.pressed and not event.echo and dragging:
			# Tecla E pressionada (lado esquerdo)
			if event.keycode == KEY_E:
				if sprite_right.visible:
					var screen_mid = get_viewport_rect().size.x / 2
					var roleta_x = sprite_right.global_position.x
					if roleta_x < screen_mid:
						_spawn_single_item()
			# Tecla P pressionada (lado direito)
			elif event.keycode == KEY_P:
				if sprite_right.visible:
					var screen_mid = get_viewport_rect().size.x / 2
					var roleta_x = sprite_right.global_position.x
					if roleta_x >= screen_mid:
						_spawn_single_item()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Verifica se iniciou drag
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
func _spawn_single_item():
	# Spawn permitidos em cliques consecutivos — permite múltiplos itens simultâneos

	if object_textures.size() == 0:
		print("⚠ Nenhuma textura em 'Imagens/Objetos' para spawnar.")
		return

	var screen_mid = get_viewport_rect().size.x / 2
	var roleta_x = sprite_right.global_position.x

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
	item.global_position = Vector2(sprite_right.global_position.x, spawn_y)

	# Define destino: mantém x da roleta (queda vertical) e y do "chão" (player)
	var target: Node2D = null
	if roleta_x < screen_mid and get_parent().has_node("player1"):
		target = get_parent().get_node("player1")
	elif roleta_x >= screen_mid and get_parent().has_node("player2"):
		target = get_parent().get_node("player2")

	if target:
		item.target_position = Vector2(sprite_right.global_position.x, target.global_position.y)
	else:
		item.target_position = Vector2(sprite_right.global_position.x, sprite_right.global_position.y + 300)

func _add_switch_points() -> void:
	# Adiciona pontos ao score global quando a roleta troca de lado
	var scene_root: Node = get_tree().get_current_scene()
	if not scene_root:
		return
	
	# Procurar qualquer ItemFall na cena para acessar o score global
	var item_fall = scene_root.find_child("ItemFall", true, false)
	if item_fall:
		# Adicionar pontos aleatórios
		var gain := randi_range(5, 20)
		item_fall.last_gain = gain
		item_fall.global_score += gain
		
		# Atualizar o label
		var score_label = scene_root.find_child("ScoreLabel", true, false)
		if score_label and score_label is Label:
			score_label.text = "Score: %d" % item_fall.global_score

func _add_interaction_points() -> void:
	# Adiciona pontos ao score global quando interage com a roleta via teclado (E ou P)
	var scene_root: Node = get_tree().get_current_scene()
	if not scene_root:
		return
	
	# Procurar qualquer ItemFall na cena para acessar o score global
	var item_fall = scene_root.find_child("ItemFall", true, false)
	if item_fall:
		# Adicionar pontos aleatórios
		var gain := randi_range(5, 20)
		item_fall.last_gain = gain
		item_fall.global_score += gain
		
		# Atualizar o label
		var score_label = scene_root.find_child("ScoreLabel", true, false)
		if score_label and score_label is Label:
			score_label.text = "Score: %d" % item_fall.global_score

	# target_position já definido abaixo
