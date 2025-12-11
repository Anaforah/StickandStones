# Telemetry Integration Examples
# 
# This file shows how to integrate telemetry logging into various game systems.
# Copy and adapt these code snippets into your existing scripts.

# ============================================
# ROULETTE/SPINNER INTEGRATION (roleta.gd)
# ============================================

# Add to your roleta.gd script:

func _ready():
	telemetry = get_tree().root.get_child(0).get_node_or_null("TelemetryManager")
	if telemetry == null:
		telemetry = get_node_or_null("/root/TelemetryManager")

func spin():
	# Log roulette spin as an action
	if telemetry:
		telemetry.log_action(1, "pressbutton", "roulette")
	
	# ... rest of your spin logic


# ============================================
# OBJECT EFFECT INTEGRATION (object_rock.gd)
# ============================================

# Add to your object_rock.gd script:

func _ready():
	telemetry = get_tree().root.get_child(0).get_node_or_null("TelemetryManager")
	if telemetry == null:
		telemetry = get_node_or_null("/root/TelemetryManager")

func apply_effect():
	# Determine which player triggered the effect
	var player_id = _get_closest_player()
	
	# Log the effect
	if telemetry:
		telemetry.log_event(player_id, "drillEffect", "groundHole")
	
	# ... rest of your effect logic


# ============================================
# ITEM USE INTEGRATION (Generic Item Script)
# ============================================

# Add this to any item/tool script when it's used:

func use_item():
	if telemetry and owner and "PLAYER_ID" in owner:
		telemetry.log_action(owner.PLAYER_ID, "use", self.item_name)
	
	# ... rest of your use logic


# ============================================
# ITEM TRANSFER INTEGRATION
# ============================================

# When transferring an item between players:

func transfer_item_to_player(from_player_id: int, to_player_id: int, item_name: String):
	if telemetry:
		# Log from the sending player's perspective
		telemetry.log_action(from_player_id, "transfer", item_name + "," + str(to_player_id))
		
		# Log from receiving player's perspective
		telemetry.log_event(to_player_id, "objectReceived", item_name)


# ============================================
# SCENARIO/ROOM EFFECT INTEGRATION (scenari.gd)
# ============================================

# Add to your scenari.gd script:

func _ready():
	telemetry = get_tree().root.get_child(0).get_node_or_null("TelemetryManager")
	if telemetry == null:
		telemetry = get_node_or_null("/root/TelemetryManager")

func apply_room_effect(effect_type: String, player_affected: int):
	if telemetry:
		telemetry.log_event(player_affected, "roomAffected", effect_type)
	
	# ... rest of your effect logic

func on_explosion():
	# Log explosion effect to both players
	if telemetry:
		telemetry.log_event(1, "roomAffected", "explosion")
		telemetry.log_event(2, "roomAffected", "explosion")


# ============================================
# HEALTH/DAMAGE INTEGRATION
# ============================================

# Add to your player scripts when health changes:

func take_damage(damage: int):
	health -= damage
	
	if telemetry:
		telemetry.update_player_health(PLAYER_ID, health)
		telemetry.log_event(PLAYER_ID, "damage", str(damage))
	
	# ... rest of your damage logic

func heal(amount: int):
	health = min(health + amount, 100)
	
	if telemetry:
		telemetry.update_player_health(PLAYER_ID, health)
		telemetry.log_event(PLAYER_ID, "heal", str(amount))


# ============================================
# GAME STATE EVENTS
# ============================================

# Add to your game manager/main scene:

func on_game_start():
	if telemetry:
		telemetry.log_event(1, "gameStart", "")
		telemetry.log_event(2, "gameStart", "")

func on_game_end(winner: int):
	if telemetry:
		telemetry.log_event(winner, "gameEnd", "winner")
		telemetry.log_event(3 - winner, "gameEnd", "loser")

func on_round_complete():
	if telemetry:
		telemetry.log_event(1, "roundComplete", "")
		telemetry.log_event(2, "roundComplete", "")
