extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const PLAYER_ID = 2

var telemetry
var health: int = 100
var current_item: String = "none"

func _ready():
	# Get reference to telemetry manager (autoload)
	telemetry = get_node_or_null("/root/TelemetryManager")
	
	# Log player spawn
	if telemetry:
		telemetry.log_event(PLAYER_ID, "playerSpawn", "")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("p2_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if telemetry:
			telemetry.log_action(PLAYER_ID, "jump", "")

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("p2_move_left", "p2_move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Update telemetry position
	if telemetry:
		telemetry.update_player_position(PLAYER_ID, global_position)

	move_and_slide()
