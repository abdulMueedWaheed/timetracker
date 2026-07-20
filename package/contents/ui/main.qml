import QtQuick
import QtQuick.Layouts
import QtCharts
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PC3

PlasmoidItem {
    id: root
    height: 500
    width: 500

    Timer {
        interval: 10 * 1000
        running: true
        repeat: true
        onTriggered: root.loadData()
    }

    preferredRepresentation: fullRepresentation

    compactRepresentation: PC3.Label {
        text: "23:45"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth:  Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        spacing: Kirigami.Units.smallSpacing

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