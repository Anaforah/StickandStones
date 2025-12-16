extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var is_in_range: bool = false
var target_object: RigidBody2D = null
var held_object: RigidBody2D = null
var holding := false

@onready var hand_position: Marker2D = $HandPosition
@onready var range_area: Area2D = $Range

func _ready():
	# Conecta os sinais da área para detectar objetos pegáveis
	range_area.body_entered.connect(_on_range_body_entered)
	range_area.body_exited.connect(_on_range_body_exited)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("p2_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("p2_move_left", "p2_move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Sprites follow the hand automatically as children


func _process(_delta: float) -> void:
	# Grab
	if Input.is_action_just_pressed("p2_grab") and is_in_range and target_object and not holding:
		# Pega a pedra
		holding = true
		held_object = target_object
		target_object.get_node("CollisionShape2D").position = target_object.original_collision_pos
		target_object.freeze = true  # congela física
		target_object.get_node("CollisionShape2D").disabled = true  # desabilita colisão
		# Reparent sprites to hand
		var sprite_left = target_object.get_node("rock")
		var sprite_right = target_object.get_node("roleta")
		target_object.remove_child(sprite_left)
		target_object.remove_child(sprite_right)
		hand_position.add_child(sprite_left)
		hand_position.add_child(sprite_right)
		sprite_left.position = Vector2(0, 0)
		sprite_right.position = Vector2(0, 0)

	# Drop
	if Input.is_action_just_pressed("p2_drop") and holding:
		# Solta a pedra para cair verticalmente
		holding = false
		# Move rock to hand position first
		held_object.move_to(hand_position.global_position)
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
		held_object = null

	# Throw
	if Input.is_action_just_pressed("p2_throw") and holding:
		# Lança a pedra
		holding = false
		# Move rock to hand position first
		held_object.move_to(hand_position.global_position)
		held_object.get_node("CollisionShape2D").position = Vector2(0, 0)
		# Lança na direção do movimento
		held_object.linear_velocity = Vector2(velocity.x * 2, -200)
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
		held_object = null


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
