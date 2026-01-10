extends Node2D

func _ready():
	print("===== Árvore de Nodes na execução =====")
	_print_tree(self, 0)
	print("=======================================")

func _print_tree(node, indent):
	print(" " * indent, node.name, " | ", node)
	for child in node.get_children():
		_print_tree(child, indent + 2)

func _do_player_respawn(player_parent, player_name: String, original_texture: Texture2D, position_x: float, sprite_pos: Vector2, sprite_scale: Vector2, sprite_flip_h: bool, collision_data: Dictionary):
	print("🔄 Respawning ", player_name)
	
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

	# Posicionar no topo para cair
	var viewport_size = get_viewport_rect().size
	var clamped_x = clamp(position_x, 50.0, viewport_size.x - 50.0)
	new_player.position = Vector2(clamped_x, -300)
	new_player.velocity = Vector2.ZERO
	new_player.visible = true
	
	# Adicionar à cena
	var target_parent = player_parent if is_instance_valid(player_parent) else self
	target_parent.add_child(new_player)
	print("✅ ", player_name, " respawned at position: ", new_player.position)
