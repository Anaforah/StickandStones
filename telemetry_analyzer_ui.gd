extends Control

## In-Game Telemetry Analysis Dashboard
## Press F12 to toggle the telemetry panel

class_name TelemetryAnalyzer

var telemetry: TelemetryManager
var is_visible: bool = false
var analysis_data: Dictionary = {}

func _ready():
	# Get telemetry manager reference
	telemetry = get_tree().root.get_node_or_null("TelemetryManager")
	if telemetry == null:
		telemetry = get_node_or_null("/root/TelemetryManager")
	
	# Create UI for analysis
	_create_ui()
	
	# Initially hidden
	hide()
	print("Telemetry Analyzer loaded. Press F12 to toggle analysis panel.")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_panel()
		get_tree().root.get_child(0).get_viewport().set_input_as_handled()

func _create_ui():
	# Create a PanelContainer for the analysis display
	var panel = PanelContainer.new()
	panel.name = "TelemetryPanel"
	add_child(panel)
	
	# Setup panel styling
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.4
	panel.anchor_bottom = 1.0
	panel.offset_left = 10
	panel.offset_top = 10
	panel.offset_right = -10
	panel.offset_bottom = -10
	
	# Add a VBoxContainer for content
	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "TELEMETRY ANALYSIS"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	# Add separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Create tabs/sections
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(scroll)
	
	var content = VBoxContainer.new()
	content.name = "ScrollContent"
	scroll.add_child(content)
	
	# Session info section
	var session_label = Label.new()
	session_label.text = "SESSION INFO"
	session_label.add_theme_font_size_override("font_size", 14)
	content.add_child(session_label)
	
	var session_content = Label.new()
	session_content.name = "SessionInfo"
	session_content.text = "Loading..."
	session_content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(session_content)
	
	# Player stats section
	var player_label = Label.new()
	player_label.text = "PLAYER STATS"
	player_label.add_theme_font_size_override("font_size", 14)
	content.add_child(player_label)
	
	var player_content = Label.new()
	player_content.name = "PlayerStats"
	player_content.text = "Waiting for data..."
	player_content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(player_content)
	
	# Events section
	var events_label = Label.new()
	events_label.text = "RECENT EVENTS"
	events_label.add_theme_font_size_override("font_size", 14)
	content.add_child(events_label)
	
	var events_content = Label.new()
	events_content.name = "RecentEvents"
	events_content.text = "No events yet..."
	events_content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(events_content)
	
	# Add bottom info
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	var info = Label.new()
	info.text = "Press F12 to close\nFile: " + telemetry.get_telemetry_file_path()
	info.add_theme_font_size_override("font_size", 10)
	info.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(info)

func toggle_panel():
	is_visible = !is_visible
	if is_visible:
		show()
		_update_analysis()
	else:
		hide()

func _process(_delta):
	if is_visible:
		_update_analysis()

func _update_analysis():
	_read_telemetry_file()
	_update_session_info()
	_update_player_stats()
	_update_recent_events()

func _read_telemetry_file():
	"""Read and parse the telemetry CSV file"""
	var file = FileAccess.open(telemetry.get_telemetry_file_path(), FileAccess.READ)
	
	if file == null:
		return
	
	analysis_data.clear()
	analysis_data["entries"] = []
	analysis_data["player_1_events"] = 0
	analysis_data["player_2_events"] = 0
	analysis_data["event_types"] = {}
	analysis_data["player_states"] = {1: "none", 2: "none"}
	analysis_data["recent_entries"] = []
	
	var line_count = 0
	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty() or line_count == 0:  # Skip header
			line_count += 1
			continue
		
		var parts = line.split(",")
		if parts.size() < 11:
			continue
		
		var entry = {
			"playerID": parts[0],
			"posX": parts[1],
			"posY": parts[2],
			"health": parts[3],
			"stateVars": parts[4],
			"sceneID": parts[5],
			"playerCount": parts[6],
			"datetime": parts[7],
			"eventType": parts[8],
			"eventName": parts[9],
			"payload": parts[10] if parts.size() > 10 else ""
		}
		
		analysis_data["entries"].append(entry)
		
		# Update stats
		if entry["playerID"] == "1":
			analysis_data["player_1_events"] += 1
		elif entry["playerID"] == "2":
			analysis_data["player_2_events"] += 1
		
		# Track event types
		var etype = entry["eventType"]
		if etype not in analysis_data["event_types"]:
			analysis_data["event_types"][etype] = 0
		analysis_data["event_types"][etype] += 1
		
		# Track player states
		if entry["eventType"] == "state":
			analysis_data["player_states"][int(entry["playerID"])] = entry["eventName"]
		
		# Keep last 5 entries
		analysis_data["recent_entries"].append(entry)
		if analysis_data["recent_entries"].size() > 5:
			analysis_data["recent_entries"].pop_front()
		
		line_count += 1

func _update_session_info():
	"""Update session info display"""
	if analysis_data.is_empty() or analysis_data["entries"].is_empty():
		_get_node_safe("SessionInfo").text = "No data recorded yet"
		return
	
	var first = analysis_data["entries"][0]
	var last = analysis_data["entries"][-1]
	var total = analysis_data["entries"].size()
	
	var text = "Total Events: %d\n" % total
	text += "First: %s\n" % first["datetime"]
	text += "Last: %s\n" % last["datetime"]
	text += "File: %s" % telemetry.get_telemetry_file_path()
	
	_get_node_safe("SessionInfo").text = text

func _update_player_stats():
	"""Update player statistics display"""
	var p1_events = analysis_data.get("player_1_events", 0)
	var p2_events = analysis_data.get("player_2_events", 0)
	var p1_state = analysis_data.get("player_states", {1: "none"}).get(1, "none")
	var p2_state = analysis_data.get("player_states", {2: "none"}).get(2, "none")
	
	var text = "Player 1:\n"
	text += "  Events: %d\n" % p1_events
	text += "  State: %s\n" % p1_state
	text += "  Pos: (%.1f, %.1f)\n\n" % [telemetry.player_positions[1].x, telemetry.player_positions[1].y]
	text += "Player 2:\n"
	text += "  Events: %d\n" % p2_events
	text += "  State: %s\n" % p2_state
	text += "  Pos: (%.1f, %.1f)" % [telemetry.player_positions[2].x, telemetry.player_positions[2].y]
	
	_get_node_safe("PlayerStats").text = text

func _update_recent_events():
	"""Update recent events display"""
	var recent = analysis_data.get("recent_entries", [])
	
	if recent.is_empty():
		_get_node_safe("RecentEvents").text = "No events yet"
		return
	
	var text = ""
	for entry in recent:
		var payload = " [%s]" % entry["payload"] if not entry["payload"].is_empty() else ""
		text += "[%s] P%s %s: %s%s\n" % [
			entry["datetime"],
			entry["playerID"],
			entry["eventType"],
			entry["eventName"],
			payload
		]
	
	_get_node_safe("RecentEvents").text = text

func _get_node_safe(node_name: String) -> Label:
	"""Safely get a node by name"""
	var node = get_node_or_null("PanelContainer/Content/ScrollContainer/ScrollContent/" + node_name)
	if node == null:
		# Create a placeholder if not found
		var placeholder = Label.new()
		placeholder.name = node_name
		placeholder.text = "Panel not initialized"
		return placeholder
	return node
