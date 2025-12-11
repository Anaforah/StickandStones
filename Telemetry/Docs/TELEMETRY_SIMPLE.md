# ✅ Simple CSV Telemetry System - Ready!

**No dashboard. No complications. Just a CSV file.**

## How It Works

When you open the game:
1. ✅ Telemetry starts automatically
2. ✅ All gameplay data is logged
3. ✅ CSV file is saved at: `user://telemetry_log.csv`

## CSV Format

```
playerID,posX,posY,health,stateVars,sceneID,playerCount,datetime,eventType,eventName,payload
1,152.3,22.0,100,none,1,2,20251212143001,action,pressbutton,roulette
1,152.3,22.0,100,drill,1,2,20251212143003,action,grab,drill
2,18.4,88.2,100,fireextinguisher,1,2,20251212147011,event,roomAffected,explosion
```

## What Gets Logged Automatically

- Player positions
- Jump actions
- Item grabs
- State changes
- Player spawns
- Object interactions

## File Location

**On macOS:** `~/Library/Application Support/Godot/app_userdata/StickandStones/telemetry_log.csv`

Open it in Excel, Google Sheets, or any text editor.

## That's It!

Just play your game. The CSV file records everything. Done! 🎮
