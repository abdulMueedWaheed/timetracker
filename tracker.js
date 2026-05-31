workspace.windowActivated.connect(function(window) {
    if (window) {
        callDBus(
            "com.custom.WindowTracker",      // Service Name (The destination bus name)
            "/com/custom/WindowTracker",     // Object Path
            "com.custom.WindowTracker",      // Interface
            "ActiveWindowChanged",           // Method Name
            window.resourceClass,            // Argument 1
            window.caption,                  // Argument 2
            function() {}                    // Empty callback forces asynchronous execution!
        );
    }
});