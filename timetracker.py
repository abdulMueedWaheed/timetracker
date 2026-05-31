#!/usr/bin/env python3

import os
import sqlite3
from datetime import datetime
import argparse
import datetime
from datetime import timedelta, datetime

DB_PATH = os.path.expanduser("~/.local/share/timetracker/usage.db")

parser = argparse.ArgumentParser(description="Simple Python Utility to show how much time you spent on each app!")
parser.add_argument("command", choices=["stats"])
parser.add_argument('day', nargs='?', default=0, type=int)
parser.add_argument("-r", "--range", dest="range_days",type=int)

args = parser.parse_args()

def show_stats(start: int, end: int):
    with sqlite3.connect(DB_PATH) as conn:
        query = """
            SELECT timestamp, app_class
            FROM activity_log
            WHERE timestamp >= ?
            AND timestamp < ?
            ORDER BY timestamp;
            """

        rows = conn.execute(query, (start.isoformat(sep=" "), end.isoformat(sep=" "))).fetchall()
        totals = {}

        for i in range(len(rows)-1):
            current_time, app = rows[i]
            next_time, _ = rows[i+1]

            current_time = datetime.fromisoformat(current_time)
            next_time = datetime.fromisoformat(next_time)

            duration = (next_time - current_time).total_seconds()

            totals[app] = totals.get(app, 0) + duration

        # Handle currently active app
        if rows:
            current_time, app = rows[-1]

            current_time = datetime.fromisoformat(current_time)
            duration = (datetime.now() - current_time).total_seconds()

            totals[app] = totals.get(app, 0) + duration

        for app, seconds in sorted(
                totals.items(),
                key=lambda x: x[1],
                reverse=True):
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            secs = int(seconds % 60)

            print(f"{app}: {hours}h {minutes}m {secs}s")


if args.command == "stats":
    today = datetime.now().date()
    target_day = today - timedelta(days=args.day)

    if args.range_days is None:
        print(f"Show stats for day offset {args.day}")
        
        start = datetime.combine(
            target_day,
            datetime.min.time()
        )

        end = start + timedelta(days=1)
    else:
        print(f"Show stats for {args.range_days} days ending at offset {args.day}")
        start = datetime.combine(
        
        target_day - timedelta(days=args.days - 1),
            datetime.min.time()
        )

        end = datetime.combine(
            target_day + timedelta(days=1),
            datetime.min.time()
        )
    
    show_stats(start, end)