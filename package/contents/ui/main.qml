import QtQuick
import QtQuick.Layouts
import QtCharts
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property var summaryData: ({ total_seconds: 0, items: [] })

    P5Support.DataSource {
        id: dataSource
        engine: "executable"

        onNewData: function(sourceName, data) {
            dataSource.disconnectSource(sourceName)

            var out = data["stdout"] || ""
            if (out === "") return

            try {
                root.summaryData = JSON.parse(out)
            } catch (e) {
                console.error("Error parsing stats:", e, out)
            }
        }
    }

    function loadStats(startDate, endDate) {
        var command = "qdbus com.custom.TimeTracker /com/custom/TimeTracker " +
                    "com.custom.TimeTracker.GetStatsForRange " +
                    startDate + " " + endDate
        dataSource.connectSource(command)
    }

    function formatTime(time) {
        if (!time || time <= 0) return "0m"
        
        var hours = Math.floor(time / 3600)
        var minutes = Math.floor((time % 3600) / 60)
        var seconds = time % 60

        return (hours > 0 ? hours + "h " : "") +
               (minutes > 0 ? minutes + "m " : "") +
               (seconds > 0 ? seconds + "s" : "")
    }

    function getISODate(date) {
        return date.toISOString().split('T')[0]
    }

    Component.onCompleted: root.loadStats(getISODate(new Date()), getISODate(new Date()))

    Timer {
        interval: 10 * 1000
        running: true
        repeat: true
        onTriggered: root.loadStats(getISODate(new Date()), getISODate(new Date()))
    }

    preferredRepresentation: compactRepresentation

    compactRepresentation: PC3.Label {
        height: 100
        width: 100
        text: formatTime(root.summaryData.total_seconds)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    fullRepresentation: ColumnLayout {
        // height: 500
        // width: 500
        // Layout.minimumWidth:  Kirigami.Units.gridUnit * 18
        // Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        // Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        // Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        // spacing: Kirigami.Units.smallSpacing

        ChartView {
            id: chart
            title: "Top-5 car brand shares in Finland"
            anchors.fill: parent
            legend.alignment: Qt.AlignBottom
            antialiasing: true

            property variant othersSlice: 0

            PieSeries {
                id: pieSeries
                PieSlice { label: "Volkswagen"; value: 13.5 }
                PieSlice { label: "Toyota"; value: 10.9 }
                PieSlice { label: "Ford"; value: 8.6 }
                PieSlice { label: "Skoda"; value: 8.2 }
                PieSlice { label: "Volvo"; value: 6.8 }
            }

            Component.onCompleted: {
                // You can also manipulate slices dynamically, like append a slice or set a slice exploded
                othersSlice = pieSeries.append("Others", 52.0);
                pieSeries.find("Volkswagen").exploded = true;
            }
        }
    }
}