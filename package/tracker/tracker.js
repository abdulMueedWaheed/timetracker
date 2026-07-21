var activationSignal = workspace.windowActivated || workspace.clientActivated;

if (!activationSignal) {
    print(">>> WindowTracker ERROR: Neither windowActivated nor clientActivated signal found!");
} else {
    activationSignal.connect(function(win) {
        if (!win) return;

        var resClass = win.resourceClass ? String(win.resourceClass) : "Unknown";
        var caption = win.caption ? String(win.caption) : "Unknown";

        print(">>> WindowTracker focus change detected: " + resClass + " | " + caption);

        callDBus(
            "com.custom.TimeTracker",   // Bus Name 
            "/com/custom/TimeTracker",  // Object Path
            "com.custom.TimeTracker",   // Interface Name
            "ActiveWindowChanged",      // Method Name
            resClass,
            caption
        );
    });
}
