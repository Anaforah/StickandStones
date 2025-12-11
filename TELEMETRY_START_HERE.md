# 🎮 Telemetry - 30 Second Quick Start

## ✅ It's Already Working!

When you **open your game**, telemetry automatically:
- ✅ Starts recording
- ✅ Logs all player actions
- ✅ Saves to CSV file
- ✅ Ready for analysis

## 🎯 Three Ways to Use It

### 1️⃣ **Live Dashboard** (Easiest)
Press **F12** while playing → See real-time stats

### 2️⃣ **CSV Analysis** (After playing)
Find file at: `user://telemetry_log.csv`
- Open in Excel/Google Sheets
- Or use Python: `python3 analyze_telemetry.py telemetry_log.csv`

### 3️⃣ **Custom Events** (Optional)
Add to any script:
```gdscript
var telemetry = get_tree().root.get_node_or_null("TelemetryManager")
telemetry.log_action(player_id, "event_name", "data")
```

## 📋 That's It!

Everything is automatically logging your gameplay. Just play and enjoy! 🎮

---

**More info?** Read `README_TELEMETRY.md` for complete details.
