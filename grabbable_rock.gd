extends RigidBody2D

# Posição original da collision shape (usado para grab/drop/throw)
var original_collision_pos: Vector2 = Vector2.ZERO
var is_thrown := false
var last_side := ""  # Rastreia o lado anterior para detectar cruzamento
var sprite_switched := false  # Flag para trocar sprite apenas uma vez

@onready var sprite_left: Sprite2D = $rock if has_node("rock") else null
@onready var sprite_right: Sprite2D = $roleta if has_node("roleta") else null

func _ready():
	# Armazena posição original da collision
	if has_node("CollisionShape2D"):
		original_collision_pos = $CollisionShape2D.position
	
	# Torna rock visível e roleta invisível por padrão
	if sprite_left:
		sprite_left.visible = true
	if sprite_right:
		sprite_right.visible = false

func _physics_process(delta):
	if is_thrown:
		# Limita a pedra às margens da tela
		var viewport_size = get_viewport_rect().size
		var margin = 50
		
		# Clamp posição X
		global_position.x = clamp(global_position.x, margin, viewport_size.x - margin)
		
		# Clamp posição Y
		global_position.y = clamp(global_position.y, margin, viewport_size.y - margin)
		
		# Se atingiu uma margem, reduz a velocidade
		if global_position.x <= margin or global_position.x >= viewport_size.x - margin:
			linear_velocity.x *= 0.5
		if global_position.y <= margin or global_position.y >= viewport_size.y - margin:
			linear_velocity.y *= 0.5
		
		# Verifica se cruzou o meio da tela
		var screen_width = viewport_size.x
		var current_side = "left" if global_position.x < screen_width / 2 else "right"
		
		# Se mudou de lado, troca seus próprios sprites
		if not sprite_switched and last_side != "" and last_side != current_side:
			if sprite_left and sprite_right:
				sprite_left.visible = not sprite_left.visible
				sprite_right.visible = not sprite_right.visible
				sprite_switched = true
				print("Pedra lançada trocou sprite!")
			last_side = current_side
		elif last_side == "":
			last_side = current_side

