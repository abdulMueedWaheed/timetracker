#!/usr/bin/env python3
import dbus # type: ignore
import dbus.service # type: ignore
from dbus.mainloop.glib import DBusGMainLoop # type: ignore
from gi.repository import GLib # type: ignore
import json
import subprocess
import time
from datetime import datetime, timedelta

from db import log_event, get_stats_for_range, init_db
from env import SCRIPT_PATH, SCRIPT_NAME

last_app: str = ""
last_title: str = ""

def is_script_loaded() -> bool:
    try:
        res = subprocess.run(
            ["qdbus", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.isScriptLoaded", SCRIPT_NAME],
            capture_output=True,
            text=True
        )
        return res.stdout.strip() == "true"
    except Exception as e:
        print(f"Error occurred while checking if script is loaded: {e}", flush=True)
        return False


def unload_script() -> None:
    try:
        subprocess.run(
            ["qdbus", "org.kde.KWin", f"/Scripting", "unloadScript", SCRIPT_NAME],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        print(f"Successfully unloaded KWin script: {SCRIPT_NAME}", flush=True)
    except Exception as e:
        print(f"Failed to unload KWin Script: {e}", flush=True)


def load_script() -> bool:
    try:
        if is_script_loaded():
            unload_script()    
        
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
        if 'res' in locals():
            print("stdout:", repr(res.stdout))   # type: ignore
            print("stderr:", repr(res.stderr))   # type: ignore
            print("returncode:", res.returncode) # type: ignore
    
        return False


# --- SYSTEMD POWER SIGNAL HANDLERS ---
def handle_sleep_change(going_to_sleep): # type: ignore
    global last_app, last_title
    if going_to_sleep:
        log_event("suspend", "System", "Machine entering sleep/suspend state")
    else:
        last_app = ""
        last_title = ""
        log_event("resume", "System", "Machine woke up from sleep state")
        load_script()


def handle_shutdown_change(going_to_shutdown): # type: ignore
    if going_to_shutdown:
        log_event("shutdown", "System", "Machine is shutting down or restarting")


# --- INITIALIZATION SEQUENCING ---
from db import init_db


def get_stats_json(start_date: str, end_date: str) -> str:
    """Convert date strings to datetime and return stats as JSON for D-Bus."""
    try:
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")
        end_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
        stats = get_stats_for_range(start_dt, end_dt)
        return json.dumps(stats)
    except Exception as exc:
        print(f"get_stats_json failed: {exc!r}", flush=True)
        return json.dumps({"total_seconds": 0, "items": [], "error": str(exc)})



def main() -> None:
    init_db()
    DBusGMainLoop(set_as_default=True)

    bus_connection = dbus.SessionBus()
    bus_name = dbus.service.BusName("com.custom.TimeTracker", bus=bus_connection) # type: ignore
    system_bus = dbus.SystemBus()

    class WindowListener(dbus.service.Object): # type: ignore
        @dbus.service.method("com.custom.TimeTracker", in_signature="ss") # type: ignore
        def ActiveWindowChanged(self, app_class: str, window_title: str):
            global last_app, last_title
            print(f"ActiveWindowChanged called: {app_class} / {window_title}", flush=True)

            if app_class == last_app and window_title == last_title:
                print(f"Ignoring duplicate", flush=True)
                return ""

            last_app = app_class
            last_title = window_title

            print(f"Logging event for {app_class}", flush=True)
            log_event("focus_changed", app_class, window_title)
            return ""


        @dbus.service.method("com.custom.TimeTracker", in_signature="ss", out_signature="s") # type: ignore
        def GetStatsForRange(self, start_date: str, end_date: str):
            return get_stats_json(start_date, end_date)


    listener = WindowListener(bus_name, "/com/custom/TimeTracker") # type: ignore


    system_bus.add_signal_receiver( # type: ignore
        handle_sleep_change,
        signal_name="PrepareForSleep",
        dbus_interface="org.freedesktop.login1.Manager",
        bus_name="org.freedesktop.login1",
    )

    system_bus.add_signal_receiver( # type: ignore
        handle_shutdown_change,
        signal_name="PrepareForShutdown",
        dbus_interface="org.freedesktop.login1.Manager",
        bus_name="org.freedesktop.login1",
    )

    for i in range(10):
        if load_script():
            break

        print(f"KWin not ready yet (attempt {i + 1}/10)")
        time.sleep(5)
    else:
        print("Failed to hook KWin after 10 attempts")

    print("Listening for KWin active window transactions and sleep/shutdown events...", flush=True)

    try:
        GLib.MainLoop().run() # type: ignore
    except KeyboardInterrupt:
        unload_script()
        print("\nStopping...")


if __name__ == "__main__":
    main()