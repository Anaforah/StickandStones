extends CharacterBody2D

func _ready():
	# Toca a animação "down" assim que a cena abre
	$AnimationPlayer.play("down")
