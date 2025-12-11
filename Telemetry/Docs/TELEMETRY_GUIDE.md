# Gameplay Telemetry Logging System

## Overview
This telemetry system logs all player actions, events, and state changes into a CSV file for gameplay analysis.

## CSV Format
```
playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload
```

### Fields:
- **playerID**: Player identifier (1 or 2)
- **posX**: Player X position
- **posY**: Player Y position
- **health**: Player health value
- **stateVars**: Current player state (e.g., "none", "drill", "fireextinguisher")
- **sceneID**: Current scene identifier
- **playerCount**: Total number of players in the session
- **datetime**: Timestamp in format YYYYMMDDHHmmss
- **eventType**: Type of log entry ("action", "event", or "state")
- **eventName**: Name of the action/event
- **payload**: Additional data for the action/event

## Log File Location
- Default: `user://telemetry_log.csv`
- On macOS: `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`

## Usage Examples

### In Player Scripts
```gdscript
# Log a jump action
if telemetry:
    telemetry.log_action(PLAYER_ID, "jump", "")

# Log button press
if telemetry:
    telemetry.log_action(PLAYER_ID, "pressbutton", "roulette")

# Update player position (called continuously)
if telemetry:
    telemetry.update_player_position(PLAYER_ID, global_position)

# Update player health
if telemetry:
    telemetry.update_player_health(PLAYER_ID, new_health)
```

### In Item/Object Scripts
```gdscript
# Log item spawn
if telemetry:
    telemetry.log_event(closest_player, "objectSpawn", "drill")

# Log item grab
if telemetry:
    telemetry.log_action(player_id, "grab", "drill")

# Log item use
if telemetry:
    telemetry.log_action(player_id, "use", "drill")

# Log item transfer between players
if telemetry:
    telemetry.log_action(player_id, "transfer", "drill,player2")
```

### In Game Manager/Scenario Scripts
```gdscript
# Log game events
if telemetry:
    telemetry.log_event(player_id, "drillEffect", "groundHole")
    telemetry.log_event(player_id, "roomAffected", "explosion")
    telemetry.log_event(player_id, "objectReceived", "fireextinguisher")
```

## Example CSV Output
```csv
playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload
1,152.3,22.0,100,none,1,2,20251212143001,action,pressbutton,roulette
1,152.3,22.0,100,none,1,2,20251212143002,event,objectSpawn,drill
1,152.3,22.0,100,drill,1,2,20251212143003,action,grab,drill
1,160.4,22.0,100,drill,1,2,20251212143030,action,use,drill
1,160.4,22.0,100,drill,1,2,20251212145005,event,drillEffect,groundHole
1,165.1,22.0,100,drill,1,2,20251212146007,action,transfer,drill,player2
2,18.4,88.2,100,none,1,2,20251212146010,event,objectReceived,fireextinguisher
2,18.4,88.2,100,fireextinguisher,1,2,20251212147011,event,roomAffected,explosion
```

## Integration Points

### Already Implemented:
1. ✅ Player movement tracking (player_1.gd, player_2.gd)
2. ✅ Jump actions (player_1.gd, player_2.gd)
3. ✅ Item grab/drop interactions (item_fall.gd)
4. ✅ Autoload initialization (project.godot)

### To Implement (Optional):
1. Damage/health change events (in player scripts or health system)
2. Item use effects (in item/tool scripts)
3. Room/scenario state changes (in scenari.gd)
4. Game completion/failure events (in game manager)
5. Roulette spin events (in roleta.gd)

## Telemetry Manager API

### Log Methods:
```gdscript
# Log an action (player input/interaction)
telemetry.log_action(player_id: int, action_name: String, payload: String = "")

# Log an event (game state change)
telemetry.log_event(player_id: int, event_name: String, payload: String = "")

# Log a state change
telemetry.log_state(player_id: int, state_name: String, payload: String = "")
```

### Data Update Methods:
```gdscript
# Update player position
telemetry.update_player_position(player_id: int, position: Vector2)

# Update player health
telemetry.update_player_health(player_id: int, health: int)
```

### Control Methods:
```gdscript
# Start/stop recording
telemetry.start_recording()
telemetry.stop_recording()

# Get file path for manual inspection
var path = telemetry.get_telemetry_file_path()
```

## Analysis Examples

### Common Queries:
```python
# Python example for CSV analysis
import pandas as pd

# Load telemetry data
df = pd.read_csv("telemetry_log.csv")

# All actions by player 1
p1_actions = df[df['playerID'] == 1][df['eventType'] == 'action']

# Timeline of drill usage
drill_events = df[df['stateVars'] == 'drill']

# Count object spawns
object_spawns = df[df['eventName'] == 'objectSpawn']['payload'].value_counts()

# Player positions over time
positions = df[['datetime', 'playerID', 'posX', 'posY']]
```

## Notes
- Telemetry recording starts automatically on game launch
- Automatically stops and flushes on game exit
- Position updates happen every frame (use sparingly in analysis if needed)
- State changes are logged when they occur
- All timestamps are in YYYYMMDDHHmmss format (UTC)
