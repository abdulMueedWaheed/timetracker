#!/usr/bin/env python3

import os
import sqlite3
from datetime import datetime
from env import DB_PATH


def initDB() -> None:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS activity_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
                event_type TEXT,
                app_class TEXT,
                window_title TEXT
            )
            """
        )
        conn.commit()


def logEvent(event_type: str, app_class: str, window_title: str) -> None:
    initDB()
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute(
                "INSERT INTO activity_log (event_type, app_class, window_title) VALUES (?, ?, ?)",
                (event_type, app_class, window_title),
            )
            conn.commit()
            print(f"LOGGED: ({event_type}, {app_class}, {window_title})", flush=True)
    except Exception as exc:
        print(f"log_event failed: {exc!r}", flush=True)


def getStats(start_dt: datetime, end_dt: datetime | None = None) -> dict[str, float]:
    initDB()
    if end_dt is None:
        end_dt = datetime.now()

    start_ts = start_dt.strftime("%Y-%m-%d %H:%M:%S")
    end_ts = end_dt.strftime("%Y-%m-%d %H:%M:%S")

    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(
            """
            SELECT timestamp, app_class
            FROM activity_log
            WHERE timestamp >= ? AND timestamp < ?
            ORDER BY timestamp
            """,
            (start_ts, end_ts),
        ).fetchall()

    totals: dict[str, float] = {}

    for index in range(len(rows) - 1):
        current_time, app = rows[index]
        next_time, _ = rows[index + 1]

        current_dt = datetime.fromisoformat(current_time)
        next_dt = datetime.fromisoformat(next_time)

        duration = (next_dt - current_dt).total_seconds()
        totals[app] = totals.get(app, 0) + duration

    if rows:
        current_time, app = rows[-1]
        current_dt = datetime.fromisoformat(current_time)
        duration = (datetime.now() - current_dt).total_seconds()
        totals[app] = totals.get(app, 0) + duration

    ignored_apps = {"System", "org.kde.plasmashell", "plasmashell", "kwin_wayland"}
    return {app: seconds for app, seconds in totals.items() if app not in ignored_apps}


def getStatsRange(start_dt: datetime, end_dt: datetime) -> dict[str, object]:
    stats = getStats(start_dt, end_dt)
    items = [{"app": app, "seconds": int(seconds)} for app, seconds in sorted(stats.items(), key=lambda item: item[1], reverse=True)]  # type: ignore
    return {"total_seconds": int(sum(stats.values())), "items": items}


if __name__ == "__main__":
    print("db.py ready")
