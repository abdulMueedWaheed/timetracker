import QtCharts
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // ------------------------------------
    //  vars
    // ------------------------------------
    property var summaryData: ({
        "total_seconds": 0,
        "items": []
    })
    property var chartItems: buildChartItems(summaryData)
    property var allItems: buildAllItems(summaryData)
    property bool loading: true


    function loadStats(startDate, endDate) {
        var command = "qdbus com.custom.TimeTracker /com/custom/TimeTracker " + "com.custom.TimeTracker.GetStatsForRange " + startDate + " " + endDate;
        dataSource.connectSource(command);
    }

    // ------------------------------------
    //  Helper functions
    // ------------------------------------
    function formatTime(time) {
        if (!time || time <= 0)
            return "0m";

        var hours = Math.floor(time / 3600);
        var minutes = Math.floor((time % 3600) / 60);
        var seconds = time % 60;
        return (hours > 0 ? hours + "h " : "") + (minutes > 0 ? minutes + "m " : "") + (hours === 0 && minutes === 0 ? seconds + "s" : "");
    }

    function getISODate(date) {
        return date.toISOString().split('T')[0];
    }

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

        // Fallback: no "Others" slice exists (e.g. very few apps today, nothing got grouped)
        return Kirigami.Theme.textColor;
    }

    function buildAllItems(summary) {
        var items = (summary && summary.items) ? summary.items.slice() : [];
        items.sort(function(a, b) {
            return b.seconds - a.seconds;
        });
        return items;
    }

    function buildChartItems(summary) {
        var items = (summary && summary.items) ? summary.items.slice() : [];
        if (items.length === 0)
            return [];

        items.sort(function(a, b) {
            return b.seconds - a.seconds;
        });
        var total = summary.total_seconds || 0;
        if (total <= 0) {
            for (var i = 0; i < items.length; i++) {
                total += items[i].seconds;
            }
        }
        var target = total * 0.9;
        var accumulated = 0;
        var result = [];
        var othersSeconds = 0;
        for (var j = 0; j < items.length; j++) {
            var item = items[j];
            if (accumulated < target) {
                result.push(item);
                accumulated += item.seconds;
            } else {
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
        chartItems = buildChartItems(summaryData);
        allItems = buildAllItems(summaryData);
        loading = false;
    }

    // ------------------------------------
    //  Timer and Data Loader
    // ------------------------------------
    Timer {
        interval: 10 * 1000
        running: true
        repeat: true
        onTriggered: root.loadStats(getISODate(new Date()), getISODate(new Date()))
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
            } catch (e) {
                console.error("Error parsing stats:", e, out);
            }
        }
    }


    preferredRepresentation: fullRepresentation

    // ------------------------------------
    //  Compact Representation
    // ------------------------------------
    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "player-time"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        PC3.Label {
            text: formatTime(root.summaryData.total_seconds)
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ------------------------------------
    //  Full Representation
    // ------------------------------------
    fullRepresentation: ColumnLayout {
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
                    text: "today"
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