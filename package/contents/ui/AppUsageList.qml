import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: root

    property var items: []
    property int totalSeconds: 0
    property var colorProvider: function(index) {
        return Kirigami.Theme.highlightColor;
    }
    property var formatDuration: function(seconds) {
        return seconds + "s";
    }
    readonly property int rowHeight: Kirigami.Units.gridUnit * 2.2

    implicitHeight: Math.min(listView.contentHeight, Kirigami.Units.gridUnit * 12)

    ListView {
        id: listView

        anchors.fill: parent
        clip: true
        interactive: contentHeight > height
        spacing: Kirigami.Units.smallSpacing
        model: root.items

        delegate: Item {
            width: ListView.view.width
            height: root.rowHeight

            readonly property int percent: root.totalSeconds > 0 ? Math.round(modelData.seconds * 100 / root.totalSeconds) : 0

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.highlightColor
                opacity: rowMouse.containsMouse ? 0.08 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 0.55
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 0.55
                        radius: width / 2
                        color: root.colorProvider(index)
                    }

                    PC3.Label {
                        Layout.fillWidth: true
                        text: modelData.app
                        elide: Text.ElideRight
                        font.bold: true
                    }

                    PC3.Label {
                        text: root.formatDuration(modelData.seconds)
                        opacity: 0.8
                    }

                    PC3.Label {
                        text: percent + "%"
                        opacity: 0.5
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                    }

                }

                // Mini progress bar
                // Track
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 0.35
                    radius: height / 2
                    color: Kirigami.Theme.textColor
                    

                    Rectangle {
                        width: parent.width * (percent / 100)
                        height: parent.height
                        radius: height / 2
                        color: root.colorProvider(modelData.app)
                        opacity: 1.0

                        Behavior on width {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

            }

        }

    }

}