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

# Posições originais da barreira central (para reset após alavanca)
var middle_collision_default_local_x = null
var middle_sprite_default_local_x = null

func _cache_middle_defaults() -> void:
	# Garante que as posições originais do retângulo central estão guardadas (em coordenadas locais)
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	if middle_collision_default_local_x == null:
		var middle_collision: CollisionShape2D = scene_root.find_child("Centered_Wall", true, false)
		if middle_collision:
			middle_collision_default_local_x = middle_collision.position.x
			print("🔍 Cached Centered_Wall default local x: ", middle_collision_default_local_x)

	if middle_sprite_default_local_x == null:
		var middle_sprite: Sprite2D = scene_root.get_node_or_null("StaticBody2D/Node/Sprite2D")
		if middle_sprite:
			middle_sprite_default_local_x = middle_sprite.position.x
			print("🔍 Cached middle sprite default local x: ", middle_sprite_default_local_x)

# Dragging
var dragging := false
var drag_offset := Vector2.ZERO
var prev_side_left := false
var is_hole := false  # Flag para indicar se o objeto é um buraco (não interativo)
var prev_q_pressed := false
var prev_o_pressed := false

# Gamepad (mantido apenas para compatibilidade; o controle real está em gamepad_cursor.gd)
static var gamepad_cursor_pos: Vector2 = Vector2.ZERO
static var gamepad_grabbed_item: Node = null
var gamepad_dragging := false
var gamepad_drag_offset := Vector2.ZERO
var prev_rt_pressed := false
var prev_lt_pressed := false
var prev_x_pressed := false

# Score global
static var global_score: int = 0
static var last_gain: int = 0

# Rock pass animation
var pass_rock_animation := false
var pass_rock_is_left := false

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

	# Guardar posições originais do retângulo central
	_cache_middle_defaults()

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
					gamepad_grabbed_item = self
					gamepad_dragging = true
		else:
			dragging = false
			gamepad_grabbed_item = null
			gamepad_dragging = false

func _process(delta):
	# Processar input de rato/teclado normalmente; gamepad agora é gerido por gamepad_cursor.gd

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

		# Check for throw action (Q for Player 1, O for Player 2)
		var q_down = Input.is_key_pressed(KEY_Q)
		var q_just_pressed = q_down and not prev_q_pressed
		prev_q_pressed = q_down
		
		var o_down = Input.is_key_pressed(KEY_O)
		var o_just_pressed = o_down and not prev_o_pressed
		prev_o_pressed = o_down
		
		var should_throw = (is_left and q_just_pressed) or (not is_left and o_just_pressed)
		
		if should_throw:
			_throw_object(is_left)

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
				# Alavanca -> estica e desloca o retângulo central, explodindo o outro jogador
				elif path == "res://Imagens/Objetos/alavanca.png":
					_handle_lever_interaction()
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
	prev_q_pressed = false
	prev_o_pressed = false
	
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
			
			# Se é uma pedra com animação de passe, fazer arremesso
			if pass_rock_animation:
				_animate_throw(pass_rock_is_left)
	
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
		# Mostrar floating text com o ganho
		_show_point_gain_floating(last_gain)

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
			var _hole_radius_fb = max(float(tex_sz_fb.x) * fallback_sprite.scale.x, float(tex_sz_fb.y) * fallback_sprite.scale.y) * 0.5
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
	var state = {"animation_complete": false, "timeout_reached": false}
	
	var on_animation_finished = func():
		state["animation_complete"] = true
	
	animation_signal.connect(on_animation_finished)
	
	while not state["animation_complete"] and not state["timeout_reached"]:
		await get_tree().process_frame
		if timeout_timer.time_left <= 0:
			print("⏱ Timeout na animação de explosão")
			state["timeout_reached"] = true
	
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

func _handle_lever_interaction() -> void:
	# Estica a alavanca, move a barreira central para o lado oposto e explode o adversário
	if not sprite:
		return

	print("🔨🔨🔨 LEVER INTERACTION STARTED 🔨🔨🔨")
	_cache_middle_defaults()

	var screen_mid = get_viewport_rect().size.x / 2.0
	var lever_is_left = global_position.x < screen_mid

	var original_scale = sprite.scale
	var stretched_scale = original_scale
	stretched_scale.x = max(original_scale.x * 6.0, original_scale.x + 2.0)

	var tween = create_tween()
	tween.tween_property(sprite, "scale:x", stretched_scale.x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale:x", original_scale.x, 0.25).set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	print("✅ Calling shift...")
	await _shift_middle_wall_to_opposite_side(lever_is_left)
	print("✅ Shift done, now calling explode...")
	await _explode_player_on_opposite_side(lever_is_left)
	print("✅ Calling reset...")
	await _reset_middle_wall_position()
	print("✅ Reset done!")
	_play_random_object_sound()
	_add_interaction_points()
	print("🔨🔨🔨 LEVER INTERACTION FINISHED 🔨🔨🔨")

func _shift_middle_wall_to_opposite_side(lever_is_left: bool) -> void:
	# Move o retângulo central (Sprite + colisão) para o lado oposto da alavanca
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	var middle_collision: CollisionShape2D = scene_root.find_child("Centered_Wall", true, false)
	var middle_sprite: Sprite2D = scene_root.get_node_or_null("StaticBody2D/Node/Sprite2D")

	var duration = 0.4
	var shift_amount = 300.0  # deslocar 300 pixels na posição local
	var target_local_x_collision = middle_collision_default_local_x if middle_collision_default_local_x != null else 0.0
	var target_local_x_sprite = middle_sprite_default_local_x if middle_sprite_default_local_x != null else 0.0

	if lever_is_left:
		target_local_x_collision += shift_amount
		target_local_x_sprite += shift_amount
	else:
		target_local_x_collision -= shift_amount
		target_local_x_sprite -= shift_amount

	var tweens_done = 0
	var total_tweens = 0

	if middle_collision:
		total_tweens += 1
		var tween_collision = middle_collision.create_tween()
		tween_collision.tween_property(middle_collision, "position:x", target_local_x_collision, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_collision.finished.connect(func(): tweens_done += 1)

	if middle_sprite:
		total_tweens += 1
		var tween_sprite = middle_sprite.create_tween()
		tween_sprite.tween_property(middle_sprite, "position:x", target_local_x_sprite, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_sprite.finished.connect(func(): tweens_done += 1)

	# Wait for shift tweens to finish
	while tweens_done < total_tweens:
		await get_tree().process_frame

func _reset_middle_wall_position() -> void:
	# Reposiciona o retângulo central para a posição original, se conhecida
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	var middle_collision: CollisionShape2D = scene_root.find_child("Centered_Wall", true, false)
	var middle_sprite: Sprite2D = scene_root.get_node_or_null("StaticBody2D/Node/Sprite2D")
	var duration = 0.35
	var target_x_collision = middle_collision_default_local_x if middle_collision_default_local_x != null else 0.0
	var target_x_sprite = middle_sprite_default_local_x if middle_sprite_default_local_x != null else 642.5

	var tweens_done = 0
	var total_tweens = 0

	if middle_collision:
		total_tweens += 1
		var tween_collision = middle_collision.create_tween()
		tween_collision.tween_property(middle_collision, "position:x", target_x_collision, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_collision.finished.connect(func(): tweens_done += 1)

	if middle_sprite:
		total_tweens += 1
		var tween_sprite = middle_sprite.create_tween()
		tween_sprite.tween_property(middle_sprite, "position:x", target_x_sprite, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_sprite.finished.connect(func(): tweens_done += 1)

	# Wait for all tweens to finish
	while tweens_done < total_tweens:
		await get_tree().process_frame

func _explode_player_on_opposite_side(lever_is_left: bool) -> void:
	# Explode o jogador que está do lado contrário à alavanca
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return

	var player_left = scene_root.find_child("Player 1", true, false)
	var player_right = scene_root.find_child("Player 2", true, false)
	var target_player: Node2D = null

	if lever_is_left:
		target_player = player_right
	else:
		target_player = player_left

	if target_player:
		await _apply_explosion_to_player(target_player)

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
func _update_gamepad_cursor() -> void:
	# Atualizar posição do cursor baseado no joystick direito (gamepad device 0)
	var right_stick_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var right_stick_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Aplicar deadzone
	if abs(right_stick_x) > 0.1:
		# Mover o cursor baseado no joystick, com velocidade de 400 pixels/sec
		gamepad_cursor_pos.x += right_stick_x * 400 * get_physics_process_delta_time()
	
	if abs(right_stick_y) > 0.1:
		gamepad_cursor_pos.y += right_stick_y * 400 * get_physics_process_delta_time()
	
	# Limitar o cursor ao viewport
	var viewport_size = get_viewport_rect().size
	gamepad_cursor_pos.x = clamp(gamepad_cursor_pos.x, 0, viewport_size.x)
	gamepad_cursor_pos.y = clamp(gamepad_cursor_pos.y, 0, viewport_size.y)
	

func _process_gamepad_interactions() -> void:
	# Verificar se RT ou LT está pressionado (são eixos analógicos, não botões)
	var rt_down = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	var lt_down = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	
	var rt_just_pressed = rt_down and not prev_rt_pressed
	var lt_just_pressed = lt_down and not prev_lt_pressed
	
	prev_rt_pressed = rt_down
	prev_lt_pressed = lt_down
	
	# Se RT ou LT foi pressionado, simular clique do mouse
	if rt_just_pressed or lt_just_pressed:
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = true
		mouse_event.button_mask = MOUSE_BUTTON_MASK_LEFT
		mouse_event.position = gamepad_cursor_pos
		get_tree().root.push_input(mouse_event)
		# Registrar tentativa de agarrar; só ficará verdadeiro se _input aceitar
		gamepad_grabbed_item = null
	
	# Se RT ou LT foi libertado, simular soltar do mouse
	if gamepad_grabbed_item and not rt_down and not lt_down:
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = false
		mouse_event.button_mask = 0
		mouse_event.position = gamepad_cursor_pos
		get_tree().root.push_input(mouse_event)
		gamepad_grabbed_item = null
		gamepad_dragging = false
		dragging = false
	
	# Se estiver a arrastar com gamepad, processar movimento
	if gamepad_dragging:
		var motion_event = InputEventMouseMotion.new()
		motion_event.position = gamepad_cursor_pos
		motion_event.relative = Vector2.ZERO
		get_tree().root.push_input(motion_event)
	
	# Verificar se X foi pressionado para ativar o item
	var x_down = Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var x_just_pressed = x_down and not prev_x_pressed
	prev_x_pressed = x_down
	if x_just_pressed and gamepad_dragging:
		_activate_item_gamepad()

func _get_item_at_position(pos: Vector2) -> Node2D:
	# Encontrar o item na posição especificada
	# Procurar todos os nodes de item_fall na cena (função estática)
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return null
	
	# Procurar recursivamente todos os items
	var items_at_pos = []
	_find_items_in_tree(scene_root, items_at_pos, pos)
	
	# Se há múltiplos items, pegar o que está por cima (índice maior na árvore)
	if items_at_pos.size() > 0:
		items_at_pos.sort_custom(func(a, b): return a.get_index() < b.get_index())
		if randf() < 0.01:
			print("✅ Encontrados ", items_at_pos.size(), " items em ", pos)
		return items_at_pos[-1]
	
	return null

func _find_items_in_tree(node: Node, items_list: Array, pos: Vector2) -> void:
	# Verificar se este node é um item_fall
	if node.get_script() == load("res://item_fall.gd"):
		if node.has_node("Sprite2D"):
			var item_sprite = node.get_node("Sprite2D")
			if item_sprite.texture != null:
				# Calcular o retângulo global do sprite
				var sprite_size = item_sprite.texture.get_size() * item_sprite.scale
				var sprite_global_pos = item_sprite.global_position - sprite_size / 2
				var sprite_rect = Rect2(sprite_global_pos, sprite_size)
				
				if sprite_rect.has_point(pos):
					items_list.append(node)
					if randf() < 0.01:
						print("Item: ", node.name, " at ", sprite_global_pos, " Size: ", sprite_size, " CONTAINS ", pos)
	
	# Procurar recursivamente em filhos
	for child in node.get_children():
		_find_items_in_tree(child, items_list, pos)

func _activate_item_gamepad() -> void:
	# Ativar o item que está sendo arrastado pelo gamepad (botão X)
	if sprite.texture:
		var path: String = sprite.texture.resource_path
		# Extintor -> fogo
		if path == "res://Imagens/Objetos/Extintor.png":
			sprite.texture = fire_texture
			tex_index = -1
			_play_random_object_sound()
			_multiply_fire_on_side()
			_add_interaction_points()
		# Comando -> troca cenário
		elif path == "res://Imagens/Objetos/comando.png":
			var scene_root: Node = get_tree().get_current_scene()
			var scenario_node: Node = null
			if scene_root:
				scenario_node = scene_root.find_child("Scenario", true, false)
			if scenario_node and scenario_node is Sprite2D:
				var scenario_sprite: Sprite2D = scenario_node as Sprite2D
				current_cenario_index = (current_cenario_index + 1) % cenario_textures.size()
				scenario_sprite.texture = cenario_textures[current_cenario_index]
				_play_random_object_sound()
			_add_interaction_points()
		# Pa -> cria buraco e suga objetos
		elif path == "res://Imagens/Objetos/Pa.png":
			_create_hole_and_suck_objects()
			_play_random_object_sound()
			_add_interaction_points()
		# Aspirador -> remove objetos próximos
		elif path == "res://Imagens/Objetos/aspirador.png":
			_remove_nearby_objects()
			_play_random_object_sound()
			_add_interaction_points()
		# Camara -> mostra popup e tira foto
		elif path == "res://Imagens/Objetos/camara.png":
			_handle_camera_interaction()
		# Alavanca -> efeito de deslocar barreira e explodir o adversário
		elif path == "res://Imagens/Objetos/alavanca.png":
			_handle_lever_interaction()

func _draw_gamepad_cursor(control: Control) -> void:
	# Verificar se há um item sob o cursor
	var item_at_cursor = gamepad_grabbed_item if gamepad_grabbed_item else null
	
	# Determinar cor do cursor
	var cursor_color: Color
	var cursor_radius: float
	
	if gamepad_grabbed_item != null:
		# Verde quando agarrando
		cursor_color = Color.GREEN
		cursor_radius = 15.0
	elif item_at_cursor != null:
		# Vermelho quando passa por cima de um item
		cursor_color = Color.RED
		cursor_radius = 12.0
	else:
		# Amarelo quando não há item sob o cursor
		cursor_color = Color.YELLOW
		cursor_radius = 10.0
	
	# Desenhar círculo exterior
	control.draw_circle(Vector2(20, 20), cursor_radius, cursor_color)
	
	# Desenhar ponto central
	control.draw_circle(Vector2(20, 20), 3.0, Color.WHITE)

# ===================== GAMEPAD METHODS =====================
func gamepad_grab() -> void:
	"""Inicia o drag do item via gamepad"""
	if is_hole:
		return
	dragging = true
	var screen_mid = get_viewport_rect().size.x / 2
	prev_side_left = global_position.x < screen_mid

func gamepad_release() -> void:
	"""Termina o drag do item via gamepad"""
	dragging = false

func gamepad_drag(world_pos: Vector2) -> void:
	"""Move o item para seguir o cursor do gamepad"""
	if dragging:
		# Move diretamente para a posição do cursor
		global_position = world_pos
		
		# Verifica se cruzou o meio da tela enquanto segurado
		var screen_mid = get_viewport_rect().size.x / 2
		var now_left = global_position.x < screen_mid
		if now_left != prev_side_left:
			# cruzou — troca textura para a próxima
			if object_textures.size() > 0:
				tex_index = (tex_index + 1) % object_textures.size()
				sprite.texture = object_textures[tex_index]
			# Tocar som de achievement
			_play_random_achievement_sound()
			prev_side_left = now_left

func gamepad_activate() -> void:
	"""Ativa o item (equivalente a pressionar X)"""
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
		# Pedra (rock) -> remove do jogo
		elif path == "res://Imagens/Pedra.png":
			queue_free()
		# Roleta (spinner) -> múltiplos objetos aparecem
		elif path == "res://Imagens/roleta.png":
			var object_rock_parent = get_parent()
			if object_rock_parent and object_rock_parent.has_method("_spawn_single_item"):
				object_rock_parent._spawn_single_item()
		# Alavanca -> desloca a barreira central e explode o outro jogador
		elif path == "res://Imagens/Objetos/alavanca.png":
			_handle_lever_interaction()
func _throw_object(is_left: bool) -> void:
	"""Arremessa o objeto para o lado oposto da tela."""
	if not dragging:
		return
	
	# Stop dragging
	dragging = false
	gamepad_grabbed_item = null
	gamepad_dragging = false
	
	_animate_throw(is_left)

func _animate_throw(is_left: bool) -> void:
	"""Anima o objeto arremessado em um arco para o outro lado."""
	var viewport_size = get_viewport_rect().size
	var throw_distance = viewport_size.x  # Distância a percorrer
	var throw_duration = 1.0  # Tempo em segundos
	var screen_mid = viewport_size.x / 2
	
	# Se o objeto está no lado esquerdo, arremessa para a direita
	# Se está no lado direito, arremessa para a esquerda
	var throw_direction = 1.0 if is_left else -1.0
	
	# Calcular posição final
	var final_x = global_position.x + (throw_direction * throw_distance)
	final_x = clamp(final_x, 0, viewport_size.x)
	
	var crossed_mid = false
	
	# Criar tween para animar movimento horizontal com arco (movimento de lançamento)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Animar X (movimento horizontal)
	tween.tween_property(self, "global_position:x", final_x, throw_duration)
	
	# Simultâneamente, animar Y (movimento de arco)
	var arc_tween = create_tween()
	arc_tween.set_ease(Tween.EASE_IN)
	arc_tween.set_trans(Tween.TRANS_QUAD)
	var start_y = global_position.y
	arc_tween.tween_property(self, "global_position:y", start_y - 150, throw_duration * 0.5)  # Sobe
	arc_tween.tween_property(self, "global_position:y", start_y + 50, throw_duration * 0.5)   # Desce
	
	# Criar um timer para verificar cruzamento durante a animação
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = 0.05  # Verificar a cada 50ms
	check_timer.timeout.connect(func():
		var current_x = global_position.x
		# Verificar se cruzou a metade
		if not crossed_mid:
			if (is_left and current_x >= screen_mid) or (not is_left and current_x <= screen_mid):
				crossed_mid = true
				# Trocar textura aleatória
				if object_textures.size() > 0 and sprite:
					tex_index = (tex_index + 1) % object_textures.size()
					sprite.texture = object_textures[tex_index]
					print("🔄 Textura trocada ao cruzar o meio: índice=", tex_index)
				# Tocar som de achievement
				_play_random_achievement_sound()
	)
	check_timer.start()
	
	# Limpar timer quando animação terminar
	tween.finished.connect(func():
		check_timer.queue_free()
	)
	
	print("🚀 Objeto arremessado: direção=", throw_direction, " destino_x=", final_x)