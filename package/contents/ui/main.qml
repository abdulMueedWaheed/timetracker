import QtCharts
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.TranslucentBackground

    // ------------------------------------
    //  vars
    // ------------------------------------
    property var summaryData: ({
        "total_seconds": 0,
        "items": []
    })

    property var allItems: buildAllItems(summaryData)
    property var chartItems: buildChartItems(allItems, summaryData)
    property bool loading: true


    property var filterOptions: buildFilterOptions()
    property int selectedIndex: 0


    // ------------------------------------
    //  Helper functions
    // ------------------------------------

    // Data Loading
    function loadStats(startDate, endDate) {
        var command = "qdbus com.custom.TimeTracker /com/custom/TimeTracker " + "com.custom.TimeTracker.GetStatsForRange " + startDate + " " + endDate;
        dataSource.connectSource(command);
    }

    
    // Date and Time Functions
    function formatTime(time) {
        if (!time || time <= 0)
            return "0m";

        var hours = Math.floor(time / 3600);
        var minutes = Math.floor((time % 3600) / 60);
        var seconds = time % 60;
        return (hours > 0 ? hours + "h " : "") + (minutes > 0 ? minutes + "m " : "") + (hours === 0 && minutes === 0 ? seconds + "s" : "");
    }

    function getISODate(date) {
        var y = date.getFullYear();
        var m = String(date.getMonth() + 1).padStart(2, "0");
        var d = String(date.getDate()).padStart(2, "0");
        return y + "-" + m + "-" + d;
    }

    function dateForOffset(offset) {
        var d = new Date();
        d.setDate(d.getDate() - offset);
        return d;
    }

    function formatShortDate(date) {
        // e.g. "Jul 27" — locale-aware, no manual month-name arrays
        return Qt.locale().toString(date, "MMM d");
    }


    // Filtering Data
    function buildFilterOptions() {
        var opts = [];

        opts.push({ type: "day", offset: 0, label: "Today" });
        opts.push({ type: "day", offset: 1, label: "Yesterday" });

        // Day 2 through 6: show the actual date
        for (var i = 2; i <= 6; i++) {
            opts.push({ type: "day", offset: i, label: formatShortDate(dateForOffset(i)) });
        }

        opts.push({ type: "range", days: 3, label: "Last 3 days" });
        opts.push({ type: "range", days: 7, label: "Last week" });

        return opts;
    }

    function applyFilter(index) {
        var opt = root.filterOptions[index];
        var endDate = new Date();
        var startDate;

        if (opt.type === "day") {
            startDate = dateForOffset(opt.offset);
            endDate = startDate;
        } 
        
        else {
            startDate = new Date();
            startDate.setDate(startDate.getDate() - (opt.days - 1)); // inclusive of today
        }

        root.loadStats(getISODate(startDate), getISODate(endDate));
    }

    // Get colors for UI elements
    function chartColor(index) {
        var colors = [Kirigami.Theme.highlightColor, Kirigami.Theme.positiveTextColor, Kirigami.Theme.neutralTextColor, Kirigami.Theme.negativeTextColor, Kirigami.Theme.linkColor, Kirigami.Theme.visitedLinkColor, Kirigami.Theme.activeTextColor, Kirigami.Theme.textColor];
        return colors[index % colors.length];
    }

    function othersColor() {
        return Kirigami.Theme.disabledTextColor;
    }

    function colorForAppList(appName) {
        // If this app has its own slice in the chart, match that slice's color exactly
        for (var i = 0; i < root.chartItems.length; i++) {
            if (root.chartItems[i].app === appName) {
                return root.chartColor(i);
            }
        }

        // Otherwise it was folded into "Others" in the chart — reuse that color
        var othersIndex = root.chartItems.length - 1;
        if (othersIndex >= 0 && root.chartItems[othersIndex].app === "Others") {
            return root.chartColor(othersIndex);
        }

        return Kirigami.Theme.textColor;
    }


    // Building Array of Items for representing the data
    function buildAllItems(summary) {
        var items = (summary && summary.items) ? summary.items.slice() : [];
        items.sort(function(a, b) {
            return b.seconds - a.seconds;
        });
        return items;
    }

    function buildChartItems(allItems, summary) {
        
        var total = summary.total_seconds || 0;
        
        if (total <= 0) {
            for (var i = 0; i < allItems.length; i++) {
                total += allItems[i].seconds;
            }
        }
        
        var target = total * 0.9;
        var accumulated = 0;
        var result = [];
        var othersSeconds = 0;
        for (var j = 0; j < allItems.length; j++) {
            var item = allItems[j];
            
            if (accumulated < target) {
                result.push(item);
                accumulated += item.seconds;
            } 
            
            else {
                othersSeconds += item.seconds;
            }
        }

        if (othersSeconds > 0)
            result.push({
                "app": "Others",
                "seconds": othersSeconds
            });

        return result;
    }


    // ------------------------------------
    //  On completed
    // ------------------------------------
    Component.onCompleted: root.loadStats(getISODate(new Date()), getISODate(new Date()))
    onSummaryDataChanged: {
        allItems = buildAllItems(summaryData);
        chartItems = buildChartItems(allItems, summaryData);
        loading = false;
    }


    // ------------------------------------
    //  Timer and Data Loader
    // ------------------------------------
    Timer {
        interval: 10 * 1000
        running: root.filterOptions[root.selectedIndex].offset === 0
        repeat: true
        
        onTriggered: {
            root.loadStats(getISODate(new Date()), getISODate(new Date()))
        }
    }

    
    P5Support.DataSource {
        id: dataSource

        engine: "executable"
        onNewData: function(sourceName, data) {
            dataSource.disconnectSource(sourceName);
            var out = data["stdout"] || "";
            if (out === "")
                return;

            try {
                root.summaryData = JSON.parse(out);
            } 
            
            catch (e) {
                console.error("Error parsing stats:", e, out);
            }
        }
    }


    preferredRepresentation: Plasmoid.compactRepresentation

    // ------------------------------------
    //  Compact Representation
    // ------------------------------------
    compactRepresentation: MouseArea {
        id: compactRoot
        implicitWidth: compactLayout.implicitWidth
        implicitHeight: compactLayout.implicitHeight
        Layout.preferredWidth: compactLayout.implicitWidth
        Layout.preferredHeight: compactLayout.implicitHeight

        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactLayout
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "d-tracker"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            PC3.Label {
                text: formatTime(root.summaryData.total_seconds)
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ------------------------------------
    //  Full Representation
    // ------------------------------------
    fullRepresentation: ColumnLayout {
        implicitWidth: Kirigami.Units.gridUnit * 24
        implicitHeight: Kirigami.Units.gridUnit * 28
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: "Screen Time"
                level: 2
                Layout.fillWidth: true
            }

            PC3.BusyIndicator {
                running: root.loading
                visible: root.loading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            PC3.ComboBox {
                id: filterCombo
                Layout.fillWidth: true

                model: root.filterOptions
                textRole: "label"

                currentIndex: root.selectedIndex
                onActivated: function(index) {
                    root.selectedIndex = index;
                    root.applyFilter(index);
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 11

            ChartView {
                id: chart

                function rebuildPie() {
                    pieSeries.clear();
                    for (var i = 0; i < root.chartItems.length; i++) {
                        var item = root.chartItems[i];
                        var slice = pieSeries.append(item.app, item.seconds);
                        slice.color = item.app === "Others" ? root.othersColor() : root.chartColor(i);
                        slice.borderWidth = 2;
                        slice.borderColor = Kirigami.Theme.backgroundColor;
                    }
                }

                anchors.fill: parent
                antialiasing: true
                backgroundColor: "transparent"
                dropShadowEnabled: false
                // plotAreaBackgroundVisible: false
                margins.top: 0
                margins.bottom: 0
                margins.left: 0
                margins.right: 0
                legend.visible: false
                Component.onCompleted: rebuildPie()

                PieSeries {
                    id: pieSeries

                    size: 0.9
                    holeSize: 0.62

                    onCountChanged: chart.update()
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                opacity: root.chartItems.length > 0 ? 1 : 0.15

                Connections {
                    function onChartItemsChanged() {
                        chart.rebuildPie();
                    }

                    target: root
                }

            }

            // Center label sitting inside the donut hole
            ColumnLayout {
                x: chart.plotArea.x + (chart.plotArea.width - width) / 2
                y: chart.plotArea.y + (chart.plotArea.height - height) / 2
                spacing: 0
                visible: root.chartItems.length > 0

                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatTime(root.summaryData.total_seconds)
                    font.pixelSize: Kirigami.Units.gridUnit * 1.1
                    font.bold: true
                }

                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.filterOptions[root.selectedIndex].label.toLowerCase()
                    opacity: 0.6
                    font.pixelSize: Kirigami.Units.gridUnit * 0.7
                }

            }

            PC3.Label {
                anchors.centerIn: parent
                visible: !root.loading && root.chartItems.length === 0
                text: "No activity tracked yet today"
                opacity: 0.6
            }

        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        AppUsageList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            items: root.allItems
            totalSeconds: root.summaryData.total_seconds || 0
            colorProvider: root.colorForAppList
            formatDuration: root.formatTime
        }

    }

}