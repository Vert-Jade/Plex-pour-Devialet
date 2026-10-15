import QtQuick 2.4

// Passive remote legend: identical key shapes and spacing on every screen.
// These are instructions, not additional focusable or clickable controls.
Item {
    id: hints
    property var actions: []
    property int keySize: 34
    property int textSize: 16
    property int groupSpacing: 30
    property int labelSpacing: 12
    implicitWidth: groups.width
    implicitHeight: keySize
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Row {
        id: groups
        spacing: hints.groupSpacing
        Repeater {
            model: hints.actions
            Item {
                width: hints.keySize + hints.labelSpacing + caption.implicitWidth
                height: hints.keySize
                Rectangle {
                    x: -hints.groupSpacing / 2
                    y: 6; width: 1; height: parent.height - 12
                    color: "#424242"; visible: index > 0
                }
                Rectangle {
                    id: keycap
                    width: hints.keySize; height: width; radius: width / 2
                    antialiasing: true
                    border.color: "#828282"; border.width: 1
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#303030" }
                        GradientStop { position: 1; color: "#141414" }
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 2
                        antialiasing: true
                        radius: width / 2; color: "transparent"; border.color: "#383838"
                    }
                    TvIcon {
                        anchors.centerIn: parent
                        // Draw above display resolution so TV scaling keeps
                        // diagonals and curves crisp on the embedded Canvas.
                        width: parent.width * 1.24; height: width; scale: 0.5
                        kind: modelData.key; ink: "#eeeeee"
                        visible: modelData.key !== "ok"
                    }
                    Text {
                        anchors.centerIn: parent; visible: modelData.key === "ok"
                        textFormat: Text.PlainText; text: "OK"
                        font.family: typeface.name; font.pixelSize: Math.round(hints.keySize * 0.35)
                        font.weight: Font.DemiBold; color: "#f4f4f4"
                    }
                }
                Text {
                    id: caption
                    x: hints.keySize + hints.labelSpacing; anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText; text: modelData.label
                    font.family: typeface.name; font.pixelSize: hints.textSize
                    color: "#d0d0d0"
                }
            }
        }
    }
}
