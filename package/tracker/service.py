#!/usr/bin/env python3
from dbus_next.constants import BusType
from dbus_next.glib.message_bus import MessageBus
from dbus_next.service import ServiceInterface, method
from gi.repository import GLib # type: ignore

import json
import subprocess
import time
from datetime import datetime, timedelta

from db import logEvent, getStatsRange, initDB
from env import SCRIPT_PATH, SCRIPT_NAME, BUS_NAME, OBJECT_PATH, INTERFACE_NAME

last_app: str = ""
last_title: str = ""

# -------------------------------------
# Main Interface Class
# -------------------------------------
class TimeTrackerInterface(ServiceInterface):
    def __init__(self) -> None:
        super().__init__(INTERFACE_NAME)

    @method()
    def ActiveWindowChanged(self, app_class: "s", window_title: "s") -> None:
        global last_app, last_title

        print(f"ActiveWindowChanged called: {app_class} / {window_title}", flush=True)

        if app_class == last_app and window_title == last_title:
            print("Ignoring duplicate", flush=True)
            return

        last_app = app_class
        last_title = window_title

        print(f"Logging event for {app_class}", flush=True)
        logEvent("focus_changed", app_class, window_title)

    @method()
    def GetStatsForRange(self, start_date: "s", end_date: "s") -> "s":
        return get_stats_json(start_date, end_date)
    

# -------------------------------------
# Load, Unload, and Check if script is loaded
# -------------------------------------
def isScriptLoaded() -> bool:
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


def unloadScript() -> None:
    try:
        subprocess.run(
            ["qdbus", "org.kde.KWin", f"/Scripting", "unloadScript", SCRIPT_NAME],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        print(f"Successfully unloaded KWin script: {SCRIPT_NAME}", flush=True)
    except Exception as e:
        print(f"Failed to unload KWin Script: {e}", flush=True)


def loadScript() -> bool:
    try:
        if isScriptLoaded():
            unloadScript()    
        
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


# -------------------------------------
# SYSTEMD POWER SIGNAL HANDLERS
# -------------------------------------
def handleSleepChange(going_to_sleep): # type: ignore
    global last_app, last_title
    if going_to_sleep:
        logEvent("suspend", "System", "Machine entering sleep/suspend state")
    else:
        last_app = ""
        last_title = ""
        logEvent("resume", "System", "Machine woke up from sleep state")
        loadScript()


def handleShutdownChange(going_to_shutdown): # type: ignore
    if going_to_shutdown:
        logEvent("shutdown", "System", "Machine is shutting down or restarting")


# --- INITIALIZATION SEQUENCING ---
from db import initDB


def get_stats_json(start_date: str, end_date: str) -> str:
    """Convert date strings to datetime and return stats as JSON for D-Bus."""
    try:
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")
        end_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
        stats = getStatsRange(start_dt, end_dt)
        return json.dumps(stats)
    except Exception as exc:
        print(f"get_stats_json failed: {exc!r}", flush=True)
        return json.dumps({"total_seconds": 0, "items": [], "error": str(exc)})



def main() -> None:
    initDB()

    session_bus = MessageBus(bus_type=BusType.SESSION).connect_sync()
    session_bus.request_name_sync(BUS_NAME)
    session_bus.export(OBJECT_PATH, TimeTrackerInterface())

    system_bus = MessageBus(bus_type=BusType.SYSTEM).connect_sync()


    login1_intro = system_bus.introspect_sync(
        "org.freedesktop.login1",
        "/org/freedesktop/login1",
    )

    login1_object = system_bus.get_proxy_object(
        "org.freedesktop.login1",
        "/org/freedesktop/login1",
        login1_intro,
    )

    login1_manager = login1_object.get_interface("org.freedesktop.login1.Manager")
    login1_manager.on_prepare_for_sleep(handleSleepChange)
    login1_manager.on_prepare_for_shutdown(handleShutdownChange)


    for i in range(10):
        if loadScript():
            break

        print(f"KWin not ready yet (attempt {i + 1}/10)")
        time.sleep(5)
    else:
        print("Failed to hook KWin after 10 attempts")

    print("Listening for KWin active window transactions and sleep/shutdown events...", flush=True)

    try:
        GLib.MainLoop().run() # type: ignore
    except KeyboardInterrupt:
        unloadScript()
        print("\nStopping...")


if __name__ == "__main__":
    main()
