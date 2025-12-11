# In-Game Telemetry Analysis System

## Overview
The telemetry system now starts automatically when you open the game and provides a real-time analysis dashboard accessible with **F12**.

## Features

### Automatic Recording
- ✅ Starts automatically on game launch
- ✅ Logs all player actions, events, and state changes
- ✅ Saves to CSV file at: `user://telemetry_log.csv`
- ✅ Records continuously throughout gameplay

### Real-Time Analysis Dashboard (Press F12)
The dashboard displays:

1. **SESSION INFO**
   - Total events recorded
   - First and last timestamps
   - CSV file location

2. **PLAYER STATS**
   - Event count per player
   - Current state (what item they're holding)
   - Current position (X, Y coordinates)

3. **RECENT EVENTS**
   - Last 5 events in chronological order
   - Timestamp, player, event type, event name, and payload
   - Updates in real-time

## How to Use

### During Gameplay
1. **Open the Analysis Panel**: Press **F12**
2. **View Live Data**: See real-time stats and recent events
3. **Close the Panel**: Press **F12** again

### CSV File Location
The telemetry data is saved to your user directory:
- **macOS**: `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`
- Can be opened with Excel, Google Sheets, or any text editor

### Analyzing the Data

#### Option 1: Using the In-Game Dashboard (Recommended for quick checks)
- Press F12 during or after gameplay
- View real-time statistics and recent events

#### Option 2: Using Python Analysis (For detailed reports)
```bash
python3 analyze_telemetry.py telemetry_log.csv
```

#### Option 3: Manual CSV Analysis
- Open the CSV file in Excel or Google Sheets
- Sort and filter by eventType, eventName, playerID, etc.
- Create pivot tables for analysis

## CSV Format Reference

```csv
playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload
1,152.3,22.0,100,none,1,2,20251212143001,action,pressbutton,roulette
```

### Columns:
- **playerID**: 1 or 2 (which player)
- **posX, posY**: Player position coordinates
- **health**: Player health value
- **stateVars**: Current held item (none, drill, fireextinguisher, etc)
- **sceneID**: Scene/level identifier
- **playerCount**: Number of players (always 2)
- **datetime**: Timestamp in YYYYMMDDHHmmss format
- **eventType**: action | event | state
- **eventName**: What happened (jump, grab, objectSpawn, etc)
- **payload**: Additional data

## Event Types

### Actions (Player Input/Interactions)
```
pressbutton, roulette
jump
grab, <item_name>
drop, <item_name>
use, <item_name>
transfer, <item_name>,<target_player>
```

### Events (Game State Changes)
```
playerSpawn
objectSpawn, <object_name>
objectReceived, <object_name>
drillEffect, groundHole
roomAffected, explosion
damage, <amount>
heal, <amount>
gameStart
gameEnd, winner|loser
```

### State Changes
```
drill
fireextinguisher
none
```

## Example Workflow

1. **Start the game**
   - Telemetry automatically begins recording

2. **Play normally**
   - All actions and events are logged in real-time

3. **Press F12 anytime**
   - View session statistics
   - Check player states and positions
   - See recent events

4. **After gameplay**
   - CSV file is automatically saved
   - Use Python script for detailed analysis
   - Or manually inspect the CSV file

## Integration Notes

### Already Integrated:
- ✅ Player movement tracking
- ✅ Jump actions
- ✅ Item interactions (grab/drop)
- ✅ Real-time analysis dashboard

### Ready for Integration (Optional):
- Roulette spin events
- Item use effects
- Damage/healing events
- Room scenario effects
- Game win/lose events

See `TELEMETRY_INTEGRATION_EXAMPLES.md` for integration examples.

## Troubleshooting

**Q: F12 panel doesn't appear**
- Check that telemetry_analyzer_ui.gd is in the root of your project
- Verify project.godot has the TelemetryAnalyzerUI autoload

**Q: No data shows in the panel**
- Play the game for a few seconds to generate events
- Check that telemetry_manager.gd is properly initialized
- Verify the CSV file exists in the user folder

**Q: CSV file is empty or missing**
- Check that telemetry_manager.gd is running as an autoload
- Look in: ~/Library/Application Support/Godot/app_userdata/StickandStones/
- Ensure the game ran to completion (doesn't get cut off)

**Q: Where is the telemetry file saved?**
- Use the path shown in the F12 analysis panel
- On macOS: `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`

## Performance Impact
- Minimal overhead (CSV writes are buffered)
- Panel update rate is tied to _process() function
- Toggle F12 to disable panel updates if performance is critical

## Future Enhancements
- Export to JSON format
- Real-time graphs and charts
- Event filtering and search
- Heatmaps of player positions
- Performance metrics
