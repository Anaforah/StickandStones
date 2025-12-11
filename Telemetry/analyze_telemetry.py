#!/usr/bin/env python3
"""
Telemetry Log Analysis Tool
Analyzes gameplay telemetry CSV files from StickandStones

Usage:
    python3 analyze_telemetry.py telemetry_log.csv
"""

import csv
import sys
from collections import defaultdict
from datetime import datetime

class TelemetryAnalyzer:
    def __init__(self, csv_file):
        self.csv_file = csv_file
        self.data = []
        self.load_data()
    
    def load_data(self):
        """Load CSV data from file"""
        try:
            with open(self.csv_file, 'r') as f:
                reader = csv.DictReader(f)
                self.data = list(reader)
            print(f"✓ Loaded {len(self.data)} telemetry entries")
        except FileNotFoundError:
            print(f"✗ File not found: {self.csv_file}")
            sys.exit(1)
    
    def get_summary(self):
        """Print summary statistics"""
        if not self.data:
            print("No data to analyze")
            return
        
        print("\n" + "="*60)
        print("TELEMETRY SUMMARY")
        print("="*60)
        
        # Time span
        first_time = self.data[0]['datetime']
        last_time = self.data[-1]['datetime']
        print(f"Session Duration: {first_time} → {last_time}")
        print(f"Total Events: {len(self.data)}")
        
        # Events by type
        event_types = defaultdict(int)
        for entry in self.data:
            event_types[entry['eventType']] += 1
        
        print(f"\nEvent Types:")
        for etype, count in sorted(event_types.items()):
            print(f"  {etype}: {count}")
        
        # Events by player
        player_events = defaultdict(int)
        for entry in self.data:
            player_events[entry['playerID']] += 1
        
        print(f"\nEvents by Player:")
        for player, count in sorted(player_events.items()):
            print(f"  Player {player}: {count}")
    
    def get_action_timeline(self, player_id=None):
        """Print timeline of player actions"""
        print("\n" + "="*60)
        print(f"ACTION TIMELINE{' - Player ' + str(player_id) if player_id else ''}")
        print("="*60)
        
        actions = [e for e in self.data if e['eventType'] == 'action']
        if player_id:
            actions = [e for e in actions if e['playerID'] == str(player_id)]
        
        for entry in actions:
            payload = f" ({entry['payload']})" if entry['payload'] else ""
            print(f"[{entry['datetime']}] P{entry['playerID']}: {entry['eventName']}{payload}")
    
    def get_state_changes(self, player_id=None):
        """Print all state changes"""
        print("\n" + "="*60)
        print(f"STATE CHANGES{' - Player ' + str(player_id) if player_id else ''}")
        print("="*60)
        
        states = [e for e in self.data if e['eventType'] == 'state']
        if player_id:
            states = [e for e in states if e['playerID'] == str(player_id)]
        
        for entry in states:
            print(f"[{entry['datetime']}] P{entry['playerID']}: {entry['eventName']}")
    
    def get_events(self, event_name=None, player_id=None):
        """Get all events, optionally filtered"""
        print("\n" + "="*60)
        print(f"GAME EVENTS{' - ' + event_name if event_name else ''}{' - Player ' + str(player_id) if player_id else ''}")
        print("="*60)
        
        events = [e for e in self.data if e['eventType'] == 'event']
        
        if event_name:
            events = [e for e in events if event_name.lower() in e['eventName'].lower()]
        if player_id:
            events = [e for e in events if e['playerID'] == str(player_id)]
        
        for entry in events:
            payload = f" ({entry['payload']})" if entry['payload'] else ""
            print(f"[{entry['datetime']}] P{entry['playerID']}: {entry['eventName']}{payload}")
    
    def get_object_events(self):
        """Get all object-related events"""
        print("\n" + "="*60)
        print("OBJECT INTERACTIONS")
        print("="*60)
        
        object_keywords = ['spawn', 'grab', 'drop', 'use', 'transfer', 'received']
        
        for entry in self.data:
            event_name = entry['eventName'].lower()
            if any(keyword in event_name for keyword in object_keywords):
                payload = f" - {entry['payload']}" if entry['payload'] else ""
                event_type = entry['eventType']
                print(f"[{entry['datetime']}] P{entry['playerID']}: [{event_type}] {entry['eventName']}{payload}")
    
    def get_position_range(self, player_id):
        """Get position stats for a player"""
        print("\n" + "="*60)
        print(f"POSITION ANALYSIS - Player {player_id}")
        print("="*60)
        
        positions = [e for e in self.data if e['playerID'] == str(player_id)]
        
        if not positions:
            print(f"No position data for Player {player_id}")
            return
        
        x_values = [float(e['posX']) for e in positions]
        y_values = [float(e['posY']) for e in positions]
        
        print(f"X Range: {min(x_values):.1f} → {max(x_values):.1f}")
        print(f"Y Range: {min(y_values):.1f} → {max(y_values):.1f}")
        print(f"Avg X: {sum(x_values)/len(x_values):.1f}")
        print(f"Avg Y: {sum(y_values)/len(y_values):.1f}")
    
    def get_event_count_by_name(self):
        """Count events by name"""
        print("\n" + "="*60)
        print("EVENT FREQUENCY")
        print("="*60)
        
        event_counts = defaultdict(int)
        for entry in self.data:
            event_counts[entry['eventName']] += 1
        
        for event, count in sorted(event_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"  {event}: {count}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_telemetry.py <csv_file>")
        sys.exit(1)
    
    analyzer = TelemetryAnalyzer(sys.argv[1])
    
    # Display analysis
    analyzer.get_summary()
    analyzer.get_event_count_by_name()
    analyzer.get_action_timeline()
    analyzer.get_state_changes()
    analyzer.get_object_events()
    analyzer.get_position_range(1)
    analyzer.get_position_range(2)
    
    print("\n" + "="*60)
    print("Analysis complete!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
