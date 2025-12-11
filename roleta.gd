extends Area2D

var textures: Array = []

func _ready():
	load_textures()


func load_textures():
	var dir = DirAccess.open("res://Imagens/objects/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()

		while file != "":
			if file.ends_with(".png") or file.ends_with(".jpg") or file.ends_with(".webp"):
				textures.append(load("res://objects/" + file))
			file = dir.get_next()

		dir.list_dir_end()


func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		add_random_texture_to_canvas()


func add_random_texture_to_canvas():
	if textures.is_empty():
		print("Nenhuma textura encontrada na pasta objects/")
		return

	# Escolher textura random
	var tex = textures[randi() % textures.size()]

	# Criar Sprite2D novo
	var sprite := Sprite2D.new()
	sprite.texture = tex

	# Pegar CanvasLayer da cena atual
	var canvas = get_tree().get_current_scene().get_node("CanvasLayer")
	canvas.add_child(sprite)

	# Definir posição inicial
	sprite.position = Vector2(200, 200)  # ajusta como quiser
