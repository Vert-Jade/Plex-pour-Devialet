import QtQuick 2.4

Item {
    id: menu
    property string title: ""
    property var options: []
    property int focusedIndex: 0
    property int selectedIndex: -1
    property bool loading: false
    signal chosen(int index)
    width: 330; height: Math.min(486, Math.max(160, options.length * 54 + 110))
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Rectangle { x: -7; y: -3; width: parent.width + 14; height: parent.height + 17; radius: 14; color: "#33000000" }
    Rectangle { anchors.fill: parent; radius: 5; color: "#303030"; border.color: "#505050" }
    Text { textFormat: Text.PlainText; x: 20; y: 16; text: menu.title; color: "#b4b4b4"; font.family: typeface.name; font.pixelSize: 15; font.letterSpacing: 1.2 }
    Item {
        x: list.x; y: list.y + menu.focusedIndex * 54 - list.contentY; width: list.width; height: 54
        visible: menu.options.length > 0 && !menu.loading
        GlowFrame { corner: 5 }
    }
    ListView {
        id: list; x: 10; y: 50; width: parent.width - 20; height: parent.height - 104; clip: true
        model: menu.options; currentIndex: menu.focusedIndex; highlightMoveDuration: 100
        highlightRangeMode: ListView.ApplyRange; preferredHighlightBegin: 0; preferredHighlightEnd: height - 54
        delegate: Rectangle {
            width: list.width; height: 54; radius: 5
            color: index === menu.focusedIndex ? "#f3f3f3" : "transparent"
            Text { textFormat: Text.PlainText; x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60; text: modelData.title; font.family: typeface.name; font.pixelSize: 20; color: index === menu.focusedIndex ? "#121212" : "#f0f0f0"; elide: Text.ElideRight }
            TvIcon { x: parent.width - 35; anchors.verticalCenter: parent.verticalCenter; kind: "check"; width: 20; height: 20; visible: index === menu.selectedIndex; ink: index === menu.focusedIndex ? "#121212" : "#59d6a6" }
            MouseArea { anchors.fill: parent; onClicked: menu.chosen(index) }
        }
    }
    Rectangle { x: parent.width - 5; y: 50; width: 2; height: list.height; color: "#414141"; visible: list.contentHeight > list.height
        Rectangle { width: 2; height: Math.max(18, parent.height * list.height / Math.max(1, list.contentHeight)); y: Math.max(0, Math.min(parent.height - height, list.contentY / Math.max(1, list.contentHeight - list.height) * (parent.height - height))); color: "#dcdcdc" }
    }
    Text { textFormat: Text.PlainText; visible: menu.loading; anchors.centerIn: parent; text: "Chargement des genres…"; font.family: typeface.name; font.pixelSize: 18; color: "#dedede" }
    RemoteHints { x:23;anchors.bottom:parent.bottom;anchors.bottomMargin:13;keySize:26;textSize:13;groupSpacing:24;labelSpacing:9;actions:[{key:"ok",label:"Valider"},{key:"back",label:"Annuler"}] }
}
