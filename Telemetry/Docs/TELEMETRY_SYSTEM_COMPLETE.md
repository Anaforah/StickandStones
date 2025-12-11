# ✅ Gameplay Telemetry System - Implementation Complete

## 🎮 How to Use (Quick Start)

### When You Open the Game:
1. **Telemetry starts automatically** ✅
2. **Play the game normally** - all actions are being logged
3. **Press F12 anytime** - opens the analysis dashboard
4. **See real-time statistics**:
   - Total events recorded
   - Player positions and states
   - Last 5 events

### CSV File:
- Automatically saved to: `user://telemetry_log.csv`
- On macOS: `~/Library/Application Support/Godot/app_userdata/StickandStones/`
- Format matches your specification exactly

## 📊 What's Being Logged

### Automatically Captured:
✅ Player positions (X, Y coordinates)  
✅ Player health  
✅ Player state (holding item or "none")  
✅ Jump actions  
✅ Item grabs and state changes  
✅ Player spawns  
✅ Object spawns  

### CSV Format:
```
playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload
1,152.3,22.0,100,none,1,2,20251212143001,action,pressbutton,roulette
```

## 📁 Files Created

| File | Purpose |
|------|---------|
| `telemetry_manager.gd` | Core logging system (Autoload) |
| `telemetry_analyzer_ui.gd` | In-game F12 dashboard (Autoload) |
| `analyze_telemetry.py` | Python analysis tool (optional) |
| `TELEMETRY_QUICKSTART.md` | Quick reference guide |
| `IN_GAME_TELEMETRY.md` | Detailed in-game features |
| `TELEMETRY_GUIDE.md` | Complete API documentation |
| `TELEMETRY_INTEGRATION_EXAMPLES.md` | Code examples for custom events |

## 🔧 Easy Custom Logging

To add custom telemetry events to any script:

```gdscript
var telemetry = get_tree().root.get_node_or_null("TelemetryManager")

# Log actions
telemetry.log_action(player_id, "event_name", "payload")

# Log events
telemetry.log_event(player_id, "event_name", "payload")

# Update player data
telemetry.update_player_position(player_id, position)
telemetry.update_player_health(player_id, health)
```

See `TELEMETRY_INTEGRATION_EXAMPLES.md` for examples with roulette, items, and game events.

## 📈 Analysis Options

**Option 1: In-Game Dashboard** ⭐ Easiest
- Press F12 to see live stats and recent events

**Option 2: Python Analysis Script**
```bash
python3 analyze_telemetry.py telemetry_log.csv
```

**Option 3: Manual Analysis**
- Open CSV in Excel, Google Sheets, or any spreadsheet tool
- Sort/filter by any column

## 🚀 What Happens When Game Starts

1. TelemetryManager autoload initializes
2. CSV header is written: `playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload`
3. Recording begins immediately
4. TelemetryAnalyzerUI autoload loads (F12 available)
5. Game runs normally while logging in background
6. CSV continuously updated throughout gameplay
7. On game exit, file is properly closed

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **F12** | Toggle telemetry analysis panel |

## 📋 Example Telemetry Output

Based on your specification:
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

## ✨ Features

✅ **Automatic Recording** - Starts on game launch  
✅ **Real-Time Dashboard** - Press F12 for live stats  
✅ **CSV Output** - Standard format for analysis  
✅ **Multi-Player Support** - Tracks both Player 1 and 2  
✅ **Position Tracking** - X, Y coordinates logged  
✅ **State Management** - Tracks held items  
✅ **Health Monitoring** - Records player health  
✅ **Timestamp Precision** - YYYYMMDDHHmmss format  
✅ **Extensible API** - Easy to add custom events  

## 🎯 Next Steps

1. **Open your game** - telemetry auto-starts ✅
2. **Play normally** - events are logged ✅
3. **Press F12 anytime** - view analysis ✅
4. **Check CSV file** - for detailed data ✅
5. **(Optional) Add custom events** - use examples provided ✅

## 📚 Documentation

- **Quick Start**: Read `TELEMETRY_QUICKSTART.md`
- **In-Game Features**: Read `IN_GAME_TELEMETRY.md`
- **Full API Reference**: Read `TELEMETRY_GUIDE.md`
- **Integration Examples**: Read `TELEMETRY_INTEGRATION_EXAMPLES.md`

---

**The telemetry system is ready to use!** Just open your game and press F12 to see it in action. 🎮
