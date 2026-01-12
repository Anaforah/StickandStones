extends Node

# Cursor global control for gamepad (player 2 right stick)
var cursor_pos: Vector2 = Vector2.ZERO
var cursor_visual: Control
var cursor_layer: CanvasLayer
var grabbing := false
var prev_rt := false
var prev_lt := false
var prev_x := false
var grabbed_item = null  # Referência ao item sendo agarrado

const CURSOR_SPEED := 480.0
const DEADZONE := 0.15

func _ready():
	cursor_layer = CanvasLayer.new()
	cursor_layer.layer = 100
	get_tree().root.add_child(cursor_layer)

	cursor_visual = Control.new()
	cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_visual.size = Vector2(40, 40)
	cursor_layer.add_child(cursor_visual)
	cursor_visual.draw.connect(func(): _draw_cursor(cursor_visual))

	cursor_pos = get_tree().get_root().get_mouse_position()
	cursor_visual.position = cursor_pos
	cursor_visual.queue_redraw()

func _process(delta):
	_update_cursor(delta)
	cursor_visual.position = cursor_pos
	cursor_visual.queue_redraw()
	_process_inputs()

func _update_cursor(delta: float) -> void:
	var rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rx) > DEADZONE:
		cursor_pos.x += rx * CURSOR_SPEED * delta
	if abs(ry) > DEADZONE:
		cursor_pos.y += ry * CURSOR_SPEED * delta
	var size = get_window().size
	cursor_pos.x = clamp(cursor_pos.x, 0, size.x)
	cursor_pos.y = clamp(cursor_pos.y, 0, size.y)

func _process_inputs() -> void:
	# Usar LB (Button 10) e RB (Button 11) para agarrar em vez dos triggers
	var lb_down = Input.is_joy_button_pressed(0, 10 as JoyButton)
	var rb_down = Input.is_joy_button_pressed(0, 11 as JoyButton)
	var lb_press = lb_down and not prev_rt
	var rb_press = rb_down and not prev_lt
	prev_rt = lb_down
	prev_lt = rb_down

	# Get the scene root for item detection
	var root = get_tree().root.get_child(0)  # Should be "scenario" node
	
	# Converter de coordenadas de tela (CanvasLayer) para coordenadas globais da cena
	# cursor_pos está em espaço de tela, precisamos converter para espaço global
	var canvas_transform = get_tree().root.get_canvas_transform()
	var world_pos = canvas_transform.affine_inverse() * cursor_pos

	# Procurar item sob o cursor
	if lb_press or rb_press:
		grabbed_item = _find_item_at_position(world_pos, root)
		if grabbed_item and grabbed_item.has_method("gamepad_grab"):
			grabbed_item.gamepad_grab()
			grabbing = true
		else:
			grabbing = false

	if grabbing and not lb_down and not rb_down:
		if grabbed_item and grabbed_item.has_method("gamepad_release"):
			grabbed_item.gamepad_release()
		grabbed_item = null
		grabbing = false

	if grabbing and grabbed_item and grabbed_item.has_method("gamepad_drag"):
		grabbed_item.gamepad_drag(world_pos)

	# X para usar item/roleta - APENAS DO LADO DIREITO
	var x_down = Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var x_press = x_down and not prev_x
	prev_x = x_down
	if x_press:
		# Usar o tamanho real da viewport/window, não o escalado
		var viewport_width = get_viewport().get_visible_rect().size.x
		var side_check = cursor_pos.x >= viewport_width / 2
		print("X press: cursor_pos.x=%s viewport_width/2=%s right_side=%s" % [cursor_pos.x, viewport_width/2, side_check])
		# Só funciona se cursor está do lado direito (x >= viewport_width/2)
		if side_check:
			var item = _find_item_at_position(world_pos, root)
			print("  Item found: %s" % (item.name if item else "null"))
			if item and item.has_method("gamepad_activate"):
				print("  Calling gamepad_activate")
				item.gamepad_activate()

func _find_item_at_position(world_pos: Vector2, root: Node) -> Node:
	# Procurar todos os items sob a posição, recursivamente
	var items_under_cursor = []
	
	_collect_items_at_position(root, world_pos, items_under_cursor)
	
	if items_under_cursor.size() > 0:
		# Retornar o item mais acima (último na árvore)
		items_under_cursor.sort_custom(func(a, b): return a.get_index() < b.get_index())
		return items_under_cursor[-1]
	
	return null

func _collect_items_at_position(node: Node, world_pos: Vector2, result: Array) -> void:
	# Verificar se este nó ou seu pai tem métodos de gamepad e Sprite2D
	var sprite_node = null
	var controller_node = null
	
	# Caso 1: O próprio nó tem Sprite2D (item_fall.gd)
	if node.has_node("Sprite2D"):
		sprite_node = node.get_node("Sprite2D")
		controller_node = node
	# Caso 2: É um Sprite2D filho de um nó com script (rock/roleta filhos de ObjectRock)
	elif node is Sprite2D and node.get_parent() and node.get_parent().get_script():
		sprite_node = node
		controller_node = node.get_parent()
	
	if sprite_node and sprite_node.texture and sprite_node.visible:
		# Calcular o retângulo global manualmente
		var sprite_rect = sprite_node.get_rect()
		var sprite_size = sprite_rect.size * sprite_node.scale
		var sprite_center = sprite_node.global_position
		
		# Criar retângulo global (ajustar para que a origem seja o centro)
		var global_rect = Rect2(sprite_center - sprite_size / 2, sprite_size)
		

		
		if global_rect.has_point(world_pos):
			# Se o nó controlador tem métodos de gamepad, adiciona à lista
			if controller_node and (controller_node.has_method("gamepad_grab") or controller_node.has_method("_spawn_single_item")):
				result.append(controller_node)
			elif controller_node:
				# Se não tem métodos, tenta adicionar o próprio nó
				result.append(node)
	
	# Recursivamente procurar nos filhos
	for child in node.get_children():
		_collect_items_at_position(child, world_pos, result)

func _draw_cursor(c: Control) -> void:
	var color := Color.YELLOW
	if grabbing:
		color = Color.GREEN
	c.draw_circle(Vector2(20,20), 10.0, color)
	c.draw_circle(Vector2(20,20), 3.0, Color.WHITE)
