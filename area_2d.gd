extends Area2D

var textures: Array = []

func _ready():
	set_process_input(true)
	load_textures()


func load_textures():
	var dir = DirAccess.open("res://Imagens/objects/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()

		while file != "":
			if file.ends_with(".png") or file.ends_with(".jpg") or file.ends_with(".webp"):
				textures.append(load("res://Imagens/objects/" + file))
			file = dir.get_next()

		dir.list_dir_end()


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		add_random_texture_to_canvas()


func add_random_texture_to_canvas():
	if textures.is_empty():
		print("Nenhuma textura encontrada na pasta!")
		return

	var tex = textures[randi() % textures.size()]
	var sprite := Sprite2D.new()
	sprite.texture = tex

	var canvas = get_tree().get_current_scene().get_node("CanvasLayer")
	canvas.add_child(sprite)

	sprite.position = Vector2(200, 200)
