Telemetry Folder

- telemetry_manager.gd: Autoload that writes gameplay telemetry to CSV in user://
- Docs/: Reference guides for telemetry usage
- analyze_telemetry.py (optional): Script to analyze CSV (no runtime dependency in game)

CSV Location
- macOS: ~/Library/Application Support/Godot/app_userdata/StickandStones/Test_1.csv

Change Output Filename
- Edit telemetry_manager.gd: var telemetry_file_path = "user://Test_1.csv"