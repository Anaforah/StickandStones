extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var is_in_range: bool = false
var target_object: RigidBody2D = null
var held_object: RigidBody2D = null
var holding := false

# --- Player animation (walk/jump) ---
@onready var player_sprite: Sprite2D = $Sprite2D
@onready var TEX_MAN: Texture2D = preload("res://Imagens/Man.png")
@onready var TEX_MAN2: Texture2D = preload("res://Imagens/man2.png")
@onready var TEX_JUMP: Texture2D = preload("res://Imagens/ManJump.png")
var _walk_accum := 0.0
var _walk_toggle := false
const WALK_SWAP_TIME := 0.15

@onready var hand_position: Marker2D = $HandPosition
@onready var range_area: Area2D = $Range

func _ready():
	# Conecta os sinais da área para detectar objetos pegáveis
	range_area.body_entered.connect(_on_range_body_entered)
	range_area.body_exited.connect(_on_range_body_exited)


func _physics_process(delta: float) -> void:
	# Movimento horizontal
	var direction := Input.get_axis("p1_move_left", "p1_move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo
	if Input.is_action_just_pressed("p1_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	# Atualiza animação de andar/saltar após mover
	_update_animation(direction, delta)

	# Sprites follow the hand automatically as children


func _process(_delta: float) -> void:
	# Grab
	if Input.is_action_just_pressed("p1_grab"):
		# Se já está agarrando, tenta spawnar ao invés de soltar
		if holding and held_object:
			var object_rock_parent = held_object.get_parent()
			# Se está agarrando uma ItemFall (roleta), chama spawn do ObjectRock pai
			if object_rock_parent and object_rock_parent.has_method("_spawn_single_item"):
				# Busca o sprite da roleta para pegar a posição correta
				var roleta_sprite = held_object.get_node_or_null("roleta")
				if roleta_sprite:
					object_rock_parent._spawn_single_item(roleta_sprite.global_position)
				else:
					object_rock_parent._spawn_single_item()
		# Senão, tenta agarrar um novo objeto
		elif is_in_range and target_object and not holding:
			# Pega a pedra
			holding = true
			held_object = target_object
			# Se for ItemFall (roleta), permite spawn ao agarrar
			var object_rock_parent = held_object.get_parent()
			# Reseta flags quando agarrada
			if "is_thrown" in held_object:
				held_object.is_thrown = false
				held_object.last_side = ""
				if "sprite_switched" in held_object:
					held_object.sprite_switched = false
			# Busca o ObjectRock pai desta pedra específica
			if object_rock_parent and "switched" in object_rock_parent:
				object_rock_parent.switched = false
			held_object.global_position = hand_position.global_position
			target_object.get_node("CollisionShape2D").position = target_object.original_collision_pos
			target_object.freeze = true  # congela física
			target_object.get_node("CollisionShape2D").disabled = true  # desabilita colisão
			# Reparent rock to hand
			held_object.get_parent().remove_child(held_object)
			hand_position.add_child(held_object)
			held_object.position = Vector2(0, 0)
			# Reparent sprites to hand
			var sprite_left = target_object.get_node("rock")
			var sprite_right = target_object.get_node("roleta")
			target_object.remove_child(sprite_left)
			target_object.remove_child(sprite_right)
			hand_position.add_child(sprite_left)
			hand_position.add_child(sprite_right)
			sprite_left.position = Vector2(0, 0)
			sprite_right.position = Vector2(0, 0)
			# Aumenta escala quando na mão
			sprite_left.scale = Vector2(0.3, 0.3)
			sprite_right.scale = Vector2(0.3, 0.3)

	# Drop
	if Input.is_action_just_pressed("p1_drop") and holding:
		# Solta a pedra para cair verticalmente
		holding = false
		# volta para o mundo
		hand_position.remove_child(held_object)
		get_tree().current_scene.add_child(held_object)
		# posição inicial = mão
		held_object.global_position = hand_position.global_position
		held_object.get_node("CollisionShape2D").position = Vector2(0, 0)
		held_object.freeze = false  # libera física
		held_object.get_node("CollisionShape2D").disabled = false  # habilita colisão
		# Reparent sprites back
		var sprite_left = hand_position.get_node("rock")
		var sprite_right = hand_position.get_node("roleta")
		hand_position.remove_child(sprite_left)
		hand_position.remove_child(sprite_right)
		held_object.add_child(sprite_left)
		held_object.add_child(sprite_right)
		# Center sprites at rock's position (hand position)
		sprite_left.position = Vector2(0, 0)
		sprite_right.position = Vector2(0, 0)
		# Restaura escala pequena
		sprite_left.scale = Vector2(0.08331547, 0.07813338)
		sprite_right.scale = Vector2(0.08304072, 0.08457031)
		held_object = null

	# Throw
	if Input.is_action_just_pressed("p1_throw") and holding:
		holding = false

		var dir = sign(hand_position.global_position.x - global_position.x)
		if dir == 0:
			dir = 1

		# volta para o mundo
		hand_position.remove_child(held_object)
		get_tree().current_scene.add_child(held_object)

		# posição inicial ligeiramente à frente da mão
		held_object.global_position = hand_position.global_position + Vector2(dir * 20, 0)
		
		# reativa física
		held_object.freeze = false
		held_object.linear_velocity = Vector2.ZERO
		held_object.angular_velocity = 0
		held_object.get_node("CollisionShape2D").disabled = false
		held_object.get_node("CollisionShape2D").position = Vector2(0, 0)
		
		# Desativa modo de queda se for ItemFall
		if "is_falling_mode" in held_object:
			held_object.is_falling_mode = false
			held_object.gravity_scale = 1  # Restaura gravidade normal
			held_object.lock_rotation = false
		
		# Reparent sprites back
		var sprite_left = hand_position.get_node("rock")
		var sprite_right = hand_position.get_node("roleta")
		hand_position.remove_child(sprite_left)
		hand_position.remove_child(sprite_right)
		held_object.add_child(sprite_left)
		held_object.add_child(sprite_right)
		sprite_left.position = Vector2(0, 0)
		sprite_right.position = Vector2(0, 0)

		# arco real (sprite + collision juntos)
		held_object.linear_velocity = Vector2(dir * 800, 0)
		# Permite passar por paredes quando lançada
		held_object.collision_mask = 0
		# Marca como lançada para limitar às margens
		if "is_thrown" in held_object:
			held_object.is_thrown = true
		
		# Reseta switched para permitir próxima troca
		var object_rock_parent = held_object.get_parent()
		if object_rock_parent and "switched" in object_rock_parent:
			object_rock_parent.switched = false
		
		held_object = null
	
	# Interagir com roleta (ItemFall) para spawnar objetos
	if Input.is_action_just_pressed("use_item") and holding and held_object:
		var object_rock_parent = held_object.get_parent()
		# Se está agarrando uma ItemFall (roleta), chama spawn do ObjectRock pai
		if object_rock_parent and object_rock_parent.has_method("_spawn_single_item"):
			object_rock_parent._spawn_single_item()





# -----------------------------
# DETECÇÃO DE OBJETOS PEGÁVEIS
# -----------------------------
func _on_range_body_entered(body: Node) -> void:
	if body.is_in_group("CanGrab") and body is RigidBody2D:
		is_in_range = true
		target_object = body

func _on_range_body_exited(body: Node) -> void:
	if body.is_in_group("CanGrab") and body == target_object:
		is_in_range = false
		target_object = null


# -----------------------------
# ANIMAÇÃO DE ANDAR/SALTAR
# -----------------------------
func _update_animation(direction: float, delta: float) -> void:
	if player_sprite == null:
		return
	# Saltando: sempre usa frame de pulo
	if not is_on_floor():
		player_sprite.texture = TEX_JUMP
		return
	# Andando: alterna entre Man2 e Man constantemente
	if direction != 0.0:
		_walk_accum += delta
		if _walk_accum >= WALK_SWAP_TIME:
			_walk_accum = 0.0
			_walk_toggle = not _walk_toggle
		player_sprite.texture = (TEX_MAN2 if _walk_toggle else TEX_MAN)
	else:
		# Parado: usa Man
		player_sprite.texture = TEX_MAN
