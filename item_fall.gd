extends Node2D

var target_position: Vector2 = Vector2.ZERO
var fall_speed := 300.0
var arrived := false
@onready var sprite := $Sprite2D

# Texturas possíveis e índice atual (serão atribuídos pelo spawner)
var object_textures: Array = []
var tex_index := 0
var object_name: String = ""  # Name of the object (drill, fireextinguisher, etc)

# Dragging
var dragging := false
var drag_offset := Vector2.ZERO
var prev_side_left := false

# Telemetry
var telemetry
var grabbed_by_player: int = -1  # Track which player grabbed the item
var current_side_player: int = 1  # Track which player's side the object is on

func _ready():
	# inicializa prev_side_left com base na posição inicial
	var screen_mid = get_viewport_rect().size.x / 2
	prev_side_left = global_position.x < screen_mid
	
	# Determine initial side player (left = player 1, right = player 2)
	current_side_player = 1 if prev_side_left else 2
	
	# Get telemetry reference
	telemetry = get_node_or_null("/root/TelemetryManager")
	
	# Log object spawn
	if telemetry and object_name:
		telemetry.log_event(current_side_player, "objectSpawn", object_name)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if sprite.get_rect().has_point(sprite.to_local(event.position)):
				dragging = true
				drag_offset = global_position - event.position
				
				# Use the current side player (determined by position)
				grabbed_by_player = current_side_player
				
				# Log grab action
				if telemetry and grabbed_by_player > 0:
					telemetry.log_action(grabbed_by_player, "grab", object_name)
					telemetry.log_state(grabbed_by_player, object_name, "")
		else:
			dragging = false

func _process(delta):
	if dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset

		# Verifica se cruzou o meio da tela enquanto segurado
		var screen_mid = get_viewport_rect().size.x / 2
		var now_left = global_position.x < screen_mid
		if now_left != prev_side_left:
			# Mudou de lado da tela
			var old_player = current_side_player
			current_side_player = 1 if now_left else 2
			
			# Troca textura para a próxima
			var old_texture_index = tex_index
			if object_textures.size() > 0:
				tex_index = (tex_index + 1) % object_textures.size()
				sprite.texture = object_textures[tex_index]
			
			# Log transfer between players with texture change info
			if telemetry:
				var texture_info = "texture_change_%d_to_%d" % [old_texture_index, tex_index]
				telemetry.log_action(old_player, "transfer", object_name + ",player" + str(current_side_player) + "," + texture_info)
				telemetry.log_event(current_side_player, "objectReceived", object_name)
				telemetry.log_event(current_side_player, "textureChanged", "index_%d" % tex_index)
				telemetry.log_state(current_side_player, object_name, "")
				telemetry.log_state(old_player, "none", "")
			
			prev_side_left = now_left
			grabbed_by_player = current_side_player

		return

	if not arrived and target_position:
		# Move apenas na vertical para garantir queda reta (x preservado)
		var vertical_target = Vector2(global_position.x, target_position.y)
		global_position = global_position.move_toward(vertical_target, fall_speed * delta)
		if abs(global_position.y - target_position.y) < 10:
			# Para no destino vertical e permanece (não é removido)
			global_position.y = target_position.y
			arrived = true

func _get_closest_player() -> int:
	var screen_mid = get_viewport_rect().size.x / 2
	return 1 if global_position.x < screen_mid else 2

func set_object_name(name: String) -> void:
	object_name = name
