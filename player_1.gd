extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var is_in_range: bool = false
var target_object: RigidBody2D = null
var holding := false

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

	# Segurando objeto
	if holding and target_object:
		# Mantém pedra na mão
		target_object.freeze = true         # congela física enquanto segura
		target_object.move_to(hand_position.global_position)


func _process(_delta: float) -> void:
	# Pegar ou soltar
	if is_in_range and target_object:
		if Input.is_action_just_pressed("p1_grab") and not holding:
			# Pega a pedra
			holding = true
			target_object.freeze = true       # congela física
			target_object.move_to(hand_position.global_position)

		elif Input.is_action_just_released("p1_grab") and holding:
			# Solta a pedra
			holding = false
			target_object.freeze = false      # libera física
			# Pedra cai no chão mantendo posição atual
			target_object.move_to(hand_position.global_position)


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
