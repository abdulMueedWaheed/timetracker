import os

DB_PATH      = os.path.expanduser("~/.local/share/timetracker/usage.db")
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
SCRIPT_PATH  = os.path.join(SCRIPT_DIR, "tracker.js")
SCRIPT_NAME  = "focus-tracker"

BUS_NAME        = "com.custom.TimeTracker"
OBJECT_PATH     = "/com/custom/TimeTracker"
INTERFACE_NAME  = "com.custom.TimeTracker"
