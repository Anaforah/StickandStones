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
				# Pa -> cria buraco e suga objetos para o outro lado
				elif path == "res://Imagens/Objetos/Pa.png":
					_create_hole_and_suck_objects()
					# Tocar som aleatório
					_play_random_object_sound()
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
				# Aumentar o raio para cobrir toda a área visível do buraco
				# Assumindo que a textura original tem um certo tamanho, multiplicar pela escala
				collision.shape.radius = 60.0  # Raio maior para cobrir toda a área
		
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
		return
	
	var hole_pos = global_position
	var screen_mid = get_viewport_rect().size.x / 2
	
	# Obter o raio do collision shape do buraco
	var hole_radius = 0.0
	if hole_collision.shape is CircleShape2D:
		hole_radius = hole_collision.shape.radius
		# Multiplicar pelo scale do sprite se houver
		if has_node("Sprite2D"):
			var sprite_node = get_node("Sprite2D")
			hole_radius *= max(sprite_node.scale.x, sprite_node.scale.y)
	
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
	# Verificar se o fogo está perto de player1 ou player2
	var scene_root = get_tree().get_current_scene()
	var distance_threshold = 150.0  # Aumentado para 150 pixels para melhor detecção
	
	# Procurar players diretamente usando find_child
	var player1 = scene_root.find_child("Player 1", true, false)
	var player2 = scene_root.find_child("Player 2", true, false)
	
	var closest_player = null
	var closest_distance = distance_threshold
	
	# Verificar player1
	if player1:
		var distance = _calculate_distance_to_player(player1)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player1
	
	# Verificar player2
	if player2:
		var distance = _calculate_distance_to_player(player2)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player2
	
	# Aplicar explosão apenas ao jogador mais próximo (se estiver dentro do threshold)
	if closest_player:
		await _apply_explosion_to_player(closest_player)
		# Remover o fogo após colisão
		queue_free()

func _calculate_distance_to_player(player: Node2D) -> float:
	# Calcular distância entre fogo e player (horizontal E vertical)
	var fire_pos = global_position
	var player_pos = player.global_position
	var distance_x = abs(fire_pos.x - player_pos.x)
	var distance_y = abs(fire_pos.y - player_pos.y)
	
	# Só considerar se estiver próximo verticalmente também (dentro de 150 pixels)
	if distance_y > 150:
		return 999999.0  # Retorna valor muito alto para ignorar
	
	return distance_x

func _apply_explosion_to_player(player: Node2D):
	# Verificar se o player já está explodindo (evitar duplicações)
	if player.has_meta("exploding"):
		return
	
	# Marcar o player como explodindo
	player.set_meta("exploding", true)
	
	# Encontrar o sprite do player
	if not player.has_node("Sprite2D"):
		# Player pode não ter Sprite2D, ignorar
		return

	var player_sprite = player.get_node("Sprite2D")

	# Guardar TODAS as informações necessárias do player ANTES de modificá-lo
	var original_texture = player_sprite.texture
	var player_parent = player.get_parent()
	var player_name = player.name
	var player_global_pos = player.global_position
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
		var explosion_texture = load("res://Imagens/Efeitos/Fire.png")
		if explosion_texture:
			player_sprite.texture = explosion_texture
			player_sprite.scale = player_sprite.scale * 1.5
		return
	
	# Configurar animação
	sprite_frames.set_animation_speed("explosion", 12)  # 12 FPS para terminar mais rápido
	sprite_frames.set_animation_loop("explosion", false)  # Reproduzir apenas 1 vez
	
	# Configurar AnimatedSprite2D
	animated_explosion.sprite_frames = sprite_frames
	animated_explosion.animation = "explosion"
	animated_explosion.scale = player_scale * 10.5  # Aumentado 2.5x o tamanho
	animated_explosion.global_position = player_global_pos
	
	# Adicionar explosão diretamente à cena (não ao player)
	player_parent.add_child(animated_explosion)
	
	# Esconder o player imediatamente
	player.visible = false
	
	# Começar a animação
	animated_explosion.play()
	
	# Parar movimento do player
	player.velocity = Vector2.ZERO

	# Aguardar o sinal de animação terminada
	await animated_explosion.animation_finished
	
	_remove_all_fires()
	
	# Fade out da explosão (mais rápido)
	var tween = create_tween()
	tween.tween_property(animated_explosion, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Remover a explosão IMEDIATAMENTE
	if is_instance_valid(animated_explosion):
		animated_explosion.queue_free()
	
	# Remover completamente o player antigo
	if is_instance_valid(player):
		player.queue_free()
	
	# Esperar um frame para garantir que foi removido
	await get_tree().process_frame
	
	# Criar novo player
	_spawn_new_player_at_top(player_parent, player_name, original_texture, player_global_pos.x)

func _spawn_new_player_at_top(parent: Node, player_name: String, original_texture: Texture2D, position_x: float):
	# Esperar um frame para garantir que o antigo player foi removido
	await get_tree().process_frame
	
	# Criar novo CharacterBody2D
	var new_player = CharacterBody2D.new()
	new_player.name = player_name
	
	# Adicionar Sprite2D
	var new_sprite = Sprite2D.new()
	new_sprite.texture = original_texture
	new_sprite.name = "Sprite2D"
	new_player.add_child(new_sprite)
	
	# Adicionar CollisionShape2D (cópia da forma original)
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	# Criar uma forma retangular básica
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 100)  # Tamanho aproximado do personagem
	collision.shape = shape
	new_player.add_child(collision)
	
	# Adicionar script do player
	if player_name == "Player 1":
		new_player.set_script(load("res://player_1.gd"))
	elif player_name == "Player 2":
		new_player.set_script(load("res://player_2.gd"))
	
	# Posicionar no topo com a mesma posição X do antigo
	new_player.position = Vector2(position_x, -300)
	
	# Adicionar à cena
	parent.add_child(new_player)

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
	# Encontrar e remover todos os fogos da cena
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return
	
	var all_items = scene_root.get_children()
	
	for item in all_items:
		# Verificar se é um item de fogo (tem Fire.png)
		if item.has_node("Sprite2D"):
			var item_sprite = item.get_node("Sprite2D")
			if item_sprite.texture and item_sprite.texture.resource_path.contains("Fire.png"):
				item.queue_free()

func _play_random_character_sound(position: Vector2):
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
		sound_player.global_position = position
		
		# Adicionar à cena
		get_tree().get_current_scene().add_child(sound_player)
		
		# Tocar e remover quando terminar
		sound_player.play()
		sound_player.finished.connect(func(): sound_player.queue_free())
