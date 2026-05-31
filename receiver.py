#!/usr/bin/env python3
import os
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import sqlite3
import subprocess
import time

LAST_APP = None
LAST_TITLE = None

DB_PATH = os.path.expanduser("~/.local/share/timetracker/usage.db")
SCRIPT_PATH = os.path.expanduser("/home/awaheed/Code/timetracker/tracker.js")
SCRIPT_NAME = "window-tracker"

def load_script() -> bool:
    try:
        subprocess.run(
            ["qdbus", "org.kde.KWin", "/Scripting", "unloadScript", SCRIPT_NAME],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        
        # Load the JS script file
        res = subprocess.run(
            ["qdbus", "org.kde.KWin", "/Scripting", "loadScript", SCRIPT_PATH, SCRIPT_NAME], 
            capture_output=True, 
            text=True
        )
        
        script_id = res.stdout.strip()
        if script_id.isdigit():
            subprocess.run(
                ["qdbus", "org.kde.KWin", f"/Scripting/Script{script_id}", "run"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"Successfully loaded and hooked KWin script ID: {script_id}", flush=True)
            return True
        else:
            print(f"KWin returned an unexpected script signature: '{script_id}'", flush=True)
            return False

    except Exception as e:
        print(f"Failed to start KWin Script: {e}", flush=True)

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS activity_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
                event_type TEXT,
                app_class TEXT,
                window_title TEXT
            )
        ''')
        conn.commit()

def log_event(event_type, app_class, window_title):
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute(
                "INSERT INTO activity_log (event_type, app_class, window_title) VALUES (?, ?, ?)",
                (event_type, app_class, window_title)
            )
    
            conn.commit()
            print(f"LOGGED: ({event_type}, {app_class}, {window_title})", flush=True)
    
    except Exception as e:
        print(f"log_event failed: {e!r}", flush=True)

# --- SYSTEMD POWER SIGNAL HANDLERS ---
def handle_sleep_change(going_to_sleep):
    global LAST_APP, LAST_TITLE
    if going_to_sleep:
        log_event("suspend", "System", "Machine entering sleep/suspend state")
    else:
        LAST_APP = None
        LAST_TITLE = None
        log_event("resume", "System", "Machine woke up from sleep state")
        load_script()

def handle_shutdown_change(going_to_shutdown):
    if going_to_shutdown:
        log_event("shutdown", "System", "Machine is shutting down or restarting")

# --- INITIALIZATION SEQUENCING ---
init_db()
DBusGMainLoop(set_as_default=True)

bus_connection = dbus.SessionBus()
bus_name = dbus.service.BusName("com.custom.WindowTracker", bus=bus_connection)
system_bus = dbus.SystemBus()

class WindowListener(dbus.service.Object):
    @dbus.service.method("com.custom.WindowTracker", in_signature="ss")
    def ActiveWindowChanged(self, app_class, window_title):
        global LAST_APP, LAST_TITLE
        
        # If the window hasn't actually changed, ignore this duplicate trigger
        if app_class == LAST_APP and window_title == LAST_TITLE:
            return ""
            
        LAST_APP = app_class
        LAST_TITLE = window_title

        log_event("focus_changed", app_class, window_title)
        return ""

listener = WindowListener(bus_name, "/com/custom/WindowTracker")

# Wire up the system bus infrastructure for logind hooks
system_bus.add_signal_receiver(
    handle_sleep_change,
    signal_name="PrepareForSleep",
    dbus_interface="org.freedesktop.login1.Manager",
    bus_name="org.freedesktop.login1"
)

system_bus.add_signal_receiver(
    handle_shutdown_change,
    signal_name="PrepareForShutdown",
    dbus_interface="org.freedesktop.login1.Manager",
    bus_name="org.freedesktop.login1"
)


for i in range(10):
    if load_script():
        break
    
    print(f"KWin not ready yet (attempt {attempt+1}/10)")
    time.sleep(5)

else:
    print("Failed to hook KWin after 10 attempts")

print("Listening for KWin active window transactions and sleep/shutdown events...", flush=True)
try:
    GLib.MainLoop().run()
except KeyboardInterrupt:
    print("\nStopping...")