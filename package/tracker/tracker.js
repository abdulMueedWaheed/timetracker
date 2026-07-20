print(">>> WindowTracker: Script loaded and initializing...");

// Supports Plasma 6 (windowActivated) and Plasma 5 (clientActivated)
var activationSignal = workspace.windowActivated || workspace.clientActivated;

if (!activationSignal) {
    print(">>> WindowTracker ERROR: Neither windowActivated nor clientActivated signal found!");
} else {
    print(">>> WindowTracker: Successfully connected to window activation signal.");

    activationSignal.connect(function(win) {
        if (!win) return;

        // Ensure variables are strictly converted to string
        var resClass = win.resourceClass ? String(win.resourceClass) : "Unknown";
        var caption = win.caption ? String(win.caption) : "Unknown";

        print(">>> WindowTracker focus change detected: " + resClass + " | " + caption);

        callDBus(
            "com.custom.TimeTracker",
            "/com/custom/TimeTracker",
            "com.custom.TimeTracker",
            "ActiveWindowChanged",
            resClass,
            caption
        );
    });
}