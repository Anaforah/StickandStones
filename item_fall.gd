extends RigidBody2D

var target_position: Vector2 = Vector2.ZERO
var fall_speed := 300.0
var arrived := false
var is_falling_mode := true  # Flag para saber se está no modo de queda controlada
@onready var sprite := $Sprite2D

# Texturas possíveis e índice atual (serão atribuídos pelo spawner)
var object_textures: Array = []
var tex_index := 0

# Score tracking (used by object_rock.gd)
var last_gain: int = 0
var global_score: int = 0

# Posição original da collision shape (usado para grab/drop/throw)
var original_collision_pos: Vector2 = Vector2.ZERO

func _ready():
	# Armazena posição original da collision
	if has_node("CollisionShape2D"):
		original_collision_pos = $CollisionShape2D.position

func _process(delta):
	# Só executa a lógica de queda controlada se estiver no modo falling
	if is_falling_mode and not arrived and target_position:
		# Move apenas na vertical para garantir queda reta (x preservado)
		var vertical_target = Vector2(global_position.x, target_position.y)
		global_position = global_position.move_toward(vertical_target, fall_speed * delta)
		if abs(global_position.y - target_position.y) < 10:
			# Para no destino vertical e permanece (não é removido)
			global_position.y = target_position.y
			arrived = true
			# Para completamente para poder ser agarrado
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0
			lock_rotation = true
			gravity_scale = 0
			freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
			freeze = true
			print("ItemFall chegou e CONGELOU - pode ser agarrado!")
