extends Node2D

func _ready():
	print("===== Descendentes de Object_rock =====")
	_print_descendants(self)
	print("=======================================")

func _print_descendants(node):
	for child in node.get_children():
		print("Descendente:", child.name, "| Tipo:", child)
		_print_descendants(child)
