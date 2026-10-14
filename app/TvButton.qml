import QtQuick 2.4

FocusScope {
    id: control
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    FontLoader { source: "fonts/NotoSans-SemiBold.ttf" }
    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool highlighted: activeFocus
    property bool primary: false
    property bool glow: true
    property bool available: true
    property int textSize: 20
    signal clicked()
    width: 180; height: 52
    opacity: available ? 1 : 0.35
    Rectangle {
        anchors.fill: parent; radius: 4
        color: control.highlighted ? "#f4f4f4" : control.primary ? "#59d6a6" : control.selected ? "#3a3a3a" : "#4a4a4a"
        border.width: control.highlighted ? 2 : 1
        border.color: control.highlighted ? "#ffffff" : control.selected ? "#65ffe3" : "#4a4a4a"
        GlowFrame { visible: control.highlighted && control.glow; corner: 4 }
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    Text { font.family: typeface.name;
        anchors.fill: parent; anchors.leftMargin: control.icon ? 47 : 16; anchors.rightMargin: 16
        text: control.text; color: control.highlighted || control.primary ? "#141414" : "#f0f0f0"
        font.pixelSize: control.textSize; font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
    }
    TvIcon { visible: !!control.icon; kind: control.icon; width: 20; height: 20; x: 21; anchors.verticalCenter: parent.verticalCenter; ink: control.highlighted || control.primary ? "#141414" : "#f0f0f0" }
    Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
            if (available) clicked(); event.accepted = true;
        }
    }
    MouseArea { anchors.fill: parent; onClicked: { control.forceActiveFocus(); if (control.available) control.clicked(); } }
}
