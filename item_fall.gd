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
	if sprite.texture and sprite.texture.resource_path == "res://Imagens/Efeitos/Fire.png":
		_check_fire_collision_with_players()

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

func _check_fire_collision_with_players():
	# Verificar se o fogo está perto de player1 ou player2
	var scene_root = get_tree().get_current_scene()
	var distance_threshold = 150.0  # Distância para detectar colisão
	
	# Procurar todos os players na cena
	var all_children = scene_root.get_children()
	
	for child in all_children:
		# Procurar player1 e player2
		if child.name == "AnimationPlayer":
			# Player 1
			if child.has_node("Player 1"):
				var player1 = child.get_node("Player 1")
				_check_player_fire_collision(player1, distance_threshold)
		elif child.name == "AnimationPlayer2":
			# Player 2
			if child.has_node("Player 2"):
				var player2 = child.get_node("Player 2")
				_check_player_fire_collision(player2, distance_threshold)

func _check_player_fire_collision(player: Node2D, distance_threshold: float):
	# Verificar distância entre fogo e player
	var fire_pos = global_position
	var player_pos = player.global_position
	var distance = fire_pos.distance_to(player_pos)
	
	if distance < distance_threshold:
		# Aplicar efeito de explosão ao player
		_apply_explosion_to_player(player)
		# Remover o fogo após colisão
		queue_free()

func _apply_explosion_to_player(player: Node2D):
	# Encontrar o sprite do player
	if not player.has_node("Sprite2D"):
		return
	
	var player_sprite = player.get_node("Sprite2D")
	var explosion_texture = load("res://Imagens/Efeitos/man_explotion.gif")
	
	# Se não conseguir carregar, tentar sem cache
	if not explosion_texture:
		explosion_texture = ResourceLoader.load("res://Imagens/Efeitos/man_explotion.gif", "", ResourceLoader.CACHE_MODE_REUSE)
	
	if explosion_texture:
		# Trocar para textura de explosão
		player_sprite.texture = explosion_texture
		
		# Parar movimento do player
		player.velocity = Vector2.ZERO
		
		# Fazer desaparecer após a animação (2 segundos)
		var tween = create_tween()
		tween.tween_callback(func(): player_sprite.modulate.a = 0.0)
		tween.tween_callback(func(): 
			# Criar novo player caindo de cima
			_spawn_new_player(player)
			# Esconder o player antigo
			player.visible = false
		).set_delay(1.5)
	else:
		print("⚠ Erro: não conseguiu carregar man_explotion.gif")

func _spawn_new_player(old_player: Node2D):
	# Duplicar o player antigo
	var new_player = old_player.duplicate()
	
	# Restaurar sprite e aparência
	if new_player.has_node("Sprite2D"):
		var sprite = new_player.get_node("Sprite2D")
		var man_texture = load("res://Imagens/Man.png")
		if man_texture:
			sprite.texture = man_texture
		sprite.modulate.a = 1.0
	
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
	
	# Animar queda com AnimationPlayer se existir
	if new_player.has_node("AnimationPlayer"):
		var anim_player = new_player.get_node("AnimationPlayer")
		if anim_player.has_animation("down"):
			anim_player.play("down")