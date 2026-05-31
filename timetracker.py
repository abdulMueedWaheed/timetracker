#!/usr/bin/env python3

import os
import sqlite3
from datetime import datetime

DB_PATH = os.path.expanduser("~/.local/share/timetracker/usage.db")

conn = sqlite3.connect(DB_PATH)

rows = conn.execute("""
    SELECT timestamp, app_class
    FROM activity_log
    WHERE event_type='focus_changed'
    ORDER BY timestamp
""").fetchall()

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
    print(app, seconds)

conn.close()