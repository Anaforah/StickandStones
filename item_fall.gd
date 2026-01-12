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

# Cenários disponíveis e índice atual
var cenario_textures: Array[Texture2D] = []
var current_cenario_index := 0

# Sons de objetos
var object_sounds: Array[AudioStream] = []
# Sons de achievement
var achievement_sounds: Array[AudioStream] = []
var audio_player: AudioStreamPlayer2D = null
var prev_p_pressed := false

# Dragging
var dragging := false
var drag_offset := Vector2.ZERO
var prev_side_left := false
var is_hole := false  # Flag para indicar se o objeto é um buraco (não interativo)

# Score global
static var global_score: int = 0
static var last_gain: int = 0

func _ready():
	# Carregar todos os cenários disponíveis
	cenario_textures.append(load("res://Imagens/cenarios/cenario1.png"))
	cenario_textures.append(load("res://Imagens/cenarios/cenario2.png"))
	
	# Carregar todos os sons de objetos
	_load_object_sounds()
	
	# Carregar todos os sons de achievement
	_load_achievement_sounds()
	
	# Criar AudioStreamPlayer2D para tocar sons
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# inicializa prev_side_left com base na posição inicial
	var screen_mid = get_viewport_rect().size.x / 2
	prev_side_left = global_position.x < screen_mid

func _load_object_sounds():
	var dir := DirAccess.open("res://Sons/Objetos")
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
				var sound: AudioStream = load("res://Sons/Objetos/" + file_name)
				if sound:
					object_sounds.append(sound)
	else:
		push_error("⚠ ERRO: Pasta res://Sons/Objetos/ não encontrada!")

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
	# Se é um buraco, não permite interação
	if is_hole:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Apenas começar a arrastar se o clique foi diretamente neste sprite
			# (agora permite em ambos os lados; lógica de interação continua separada E/P)
			var screen_mid = get_viewport_rect().size.x / 2
			if sprite.get_rect().has_point(sprite.to_local(event.position)):
				# Procurar todos os items caídos na cena que estão sob o mouse
				var all_items = get_parent().get_children()
				var items_under_mouse = []
				
				for item in all_items:
					if item is Node2D and item.has_node("Sprite2D"):
						var item_sprite = item.get_node("Sprite2D")
						if item_sprite.get_rect().has_point(item_sprite.to_local(event.position)):
							items_under_mouse.append(item)
				
				# Se há múltiplos items, pegar o que está por cima (índice maior na árvore)
				var selected_item = self
				if items_under_mouse.size() > 0:
					# Ordenar por índice na árvore (último = por cima)
					items_under_mouse.sort_custom(func(a, b): return a.get_index() < b.get_index())
					selected_item = items_under_mouse[-1]  # Pegar o último (mais acima)
				
				# Apenas este item pode ser arrastado
				if selected_item == self:
					dragging = true
					drag_offset = global_position - event.position
					# garante que prev_side_left reflete a posição real no momento do início do drag
					prev_side_left = global_position.x < screen_mid
		else:
			dragging = false

func _process(delta):
	if dragging:
		# Estado da tecla P (lado direito)
		var p_down = Input.is_key_pressed(KEY_P)
		var p_just_pressed = p_down and not prev_p_pressed
		prev_p_pressed = p_down

		# Se pressionar 'use_item' (E) no lado esquerdo ou 'P' no lado direito
		# Usa o lado armazenado (prev_side_left) para evitar erro quando perto do meio
		var screen_mid = get_viewport_rect().size.x / 2
		var now_left = global_position.x < screen_mid
		var is_left = prev_side_left
		var should_interact = (is_left and Input.is_action_just_pressed("use_item")) or (not is_left and p_just_pressed)

		if should_interact:
			if sprite.texture:
				var path: String = sprite.texture.resource_path
				# Extintor -> fogo
				if path == "res://Imagens/Objetos/Extintor.png":
					sprite.texture = fire_texture
					tex_index = -1
					# Tocar som aleatório
					_play_random_object_sound()
					# Multiplicar fogo no mesmo lado da tela
					_multiply_fire_on_side()
					# Adicionar pontos
					_add_interaction_points()
				# Comando -> troca cenário de cenario1 para cenario2
				elif path == "res://Imagens/Objetos/comando.png":
					# Procura o Sprite2D chamado "Scenario" dentro da cena atual
					var scene_root: Node = get_tree().get_current_scene()
					var scenario_node: Node = null
					if scene_root:
						# Godot 4: usar find_child(nome, recursive=true, owned=true)
						scenario_node = scene_root.find_child("Scenario", true, false)
					if scenario_node and scenario_node is Sprite2D:
						var scenario_sprite: Sprite2D = scenario_node as Sprite2D
						# Ciclar para o próximo cenário
						current_cenario_index = (current_cenario_index + 1) % cenario_textures.size()
						scenario_sprite.texture = cenario_textures[current_cenario_index]
						# Tocar som aleatório
						_play_random_object_sound()
					# Adicionar pontos
					_add_interaction_points()
				# Pa -> cria buraco e suga objetos para o outro lado
				elif path == "res://Imagens/Objetos/Pa.png":
					_create_hole_and_suck_objects()
					# Tocar som aleatório
					_play_random_object_sound()
					# Adicionar pontos
					_add_interaction_points()
				# Aspirador -> remove objetos próximos
				elif path == "res://Imagens/Objetos/aspirador.png":
					_remove_nearby_objects()
					# Tocar som aleatório
					_play_random_object_sound()
					# Adicionar pontos
					_add_interaction_points()
				# Camara -> mostra popup de permissão e tira foto
				elif path == "res://Imagens/Objetos/camara.png":
					_handle_camera_interaction()
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset

		# Verifica se cruzou o meio da tela enquanto segurado
		if now_left != prev_side_left:
			# cruzou — troca textura para a próxima
			if object_textures.size() > 0:
				tex_index = (tex_index + 1) % object_textures.size()
				sprite.texture = object_textures[tex_index]
			# Tocar som de achievement
			_play_random_achievement_sound()
			_award_switch_points(now_left)
			prev_side_left = now_left

		return

	# reset do estado de P quando não está a arrastar
	prev_p_pressed = false
	
	# Se este objeto é um buraco, verificar colisões com outros objetos
	if is_hole:
		_check_hole_collisions()

	if not arrived and target_position:
		# Move apenas na vertical para garantir queda reta (x preservado)
		var vertical_target = Vector2(global_position.x, target_position.y)
		global_position = global_position.move_toward(vertical_target, fall_speed * delta)
		if abs(global_position.y - target_position.y) < 10:
			# Para no destino vertical e permanece (não é removido)
			global_position.y = target_position.y
			arrived = true
	
	# Verificar colisão com fogo se for fogo
	if sprite.texture:
		var texture_path = sprite.texture.resource_path
		if texture_path.contains("Fire.png"):
			# Executar a verificação de colisão de forma assíncrona
			_check_fire_collision_with_players_async()

func _play_random_object_sound():
	if object_sounds.size() > 0 and audio_player:
		var random_idx = randi() % object_sounds.size()
		audio_player.stream = object_sounds[random_idx]
		audio_player.play()

func _play_random_achievement_sound():
	if achievement_sounds.size() > 0 and audio_player:
		var random_idx = randi() % achievement_sounds.size()
		audio_player.stream = achievement_sounds[random_idx]
		audio_player.play()

func _award_switch_points(_is_left: bool) -> void:
	# Adiciona pontos globais quando há troca de objetos
	var gain := randi_range(5, 20)
	last_gain = gain
	global_score += gain
	_update_global_score_label()

func _add_interaction_points() -> void:
	# Adiciona pontos globais quando interage com objetos (E ou P)
	var gain := randi_range(5, 20)
	last_gain = gain
	global_score += gain
	_update_global_score_label()

func _update_global_score_label() -> void:
	# Atualiza o label de score global
	var scene_root: Node = get_tree().get_current_scene()
	if not scene_root:
		return
	var score_label = scene_root.find_child("ScoreLabel", true, false)
	if score_label and score_label is Label:
		score_label.text = "Score: %d" % global_score
		# Animar o score com pulse
		_animate_score_pulse(score_label)
		# Mostrar floating text com o ganho
		_show_point_gain_floating(last_gain)

func _animate_score_pulse(label: Label) -> void:
	# Anima o score com um scale pulse
	var original_scale = label.scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	await tween.finished
	tween = create_tween()
	tween.tween_property(label, "scale", original_scale, 0.15)

func _show_point_gain_floating(points: int) -> void:
	# Cria um label flutuante mostrando os pontos ganhos
	var scene_root: Node = get_tree().get_current_scene()
	if not scene_root:
		return
	
	# Criar canvas layer para floating text
	var floating_container = CanvasLayer.new()
	scene_root.add_child(floating_container)
	
	# Criar label flutuante
	var floating_label = Label.new()
	floating_label.text = "+%d" % points
	floating_label.add_theme_font_size_override("font_size", 40)
	floating_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	floating_label.position = Vector2(960, 50)  # Centralizado no topo
	floating_label.anchor_left = 0.5
	floating_label.anchor_top = 0.0
	floating_label.offset_left = -30
	
	# Add outline/shadow para melhor visibilidade
	var label_settings = LabelSettings.new()
	label_settings.outline_size = 3
	label_settings.outline_color = Color(0, 0, 0, 1)
	floating_label.label_settings = label_settings
	
	floating_container.add_child(floating_label)
	
	# Animar: subir e desaparecer
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(floating_label, "position:y", floating_label.position.y - 80, 1.0)
	tween.tween_property(floating_label, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	floating_container.queue_free()

func _create_hole_and_suck_objects():
	# Transformar a Pá em buraco
	var buraco_texture = load("res://Imagens/buraco.png")
	if buraco_texture:
		sprite.texture = buraco_texture
		# Aumentar o tamanho do buraco (1.2x maior)
		sprite.scale = Vector2(1.2, 1.2)
		
		# Ajustar o collision shape para corresponder ao tamanho do buraco
		if has_node("CollisionShape2D"):
			var collision = get_node("CollisionShape2D")
			if collision.shape is CircleShape2D:
				# Raio como círculo circunscrito ao retângulo da textura (cobre toda a imagem)
				var tex_sz = buraco_texture.get_size()
				var scaled_w = float(tex_sz.x) * sprite.scale.x
				var scaled_h = float(tex_sz.y) * sprite.scale.y
				collision.shape.radius = 0.5 * sqrt(scaled_w * scaled_w + scaled_h * scaled_h)
			elif collision.shape is RectangleShape2D:
				# Ajustar tamanho do retângulo ao tamanho visível da textura (já com scale)
				var tex_sz_r = buraco_texture.get_size()
				collision.shape.size = Vector2(float(tex_sz_r.x) * sprite.scale.x, float(tex_sz_r.y) * sprite.scale.y)
		
		tex_index = -1
		# Marcar como buraco (não interativo)
		is_hole = true
		# Parar de arrastar imediatamente
		dragging = false
	
	# Posição do buraco
	var hole_pos = global_position
	var screen_mid = get_viewport_rect().size.x / 2
	var hole_is_left = hole_pos.x < screen_mid
	
	# Procurar todos os objetos na cena
	var all_items = get_parent().get_children()
	
	for item in all_items:
		if item == self or not item is Node2D:
			continue
		
		if not item.has_node("Sprite2D"):
			continue
		
		# Verificar se o objeto está "por cima" do buraco (mesma região)
		var item_pos = item.global_position
		var distance = hole_pos.distance_to(item_pos)
		
		# Se estiver próximo do buraco (raio de sucção ~150 pixels)
		if distance < 150:
			# Mover para o outro lado do ecrã
			var target_x: float
			if hole_is_left:
				# Buraco à esquerda -> sugar para direita
				target_x = screen_mid + (screen_mid - hole_pos.x)
			else:
				# Buraco à direita -> sugar para esquerda
				target_x = screen_mid - (hole_pos.x - screen_mid)
			
			# Aplicar nova posição ao objeto
			item.global_position.x = target_x
			
			# Se tiver a variável prev_side_left, atualizar para refletir novo lado
			if "prev_side_left" in item:
				item.prev_side_left = target_x < screen_mid

func _check_hole_collisions():
	# Verifica se objetos tocam este buraco e os teleporta usando collision shape
	if not is_hole:
		return
	
	# Obter o collision shape do buraco
	var hole_collision: CollisionShape2D = null
	if has_node("CollisionShape2D"):
		hole_collision = get_node("CollisionShape2D")
	
	if not hole_collision or not hole_collision.shape:
		# Se não houver collision shape configurado, tentar calcular pela textura
		var fallback_sprite: Sprite2D = null
		if has_node("Sprite2D"):
			fallback_sprite = get_node("Sprite2D")
		if fallback_sprite and fallback_sprite.texture:
			var tex_sz_fb = fallback_sprite.texture.get_size()
			var hole_radius_fb = max(float(tex_sz_fb.x) * fallback_sprite.scale.x, float(tex_sz_fb.y) * fallback_sprite.scale.y) * 0.5
			# Continuar usando este raio de fallback
			# Código abaixo usa hole_radius calculado
		else:
			return
	
	var hole_pos = global_position
	var screen_mid = get_viewport_rect().size.x / 2
	
	# Obter o raio do collision shape do buraco
	var hole_radius = 0.0
	if hole_collision and hole_collision.shape is CircleShape2D:
		# Raio já corresponde ao círculo circunscrito (ajustado em _create_hole_and_suck_objects)
		hole_radius = hole_collision.shape.radius
	elif hole_collision and hole_collision.shape is RectangleShape2D:
		# Usar raio do círculo circunscrito ao retângulo configurado
		var size_rect = hole_collision.shape.size
		hole_radius = 0.5 * sqrt(size_rect.x * size_rect.x + size_rect.y * size_rect.y)
	else:
		# Fallback para textura se acima não disponível
		var sprite_node2: Sprite2D = null
		if has_node("Sprite2D"):
			sprite_node2 = get_node("Sprite2D")
		if sprite_node2 and sprite_node2.texture:
			var tex_sz2 = sprite_node2.texture.get_size()
			var scaled_w2 = float(tex_sz2.x) * sprite_node2.scale.x
			var scaled_h2 = float(tex_sz2.y) * sprite_node2.scale.y
			hole_radius = 0.5 * sqrt(scaled_w2 * scaled_w2 + scaled_h2 * scaled_h2)
		else:
			return
	
	var all_items = get_parent().get_children()
	
	for item in all_items:
		if item == self or not item is Node2D:
			continue
		
		if not item.has_node("Sprite2D"):
			continue
		
		# Verificar se é outro buraco
		if "is_hole" in item and item.is_hole:
			continue
		
		# Obter collision shape do objeto
		var item_collision: CollisionShape2D = null
		if item.has_node("CollisionShape2D"):
			item_collision = item.get_node("CollisionShape2D")
		
		var item_pos = item.global_position
		var distance = hole_pos.distance_to(item_pos)
		
		# Raio do objeto
		var item_radius = 0.0
		if item_collision and item_collision.shape is CircleShape2D:
			item_radius = item_collision.shape.radius
			# Multiplicar pelo scale do sprite do item
			if item.has_node("Sprite2D"):
				var item_sprite = item.get_node("Sprite2D")
				item_radius *= max(item_sprite.scale.x, item_sprite.scale.y)
		else:
			item_radius = 30.0  # Raio padrão se não tiver collision shape
		
		# Verificar colisão: distância entre centros < soma dos raios
		var collision_distance = hole_radius + item_radius
		if distance < collision_distance:
			print("TELEPORTING object! Distance: ", distance, " Collision distance: ", collision_distance)
			# Teleportar para o outro lado do ecrã
			var screen_width = get_viewport_rect().size.x
			var target_x: float
			
			# Calcular posição espelhada
			target_x = screen_width - hole_pos.x
			
			# Aplicar nova posição ao objeto
			item.global_position.x = target_x
			
			# Se tiver a variável prev_side_left, atualizar
			if "prev_side_left" in item:
				item.prev_side_left = target_x < screen_mid
			
			# Tocar som de achievement
			if achievement_sounds.size() > 0 and audio_player:
				var random_idx = randi() % achievement_sounds.size()
				audio_player.stream = achievement_sounds[random_idx]
				audio_player.play()

func _multiply_fire_on_side():
	# Determina o lado da tela onde o fogo foi criado
	var screen_mid = get_viewport_rect().size.x / 2
	var is_left_side = global_position.x < screen_mid
	
	# Número de fogos adicionais a criar (3-5 fogos)
	var num_fires = randi_range(3, 5)
	
	# Carrega a cena ItemFall para criar instâncias próprias
	var item_scene = load("res://ItemFall.tscn")
	
	# Cria múltiplos fogos espalhados no mesmo lado da tela
	for i in range(num_fires):
		# Instancia um novo item
		var fire_item = item_scene.instantiate()
		
		# Adiciona à cena primeiro para que os nodes filhos estejam disponíveis
		get_parent().add_child(fire_item)
		
		# Configura o sprite do fogo
		if fire_item.has_node("Sprite2D"):
			var fire_sprite = fire_item.get_node("Sprite2D")
			fire_sprite.texture = fire_texture
			fire_sprite.scale = sprite.scale
			
			# Define tex_index como -1 para que não mude de textura
			fire_item.tex_index = -1
			
			# Marca como "arrived" para que não caia
			fire_item.arrived = true
		
		# Posicionar o fogo aleatoriamente no mesmo lado da tela
		var screen_width = get_viewport_rect().size.x
		var screen_height = get_viewport_rect().size.y
		
		var fire_x: float
		if is_left_side:
			# Lado esquerdo: entre 50 e meio da tela - 50
			fire_x = randf_range(50, screen_mid - 50)
		else:
			# Lado direito: entre meio da tela + 50 e largura - 50
			fire_x = randf_range(screen_mid + 50, screen_width - 50)
		
		# Posição Y aleatória na metade inferior da tela
		var fire_y = randf_range(screen_height * 0.4, screen_height - 100)
		
		fire_item.global_position = Vector2(fire_x, fire_y)
		
		# Animação de aparecimento
		if fire_item.has_node("Sprite2D"):
			var fire_sprite = fire_item.get_node("Sprite2D")
			fire_sprite.modulate.a = 0.0  # Começa invisível
			var tween = create_tween()
			tween.tween_property(fire_sprite, "modulate:a", 1.0, 0.5).set_delay(i * 0.15)

func _check_fire_collision_with_players_async() -> void:
	# Executar a verificação de forma assíncrona
	_check_fire_collision_with_players()

func _check_fire_collision_with_players() -> void:
	# Verificar se o fogo está tocando player1 ou player2
	var scene_root = get_tree().get_current_scene()
	
	# Procurar players diretamente usando find_child
	var player1 = scene_root.find_child("Player 1", true, false)
	var player2 = scene_root.find_child("Player 2", true, false)
	
	# Debug: mostrar o que encontrou
	if player1:
		var p1_state = "visible: %s, in_tree: %s, has_exploding: %s" % [player1.visible, player1.is_inside_tree(), player1.has_meta("exploding")]
		print("🔍 Player 1 encontrado - %s" % p1_state)
	else:
		print("🔍 Player 1 NÃO encontrado")
	
	if player2:
		var p2_state = "visible: %s, in_tree: %s, has_exploding: %s" % [player2.visible, player2.is_inside_tree(), player2.has_meta("exploding")]
		print("🔍 Player 2 encontrado - %s" % p2_state)
	else:
		print("🔍 Player 2 NÃO encontrado")
	
	# Garantir que os players estão visíveis (elimina players antigos)
	if player1 and not player1.visible:
		player1 = null
	if player2 and not player2.visible:
		player2 = null
	
	var closest_player = null
	var closest_distance = 999999.0
	
	# Verificar player1
	if player1:
		var distance = _calculate_distance_to_player(player1)
		if distance < closest_distance and not player1.has_meta("exploding"):
			closest_distance = distance
			closest_player = player1
	
	# Verificar player2
	if player2:
		var distance = _calculate_distance_to_player(player2)
		if distance < closest_distance and not player2.has_meta("exploding"):
			closest_distance = distance
			closest_player = player2
	
	# Aplicar explosão se estiver perto (ajustado para escala 3x da cena)
	if closest_player and closest_distance <= 300.0:
		if not closest_player.has_meta("exploding"):
			await _apply_explosion_to_player(closest_player)
		else:
			print("⏭ ", closest_player.name, " já tem meta exploding ativa")

func _calculate_distance_to_player(player: Node2D) -> float:
	# Distância simples entre fogo e player
	var fire_pos = global_position
	var player_pos = player.global_position
	if player.has_node("Sprite2D"):
		player_pos = player.get_node("Sprite2D").global_position
	return fire_pos.distance_to(player_pos)

func _apply_explosion_to_player(player: Node2D):
	# Verificar se o player já está explodindo (evitar duplicações)
	if player.has_meta("exploding"):
		print("⚠ Player já está explodindo, ignorando nova explosão")
		return
	
	# Marcar o player como explodindo
	player.set_meta("exploding", true)
	print("💥 Iniciando explosão para: ", player.name)

	# Bonus de pontos ao explodir: duplica o último ganho aleatório
	if last_gain > 0:
		global_score += last_gain
		_update_global_score_label()
	
	# Encontrar o sprite do player
	if not player.has_node("Sprite2D"):
		# Player pode não ter Sprite2D, ignorar
		return

	var player_sprite = player.get_node("Sprite2D")

	# Guardar TODAS as informações necessárias do player ANTES de modificá-lo
	var original_texture = player_sprite.texture
	var original_sprite_pos = player_sprite.position
	var original_sprite_scale = player_sprite.scale
	var original_sprite_flip_h = false
	if player_sprite is Sprite2D:
		original_sprite_flip_h = (player_sprite as Sprite2D).flip_h

	var collision_data: Dictionary = {}
	if player.has_node("CollisionShape2D"):
		var coll = player.get_node("CollisionShape2D")
		collision_data["position"] = coll.position
		if coll.shape is RectangleShape2D:
			collision_data["type"] = "rect"
			collision_data["size"] = coll.shape.size
		elif coll.shape is CircleShape2D:
			collision_data["type"] = "circle"
			collision_data["radius"] = coll.shape.radius

	var player_parent = player.get_parent()
	var player_name = player.name
	var player_global_pos = player.global_position  # Posição do CharacterBody2D
	var player_sprite_global_pos = player_sprite.global_position  # Para a explosão
	var player_scale = player_sprite.scale
	
	# Tocar som aleatório da pasta Sons/Personagem
	_play_random_character_sound(player_global_pos)
	
	# Criar um novo AnimatedSprite2D para a explosão
	var animated_explosion = AnimatedSprite2D.new()
	
	# Criar SpriteFrames para a animação
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("explosion")
	
	# Carregar todos os frames extraídos do GIF
	var frames_loaded = 0
	for i in range(1, 18):  # 17 frames extraídos
		var frame_path = "res://Imagens/Efeitos/frame_%03d.png" % i
		var frame_texture = load(frame_path)
		if frame_texture:
			sprite_frames.add_frame("explosion", frame_texture)
			frames_loaded += 1
		else:
			print("⚠ Não conseguiu carregar frame: ", frame_path)
	
	print("✓ Carregados ", frames_loaded, " frames de explosão")
	
	if frames_loaded == 0:
		print("⚠ Nenhum frame de explosão carregado! Usando Fire.png como fallback")
		var fallback_texture = load("res://Imagens/Efeitos/Fire.png")
		if fallback_texture:
			sprite_frames.add_frame("explosion", fallback_texture)
		else:
			print("⚠ Fallback Fire.png não carregado; prosseguindo sem animação adicional")
	
	# Configurar animação
	sprite_frames.set_animation_speed("explosion", 12)  # 12 FPS para terminar mais rápido
	sprite_frames.set_animation_loop("explosion", false)  # Reproduzir apenas 1 vez
	
	# Configurar AnimatedSprite2D
	animated_explosion.sprite_frames = sprite_frames
	animated_explosion.animation = "explosion"
	animated_explosion.scale = player_scale * 10.5  # Aumentado 2.5x o tamanho
	animated_explosion.global_position = player_sprite_global_pos  # Posição do sprite para visual
	
	# Adicionar explosão diretamente à cena (não ao player)
	player_parent.add_child(animated_explosion)
	
	# Esconder o player imediatamente
	player.visible = false
	
	# Parar movimento do player
	player.velocity = Vector2.ZERO
	
	# Começar a animação
	animated_explosion.play()
	print("▶ Iniciando animação de explosão com ", frames_loaded, " frames")
	
	# Aguardar o sinal de animação terminada com timeout de segurança
	var animation_signal = animated_explosion.animation_finished
	var timeout_timer = get_tree().create_timer(3.0)
	
	# Aguardar animação OU timeout, o que vier primeiro
	var animation_complete = false
	var timeout_reached = false
	
	var on_animation_finished = func():
		animation_complete = true
	
	animation_signal.connect(on_animation_finished)
	
	while not animation_complete and not timeout_reached:
		await get_tree().process_frame
		if timeout_timer.time_left <= 0:
			print("⏱ Timeout na animação de explosão")
			timeout_reached = true
	
	print("✓ Animação de explosão terminada ou timeout")

	# Manter efeito visível por 1s, depois limpar tudo e respawnar
	await get_tree().create_timer(1.0).timeout

	# Limpar tudo
	_remove_all_fires()
	_remove_all_explosions()
	_remove_all_items_except_roleta()
	
	# Remover a explosão
	if is_instance_valid(animated_explosion):
		animated_explosion.queue_free()
	
	# Remover o player antigo
	if is_instance_valid(player):
		player.remove_meta("exploding")  # Remover ANTES de destruir
		player.queue_free()
	
	# Criar novo player DIRETAMENTE
	var new_player = CharacterBody2D.new()
	new_player.name = player_name
	
	# Garantir que não tem meta exploding
	if new_player.has_meta("exploding"):
		new_player.remove_meta("exploding")
	
	# Adicionar Sprite2D
	var new_sprite = Sprite2D.new()
	new_sprite.texture = original_texture
	new_sprite.name = "Sprite2D"
	new_sprite.position = original_sprite_pos
	new_sprite.scale = original_sprite_scale
	new_sprite.flip_h = original_sprite_flip_h
	new_player.add_child(new_sprite)
	
	# Adicionar CollisionShape2D
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	if collision_data.has("type") and collision_data["type"] == "circle":
		var shape_c = CircleShape2D.new()
		shape_c.radius = collision_data.get("radius", 30.0)
		collision.shape = shape_c
	elif collision_data.has("type") and collision_data["type"] == "rect":
		var shape_r = RectangleShape2D.new()
		shape_r.size = collision_data.get("size", Vector2(50, 100))
		collision.shape = shape_r
	else:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(50, 100)
		collision.shape = shape
	
	if collision_data.has("position"):
		collision.position = collision_data["position"]
	new_player.add_child(collision)
	
	# Adicionar script do player
	if player_name == "Player 1":
		new_player.set_script(load("res://player_1.gd"))
	elif player_name == "Player 2":
		new_player.set_script(load("res://player_2.gd"))
	
	# Posicionar no topo para cair - usar coordenadas locais do parent
	print("🔍 Player parent: ", player_parent.name if is_instance_valid(player_parent) else "none")
	
	# Posição local no AnimationPlayer (já considerando escala da cena)
	new_player.position = Vector2(-1.75, -300)
	new_player.velocity = Vector2.ZERO
	new_player.visible = true
	# Garantir que não tem meta exploding
	if new_player.has_meta("exploding"):
		new_player.remove_meta("exploding")
	print("🔍 new_player.position (local): ", new_player.position)
	
	# Adicionar à cena
	var target_parent = player_parent if is_instance_valid(player_parent) else get_tree().get_current_scene()
	if is_instance_valid(target_parent):
		target_parent.add_child(new_player)
		await get_tree().process_frame
		print("✅ Novo player ", player_name, " adicionado à cena e processado")
	else:
		print("⚠ Não foi possível encontrar parent para respawn")

func _spawn_new_player_at_top(parent: Node, player_name: String, original_texture: Texture2D, position_x: float, sprite_pos: Vector2, sprite_scale: Vector2, sprite_flip_h: bool, collision_data: Dictionary) -> void:
	# Esperar um frame para garantir que o antigo player foi removido da árvore
	await get_tree().process_frame
	
	print("🔄 Criando novo player: ", player_name)
	
	# Criar novo CharacterBody2D
	var new_player = CharacterBody2D.new()
	new_player.name = player_name
	
	# Adicionar Sprite2D
	var new_sprite = Sprite2D.new()
	new_sprite.texture = original_texture
	new_sprite.name = "Sprite2D"
	new_sprite.position = sprite_pos
	new_sprite.scale = sprite_scale
	new_sprite.flip_h = sprite_flip_h
	new_player.add_child(new_sprite)
	
	# Adicionar CollisionShape2D (cópia da forma original)
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	if collision_data.has("type") and collision_data["type"] == "circle":
		var shape_c = CircleShape2D.new()
		shape_c.radius = collision_data.get("radius", 30.0)
		collision.shape = shape_c
	elif collision_data.has("type") and collision_data["type"] == "rect":
		var shape_r = RectangleShape2D.new()
		shape_r.size = collision_data.get("size", Vector2(50, 100))
		collision.shape = shape_r
	else:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(50, 100)
		collision.shape = shape

	if collision_data.has("position"):
		collision.position = collision_data["position"]
	new_player.add_child(collision)
	
	# Adicionar script do player
	if player_name == "Player 1":
		new_player.set_script(load("res://player_1.gd"))
	elif player_name == "Player 2":
		new_player.set_script(load("res://player_2.gd"))

	# Posicionar bem acima da tela (fora da visão) para cair naturalmente
	# O player cairá devido à física/gravidade do seu script
	var viewport_size = get_viewport_rect().size
	var clamped_x = clamp(position_x, 50.0, viewport_size.x - 50.0)
	print("🎯 Viewport size: ", viewport_size)
	print("🎯 Position_x original: ", position_x, " | clamped: ", clamped_x)
	new_player.global_position = Vector2(clamped_x, -300)  # usar global para evitar offset do parent
	new_player.velocity = Vector2.ZERO
	new_player.visible = true
	print("🎯 Player ", player_name, " antes de add_child - global_pos: ", new_player.global_position, " | local_pos: ", new_player.position)
	
	# Adicionar à cena
	parent.add_child(new_player)
	await get_tree().process_frame
	print("✅ Player ", player_name, " APÓS add_child:")
	print("   - global_position: ", new_player.global_position)
	print("   - position: ", new_player.position)
	print("   - visible: ", new_player.visible)
	print("   - parent: ", str(new_player.get_parent().name) if new_player.get_parent() else "none")
	print("   - está na árvore: ", is_instance_valid(new_player) and new_player.is_inside_tree())

func _spawn_new_player_with_animation(old_player: Node2D, original_texture: Texture2D):

	# remover explosão se ainda existir no player antigo
	if old_player.has_node("AnimatedSprite2D"):
		old_player.get_node("AnimatedSprite2D").queue_free()
	
	# Duplicar o player antigo
	var new_player = old_player.duplicate()
	
	# Restaurar sprite e aparência
	if new_player.has_node("Sprite2D"):
		var player_sprite = new_player.get_node("Sprite2D")
		if original_texture:
			player_sprite.texture = original_texture
		player_sprite.modulate.a = 1.0
	
	# Posicionar no topo da tela
	new_player.position.y = -300
	new_player.velocity = Vector2.ZERO
	new_player.visible = true
	
	# Restaurar collision shape
	if new_player.has_node("CollisionShape2D"):
		var collision = new_player.get_node("CollisionShape2D")
		collision.disabled = false
	
	# Adicionar à cena (ao mesmo parent do player antigo)
	old_player.get_parent().add_child(new_player)
	
	# Animar queda com AnimationPlayer se existir (mesmo efeito que no play)
	if new_player.has_node("AnimationPlayer"):
		var anim_player = new_player.get_node("AnimationPlayer")
		if anim_player.has_animation("down"):
			anim_player.play("down")

func _remove_all_fires():
	# Encontrar e remover todos os fogos (Fire.png) em qualquer nível da cena
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	var removed := 0
	var stack: Array = [scene_root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node.has_node("Sprite2D"):
			var s = node.get_node("Sprite2D")
			if s.texture and s.texture.resource_path.contains("Fire.png"):
				node.queue_free()
				removed += 1
				continue
		for child in node.get_children():
			stack.append(child)
	print("🔥 Fires removed: ", removed)


func _remove_all_items_except_roleta():
	# Remove todas as instâncias de item_fall.gd exceto as roletas
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	var removed := 0
	var stack: Array = [scene_root]
	while stack.size() > 0:
		var node = stack.pop_back()
		var node_script = node.get_script()
		if node_script and node_script.resource_path.ends_with("item_fall.gd"):
			var keep_node = false
			# Não remover roletas
			if node.has_node("Sprite2D"):
				var s = node.get_node("Sprite2D")
				if s.texture and s.texture.resource_path.contains("roleta.png"):
					keep_node = true
			if not keep_node:
				node.queue_free()
				removed += 1
				continue
		for child in node.get_children():
			stack.append(child)
	print("🧹 Items (non-roleta) removed: ", removed)


func _remove_all_explosions():
	# Remove AnimatedSprite2D usados para explosão
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	var removed := 0
	var stack: Array = [scene_root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is AnimatedSprite2D:
			node.queue_free()
			removed += 1
			continue
		for child in node.get_children():
			stack.append(child)
	print("💨 Explosions removed: ", removed)

func _play_random_character_sound(sound_position: Vector2):
	# Carregar sons da pasta Sons/Personagem
	var character_sounds: Array[AudioStream] = []
	var dir := DirAccess.open("res://Sons/Personagem")
	
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
				var sound: AudioStream = load("res://Sons/Personagem/" + file_name)
				if sound:
					character_sounds.append(sound)
	
	# Se encontrou sons, tocar um aleatório
	if character_sounds.size() > 0:
		var sound_player = AudioStreamPlayer2D.new()
		sound_player.stream = character_sounds[randi() % character_sounds.size()]
		sound_player.global_position = sound_position
		
		# Adicionar à cena
		get_tree().get_current_scene().add_child(sound_player)
		
		# Tocar e remover quando terminar
		sound_player.play()
		sound_player.finished.connect(func(): sound_player.queue_free())

func _remove_nearby_objects():
	# Aspirador tem efeito aleatório: remove objetos próximos OU remove cenário (fundo branco)
	var random_choice = randi() % 2  # 0 ou 1
	
	if random_choice == 0:
		# Efeito 1: Remover objetos próximos
		var aspirador_pos = global_position
		var removal_radius = 200.0  # Raio de remoção em pixels
		
		# Procurar todos os objetos na cena
		var all_items = get_parent().get_children()
		var objects_to_remove = []
		
		for item in all_items:
			if item == self or not item is Node2D:
				continue
			
			if not item.has_node("Sprite2D"):
				continue
			
			var item_pos = item.global_position
			var distance = aspirador_pos.distance_to(item_pos)
			
			# Se estiver dentro do raio de remoção, marcar para remover
			# Não remover aspirador, buracos ou fogo
			if distance < removal_radius:
				if not ("is_hole" in item and item.is_hole):
					# Verificar se não é fogo
					var item_sprite = item.get_node("Sprite2D")
					if item_sprite.texture and not item_sprite.texture.resource_path.contains("Fire.png"):
						# Não remover outro aspirador
						if not item_sprite.texture.resource_path.contains("aspirador.png"):
							objects_to_remove.append(item)
		
		# Remover os objetos
		for item in objects_to_remove:
			item.queue_free()
	else:
		# Efeito 2: Aplicar um cenário branco temporário (comando pode trocar depois)
		var scene_root: Node = get_tree().get_current_scene()
		var scenario_node: Node = null
		if scene_root:
			scenario_node = scene_root.find_child("Scenario", true, false)
		if scenario_node and scenario_node is Sprite2D:
			var scenario_sprite: Sprite2D = scenario_node as Sprite2D
			# Criar uma textura branca simples 1x1 e aplicar
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 1, 1, 1))
			var white_tex := ImageTexture.create_from_image(img)
			scenario_sprite.texture = white_tex

func _handle_camera_interaction():
	# Random: 50% popup de foto, 50% explodir outro jogador
	var random_choice = randi() % 2
	
	if random_choice == 0:
		# Opção 1: Mostra popup de permissão de câmara e tira foto
		var permission_popup_scene = load("res://camera_permission_popup.tscn")
		var permission_popup = permission_popup_scene.instantiate()
		
		# Adicionar popup à cena
		get_tree().get_current_scene().add_child(permission_popup)
		
		# Conectar aos sinais
		permission_popup.permission_granted.connect(_on_camera_permission_granted)
		permission_popup.permission_denied.connect(_on_camera_permission_denied)
		
		print("📷 Mostrando popup de permissão de câmara")
	else:
		# Opção 2: Explodir o outro jogador (efeito de fogo)
		_explode_other_player()
		# Tocar som aleatório
		_play_random_object_sound()
		# Adicionar pontos
		_add_interaction_points()
		
		print("💥 Câmara explodiu o outro jogador!")

func _on_camera_permission_granted():
	# Acesso à câmara permitido - capturar foto
	_capture_camera_photo()
	# Tocar som aleatório
	_play_random_object_sound()
	# Adicionar pontos
	_add_interaction_points()

func _on_camera_permission_denied():
	# Mesmo negando, tira foto e coloca como background
	_capture_camera_photo()
	# Tocar som aleatório
	_play_random_object_sound()
	# Adicionar pontos
	_add_interaction_points()

func _capture_camera_photo():
	# NOTA: Godot 4 em desktop (macOS/Windows/Linux) tem suporte limitado para webcam
	# Em mobile funciona melhor. Para desktop, usamos screenshot como alternativa
	
	# Tentar usar CameraServer (funciona principalmente em mobile)
	var feeds = CameraServer.feeds()
	print("📷 Câmaras disponíveis: ", feeds.size())
	
	if feeds.size() > 0:
		var feed = feeds[0]
		print("📷 Nome da câmara: ", feed.get_name())
		feed.set_active(true)
		
		# Aguardar câmara inicializar
		await get_tree().create_timer(1.0).timeout
		
		var feed_image = feed.get_texture(CameraServer.FEED_RGBA_IMAGE)
		if feed_image:
			var img = feed_image.get_image()
			if img and img.get_width() > 1 and img.get_height() > 1:
				var captured_texture = ImageTexture.create_from_image(img)
				
				# Aplicar ao cenário
				var scene_root: Node = get_tree().get_current_scene()
				var scenario_node = scene_root.find_child("Scenario", true, false)
				
				if scenario_node and scenario_node is Sprite2D:
					var scenario_sprite: Sprite2D = scenario_node as Sprite2D
					scenario_sprite.texture = captured_texture
					print("📷 Foto da webcam aplicada ao cenário!")
					feed.set_active(false)
					return
	
	# Fallback: usar screenshot (mais confiável em desktop)
	print("📷 Usando screenshot do jogo como alternativa")
	_fallback_viewport_capture()

func _fallback_viewport_capture():
	# Fallback: capturar viewport se câmara não estiver disponível
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	
	if img:
		var captured_texture = ImageTexture.create_from_image(img)
		
		var scene_root: Node = get_tree().get_current_scene()
		var scenario_node: Node = null
		if scene_root:
			scenario_node = scene_root.find_child("Scenario", true, false)
		
		if scenario_node and scenario_node is Sprite2D:
			var scenario_sprite: Sprite2D = scenario_node as Sprite2D
			scenario_sprite.texture = captured_texture
			print("📷 Screenshot aplicado ao cenário!")
	else:
		print("⚠ Erro ao capturar imagem")

func _explode_other_player():
	# Determinar qual lado está o objeto (câmara)
	var screen_mid = get_viewport_rect().size.x / 2
	var camera_is_left = global_position.x < screen_mid
	
	# Procurar o jogador do lado oposto
	var scene_root = get_tree().get_current_scene()
	var target_player: Node2D = null
	
	# Procurar Player 1 e Player 2
	var player1 = scene_root.find_child("Player 1", true, false)
	var player2 = scene_root.find_child("Player 2", true, false)
	
	# Se câmara está à esquerda, explodir Player 2 (direita)
	# Se câmara está à direita, explodir Player 1 (esquerda)
	if camera_is_left:
		target_player = player2
		print("💥 Câmara à esquerda, explodindo Player 2 (direita)")
	else:
		target_player = player1
		print("💥 Câmara à direita, explodindo Player 1 (esquerda)")
	
	# Aplicar explosão ao jogador alvo
	if target_player:
		_apply_explosion_to_player(target_player)
	else:
		print("⚠ Jogador alvo não encontrado para explosão")
