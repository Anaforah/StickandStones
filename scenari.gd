extends Node2D

func _ready():
	print("===== Árvore de Nodes na execução =====")
	_print_tree(self, 0)
	print("=======================================")

func _print_tree(node, indent):
	print(" " * indent, node.name, " | ", node)
	for child in node.get_children():
		_print_tree(child, indent + 2)
