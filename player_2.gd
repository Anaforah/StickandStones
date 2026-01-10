extends CharacterBody2D
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

const MAN_TEX: Texture2D = preload("res://Imagens/Man.png")
const MAN2_TEX: Texture2D = preload("res://Imagens/man2.png")
const MAN_JUMP_TEX: Texture2D = preload("res://Imagens/ManJump.png")

var walk_frame_timer: float = 0.0
var walk_frame_index: int = 0
const WALK_FRAME_INTERVAL: float = 0.18

func _ready() -> void:
	if sprite and sprite.texture == null:
		sprite.texture = MAN_TEX

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("p2_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if sprite:
			sprite.texture = MAN_JUMP_TEX

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("p2_move_left", "p2_move_right")
	if direction:
		velocity.x = direction * SPEED
		# Animate walking when on the floor
		if is_on_floor():
			walk_frame_timer += delta
			if walk_frame_timer >= WALK_FRAME_INTERVAL:
				walk_frame_timer = 0.0
				walk_frame_index = (walk_frame_index + 1) % 2
				if sprite:
					sprite.texture = (MAN2_TEX if walk_frame_index == 0 else MAN_TEX)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		# Idle frame when on floor
		if is_on_floor():
			if sprite:
				sprite.texture = MAN_TEX

	# While airborne, use jump texture
	if not is_on_floor():
		if sprite:
			sprite.texture = MAN_JUMP_TEX

	move_and_slide()
