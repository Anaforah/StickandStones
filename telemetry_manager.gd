extends Node

## Gameplay Telemetry Logging System
## Tracks player actions, events, and state changes in CSV format
## 
## Format: playerID, posX, posY, health, stateVars, sceneID, playerCount, datetime, eventType, eventName, payload

class_name TelemetryManager

# Telemetry file path
var telemetry_file_path: String = "user://telemetry_log.csv"
var telemetry_file: FileAccess

# Current session data
var player_id: int = 0
var session_start_time: int = 0
var is_recording: bool = false

# Player positions cache (for multi-player logging)
var player_positions: Dictionary = {1: Vector2.ZERO, 2: Vector2.ZERO}
var player_health: Dictionary = {1: 100, 2: 100}
var player_state_vars: Dictionary = {1: "none", 2: "none"}

func _ready():
	session_start_time = Time.get_ticks_msec()
	initialize_telemetry()
	if not is_recording:
		start_recording()

## Initialize telemetry system and CSV file
func initialize_telemetry() -> void:
	# Create or overwrite telemetry file with header
	telemetry_file = FileAccess.open(telemetry_file_path, FileAccess.WRITE)
	
	if telemetry_file:
		# Write CSV header
		var header = "playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload\n"
		telemetry_file.store_string(header)
		print("Telemetry initialized at: ", telemetry_file_path)
	else:
		print("Failed to initialize telemetry file at: ", telemetry_file_path)

## Start recording telemetry
func start_recording() -> void:
	is_recording = true
	print("Telemetry recording started")

## Stop recording telemetry
func stop_recording() -> void:
	is_recording = false
	if telemetry_file:
		telemetry_file = null
	print("Telemetry recording stopped")

## Get current timestamp in format: YYYYMMDDHHmmss
func get_current_timestamp() -> String:
	var time_dict = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d%02d%02d%02d" % [
		time_dict.year,
		time_dict.month,
		time_dict.day,
		time_dict.hour,
		time_dict.minute,
		time_dict.second
	]

## Log an action (player input/interaction)
## Example: log_action(1, "pressbutton", "roulette")
func log_action(player_id: int, action_name: String, payload: String = "") -> void:
	if not is_recording:
		return
	
	_log_event(player_id, "action", action_name, payload)

## Log an event (game state change)
## Example: log_event(1, "objectSpawn", "drill")
func log_event(player_id: int, event_name: String, payload: String = "") -> void:
	if not is_recording:
		return
	
	_log_event(player_id, "event", event_name, payload)

## Log a state change
## Example: log_state(1, "drill")
func log_state(player_id: int, state_name: String, payload: String = "") -> void:
	if not is_recording:
		return
	
	# Update player state vars
	player_state_vars[player_id] = state_name
	_log_event(player_id, "state", state_name, payload)

## Internal method to write telemetry entry to CSV
func _log_event(player_id: int, event_type: String, event_name: String, payload: String = "") -> void:
	if not telemetry_file:
		return
	
	# Get player position
	var pos_x = player_positions[player_id].x if player_positions.has(player_id) else 0.0
	var pos_y = player_positions[player_id].y if player_positions.has(player_id) else 0.0
	
	# Get player health
	var health = player_health[player_id] if player_health.has(player_id) else 100
	
	# Get player state vars
	var state_vars = player_state_vars[player_id] if player_state_vars.has(player_id) else "none"
	
	# Get current scene (assuming single scene or simple scene tracking)
	var scene_id = 1  # Can be updated based on current scene
	var player_count = 2  # Your game has 2 players
	
	# Get current timestamp
	var timestamp = get_current_timestamp()
	
	# Format CSV line
	var csv_line = "%d,%.1f,%.1f,%d,%s,%d,%d,%s,%s,%s,%s\n" % [
		player_id,
		pos_x,
		pos_y,
		health,
		state_vars,
		scene_id,
		player_count,
		timestamp,
		event_type,
		event_name,
		payload
	]
	
	# Write to file
	telemetry_file.store_string(csv_line)

## Update player position (call from player scripts)
func update_player_position(player_id: int, position: Vector2) -> void:
	player_positions[player_id] = position

## Update player health (call from player scripts)
func update_player_health(player_id: int, health: int) -> void:
	player_health[player_id] = health

## Get telemetry file path (for debugging/inspection)
func get_telemetry_file_path() -> String:
	return telemetry_file_path

## Close telemetry file properly
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if telemetry_file:
			stop_recording()
