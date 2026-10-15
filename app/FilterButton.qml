import QtQuick 2.4

Item {
    id: button
    property string text: ""
    property bool highlighted: false
    property bool expanded: false
    property bool filtered: false
    signal clicked()
    width: 190; height: 46
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Rectangle {
        anchors.fill: parent; radius: 4
        color: button.highlighted ? "#f3f3f3" : button.expanded ? "#363636" : "#4a4a4a"
        border.width: button.highlighted ? 2 : 1; border.color: button.highlighted ? "#65ffe3" : "#4a4a4a"
        GlowFrame { visible: button.highlighted; corner: 4 }
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    Text { textFormat: Text.PlainText;
        x: 17; width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter
        text: button.text; color: button.highlighted ? "#111111" : button.filtered ? "#59d6a6" : "#e6e6e6"
        font.family: typeface.name; font.pixelSize: 18; elide: Text.ElideRight
    }
    TvIcon { kind: "down"; x: parent.width - 33; y: 14; width: 18; height: 18; ink: button.highlighted ? "#111111" : "#c8c8c8"; rotation: button.expanded ? 180 : 0 }
    MouseArea { anchors.fill: parent; onClicked: button.clicked() }
}
