import QtQuick 2.4

Item {
    id: button
    property string icon: "info"
    property string label: ""
    property bool highlighted: false
    property bool available: true
    signal clicked()
    width: 54; height: 54
    opacity: available ? 1 : .28
    Accessible.name: label
    Accessible.role: Accessible.Button
    Rectangle {
        anchors.fill: parent; radius: width/2
        color: button.highlighted && button.available ? "#f3f3f3" : "#d91b1b1b"
        border.color: button.highlighted && button.available ? "#65ffe3" : "#525252"
        GlowFrame { visible: button.highlighted && button.available; corner: parent.radius }
        TvIcon { anchors.centerIn: parent; width: 25; height: 25; kind: button.icon; ink: button.highlighted && button.available ? "#101010" : "#f1f1f1" }
    }
    MouseArea { anchors.fill: parent; enabled: button.available; onClicked: button.clicked() }
}
