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
				# Determinar qual player está interagindo (1 = esquerda, 2 = direita)
				var player_id = 1 if is_left else 2
				var interaction_key = "E" if is_left else "P"
				
				# Extintor -> fogo
				if path == "res://Imagens/Objetos/Extintor.png":
					sprite.texture = fire_texture
					tex_index = -1
					# Tocar som aleatório
					_play_random_object_sound()
					# Log telemetry
					if has_node("/root/TelemetryManager"):
						get_node("/root/TelemetryManager").log_action(player_id, "interact_extintor", "key=%s" % interaction_key)
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
						# Log telemetry
						if has_node("/root/TelemetryManager"):
							get_node("/root/TelemetryManager").log_action(player_id, "interact_comando", "key=%s,scenario=%d" % [interaction_key, current_cenario_index])
				# Pa -> cria buraco e suga objetos para o outro lado
				elif path == "res://Imagens/Objetos/Pa.png":
					_create_hole_and_suck_objects()
					# Log telemetry
					if has_node("/root/TelemetryManager"):
						get_node("/root/TelemetryManager").log_action(player_id, "interact_pa", "key=%s,create_hole" % interaction_key)
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
				
				# Log telemetry - object transferred to other side
				var new_player_id = 1 if now_left else 2
				var object_name = "unknown"
				if sprite.texture and sprite.texture.resource_path:
					var path_parts = sprite.texture.resource_path.split("/")
					var file_name = path_parts[-1]
					object_name = file_name.get_basename()
				
				if has_node("/root/TelemetryManager"):
					get_node("/root/TelemetryManager").log_event(new_player_id, "objectTransfer", object_name)
			
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
		# Aumentar o tamanho do buraco (1.5x maior)
		sprite.scale = Vector2(1.2, 1.2)
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
	# Verifica se objetos tocam este buraco e os teleporta
	var hole_pos = global_position
	var screen_mid = get_viewport_rect().size.x / 2
	var hole_is_left = hole_pos.x < screen_mid
	
	# Raio de detecção do buraco (aumentado para garantir detecção)
	var detection_radius = 120.0
	
	var all_items = get_parent().get_children()
	
	for item in all_items:
		if item == self or not item is Node2D:
			continue
		
		if not item.has_node("Sprite2D"):
			continue
		
		# Verificar se é outro buraco
		if "is_hole" in item and item.is_hole:
			continue
		
		var item_pos = item.global_position
		var distance = hole_pos.distance_to(item_pos)
		
		# Debug: mostrar quando objetos estão próximos
		if distance < detection_radius + 50:
			print("Distance to hole: ", distance, " Object at: ", item_pos, " Hole at: ", hole_pos)
		
		# Se o objeto está tocando o buraco
		if distance < detection_radius:
			print("TELEPORTING object! Distance: ", distance)
			# Teleportar para o outro lado do ecrã (espelhar posição)
			var screen_width = get_viewport_rect().size.x
			var target_x: float
			
			# Calcular posição espelhada: refletir através do centro da tela
			# Fórmula: novo_x = largura_tela - x_original
			target_x = screen_width - hole_pos.x
			
			# Aplicar nova posição ao objeto (mantém Y, troca X)
			item.global_position.x = target_x
			
			# Se tiver a variável prev_side_left, atualizar
			if "prev_side_left" in item:
				item.prev_side_left = target_x < screen_mid
			
			# Tocar som de achievement
			if achievement_sounds.size() > 0 and audio_player:
				var random_idx = randi() % achievement_sounds.size()
				audio_player.stream = achievement_sounds[random_idx]
				audio_player.play()
