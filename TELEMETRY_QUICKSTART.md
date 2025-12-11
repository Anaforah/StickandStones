# Telemetry System - Quick Reference

## 🎮 In-Game Usage
**Press F12 to open/close the telemetry analysis dashboard**

The dashboard shows:
- Total events recorded
- Player statistics and current states
- Recent 5 events in real-time
- CSV file location

## 📊 What Gets Logged

### Automatically Logged:
- ✅ Player positions (every frame)
- ✅ Jump actions
- ✅ Item grabs and state changes
- ✅ Player spawns
- ✅ Object spawns
- ✅ Health updates

### Example Events:
```
Player 1 grabs a drill at position (152.3, 22.0)
Player 2 receives a fireextinguisher
Room affected by explosion
```

## 📁 CSV Output

**Location:** `user://telemetry_log.csv`  
**On macOS:** `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`

**Example Row:**
```
1,152.3,22.0,100,none,1,2,20251212143001,action,pressbutton,roulette
```

**Format:** playerID, posX, posY, health, stateVars, sceneID, playerCount, datetime, eventType, eventName, payload

## 🔧 Adding Custom Telemetry

To log custom events, use the TelemetryManager in your scripts:

```gdscript
# Get reference to telemetry manager
var telemetry = get_tree().root.get_node_or_null("TelemetryManager")

# Log an action (player input)
telemetry.log_action(player_id, "action_name", "optional_payload")

# Log an event (game state change)
telemetry.log_event(player_id, "event_name", "optional_payload")

# Log a state change
telemetry.log_state(player_id, "state_name", "optional_payload")

# Update player data
telemetry.update_player_position(player_id, position)
telemetry.update_player_health(player_id, health_value)
```

## 📈 Analysis Options

### Option 1: In-Game Dashboard
Press F12 during gameplay to see live statistics and recent events.

### Option 2: Python Script
```bash
python3 analyze_telemetry.py telemetry_log.csv
```

### Option 3: Manual Inspection
Open telemetry_log.csv in Excel, Google Sheets, or a text editor.

## 🚀 Starting the Game

The telemetry system **starts automatically** when you open the game:
1. Game launches
2. TelemetryManager autoload initializes
3. CSV file is created/overwritten
4. Logging begins immediately
5. Press F12 anytime to view the analysis dashboard

## 📝 Files Created

- `telemetry_manager.gd` - Core logging system (autoload)
- `telemetry_analyzer_ui.gd` - In-game dashboard (autoload)
- `telemetry_log.csv` - Generated CSV file with all logs
- `analyze_telemetry.py` - Python analysis tool
- `TELEMETRY_GUIDE.md` - Detailed documentation
- `TELEMETRY_INTEGRATION_EXAMPLES.md` - Code examples
- `IN_GAME_TELEMETRY.md` - In-game features guide

## ⌨️ Keyboard Shortcut

| Key | Action |
|-----|--------|
| F12 | Toggle telemetry analysis panel |

## 🎯 Next Steps

1. Open the game - telemetry auto-starts
2. Play normally - events are being logged
3. Press F12 - see live analysis
4. After playing, find CSV in user directory for detailed analysis
5. Use Python script for comprehensive reports

---
**Pro Tip:** Keep the telemetry panel open (F12) while playing to see events in real-time!
