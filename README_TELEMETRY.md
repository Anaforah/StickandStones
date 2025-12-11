# 🎮 TELEMETRY SYSTEM - READY TO USE

## What You Have

A complete **automatic gameplay telemetry logging system** that runs when your Godot game opens.

### Key Features:
- ✅ **Automatic** - Starts recording when game launches
- ✅ **Real-Time** - Press **F12** to view live analysis dashboard
- ✅ **CSV Export** - Logs saved to `user://telemetry_log.csv`
- ✅ **Multi-Player** - Tracks both Player 1 and Player 2
- ✅ **Extensible** - Easy to add custom events

---

## 🚀 How It Works

### When You Open the Game:
1. **TelemetryManager** autoload starts and creates the CSV file
2. **TelemetryAnalyzerUI** autoload loads the F12 dashboard
3. **Recording begins immediately** - nothing else needed
4. All player actions, events, and positions are logged

### Live Analysis Dashboard:
Press **F12** anytime to open a panel showing:
- Total events recorded
- Player 1 stats (events, state, position)
- Player 2 stats (events, state, position)
- Last 5 events in real-time
- CSV file location

---

## 📊 CSV Output Format

**File:** `user://telemetry_log.csv` (On macOS: ~/Library/Application Support/Godot/app_userdata/StickandStones/)

**Columns:**
```
playerID, posX, posY, health, stateVars, sceneID, playerCount, datetime, eventType, eventName, payload
```

**Example:**
```csv
1, 152.3, 22.0, 100, none, 1, 2, 20251212143001, action, pressbutton, roulette
1, 152.3, 22.0, 100, none, 1, 2, 20251212143002, event, objectSpawn, drill
1, 152.3, 22.0, 100, drill, 1, 2, 20251212143003, action, grab, drill
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `telemetry_manager.gd` | Core logging (Autoload) |
| `telemetry_analyzer_ui.gd` | F12 dashboard (Autoload) |
| `TELEMETRY_QUICKSTART.md` | Quick reference |
| `IN_GAME_TELEMETRY.md` | In-game features guide |
| `TELEMETRY_GUIDE.md` | Complete API documentation |
| `TELEMETRY_INTEGRATION_EXAMPLES.md` | Code examples for adding events |

---

## 🔧 Adding Custom Events

In any of your game scripts, add telemetry logging:

```gdscript
# Get the telemetry manager
var telemetry = get_tree().root.get_node_or_null("TelemetryManager")

# Log an action (player did something)
telemetry.log_action(player_id, "jump", "")
telemetry.log_action(player_id, "use", "drill")

# Log an event (game state changed)
telemetry.log_event(player_id, "objectSpawn", "drill")
telemetry.log_event(player_id, "drillEffect", "groundHole")

# Update player data
telemetry.update_player_position(player_id, position)
telemetry.update_player_health(player_id, health)
```

---

## 📈 Analysis Options

### Option 1: In-Game (Easiest) ⭐
**Press F12** during gameplay → See live statistics

### Option 2: Python Script
```bash
python3 analyze_telemetry.py telemetry_log.csv
```

### Option 3: Spreadsheet
1. Find CSV at: `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`
2. Open in Excel or Google Sheets
3. Sort/filter/analyze as needed

---

## ⌨️ Keyboard Controls

| Key | Action |
|-----|--------|
| **F12** | Toggle telemetry analysis panel |

---

## ✨ Already Integrated

The following are automatically being logged:
- ✅ Player positions (X, Y every frame)
- ✅ Jump actions
- ✅ Item grabs and drops
- ✅ State changes (item held)
- ✅ Player spawns
- ✅ Object spawns

---

## 🎯 Next Steps

1. **Open the game** → Telemetry starts automatically ✅
2. **Play normally** → Just play, everything is logged
3. **Press F12** → View live analysis
4. **After playing** → CSV file has all the data
5. **(Optional) Add custom events** → Use examples in `TELEMETRY_INTEGRATION_EXAMPLES.md`

---

## 📝 Example Workflow

**Scenario: Testing drill object behavior**

1. Start game → Telemetry recording begins
2. Player 1 grabs the drill → Logged as action
3. Player 2 receives the drill → Logged as event
4. Effects happen → Logged as events
5. Press F12 → See timeline of all interactions
6. Close game → CSV automatically saved
7. Open CSV → Analyze the complete sequence

---

## 🐛 Troubleshooting

**Q: F12 dashboard not appearing?**
- Ensure both scripts are in your project root
- Check project.godot has both autoloads configured
- Try restarting the game

**Q: No events showing in dashboard?**
- Play the game for a few seconds to generate events
- Press F12 after some gameplay

**Q: Where's the CSV file?**
- Check: `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`
- Or look at the path shown in the F12 panel

**Q: CSV seems empty?**
- File is created with header on startup
- Keep game running to generate events
- Events are buffered and written continuously

---

## 💡 Pro Tips

- Keep F12 panel open while playing to see events in real-time
- Use Python script for complex analysis and reports
- Use spreadsheet for sorting and filtering specific events
- Add custom events to any script using the Telemetry API

---

## 🎉 You're All Set!

The telemetry system is fully implemented and running. Just **open your game** and it will start logging automatically. Press **F12** to see the live analysis dashboard.

For more details, read:
- `TELEMETRY_QUICKSTART.md` - Quick reference
- `TELEMETRY_GUIDE.md` - Complete documentation
