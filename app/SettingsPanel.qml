import QtQuick 2.4
import "Plex.js" as Plex

Rectangle {
    id: panel
    property var api
    property int selectedIndex: 0
    onSelectedIndexChanged: ensureVisible.restart()
    property url backdrop
    readonly property var preferences: Plex.settingsRows(api)
    signal chosen(int index)
    color: "transparent"
    BackdropBlur { source: panel.backdrop }
    Rectangle { anchors.fill: parent; color: "#c9000000" }
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Text { x: 1135; y: 25; width: 105; horizontalAlignment: Text.AlignRight; text: Qt.formatTime(new Date(),"hh:mm"); font.family: typeface.name; font.pixelSize: 16; color: "#efefef" }
    Image { x: 204; y: 63; width: 88; height: 40; source: "assets/plex-logo.svg"; fillMode: Image.PreserveAspectFit }
    Text { x: 313; y: 75; text: "VOTRE CINÉMA SUR DEVIALET"; font.family: typeface.name; font.pixelSize: 13; font.letterSpacing: 2.5; color: "#65ffe3" }
    Text { x: 204; y: 117; text: "Paramètres"; font.family: typeface.name; font.pixelSize: 43; font.weight: Font.DemiBold; color: "#f9f9f9" }
    Text { x: 206; y: 172; text: "Votre expérience de lecture, mémorisée sur ce Devialet."; font.family: typeface.name; font.pixelSize: 19; color: "#c4c4c4" }
    ListView {
        id: preferenceList; objectName: "preferenceList"
        x: 194; y: 205; width: 1000; height: 356; spacing: 0; clip: true; interactive: false
        currentIndex: Math.min(panel.selectedIndex,panel.preferences.length-1); highlightRangeMode: ListView.NoHighlightRange
        preferredHighlightBegin: 0; preferredHighlightEnd: 344; highlightMoveDuration: 130
        model: panel.preferences
        onCurrentIndexChanged: ensureVisible.restart()
        onModelChanged: ensureVisible.restart()
        Timer { id: ensureVisible; interval: 1; onTriggered: {
            preferenceList.currentIndex=Math.min(panel.selectedIndex,panel.preferences.length-1);
            var first=Math.max(0,Math.round(preferenceList.contentY/86)),selected=preferenceList.currentIndex;
            if(selected<first)first=selected;else if(selected>first+3)first=selected-3;
            preferenceList.contentY=Math.max(0,first)*86;
        } }
        delegate: Item {
            width: 1000; height: 86
            Rectangle {
                x: 13; y: 12; width: 972; height: 74; radius: 10
                color: panel.selectedIndex === index ? "#f3f3f3" : "#e0181818"; border.color: panel.selectedIndex === index ? "#b4d5d0" : "#454545"
                GlowFrame { visible: panel.selectedIndex === index; corner: 10 }
                Rectangle { x: 21; y: 10; width: 54; height: 54; radius: 27; color: panel.selectedIndex === index ? "#c2eee7" : "#303030"
                    TvIcon { anchors.centerIn: parent; width: 27; height: 27; kind: modelData.icon; ink: panel.selectedIndex === index ? "#07594d" : "#f5f5f5" }
                }
                Text { x: 104; y: 10; text: modelData.title; font.family: typeface.name; font.pixelSize: 21; font.weight: Font.DemiBold; color: panel.selectedIndex === index ? "#101010" : "#f8f8f8" }
                Text { x: 104; y: 40; width:625;text: modelData.hint;elide:Text.ElideRight;font.family: typeface.name; font.pixelSize: 15; color: panel.selectedIndex === index ? "#525252" : "#c4c4c4" }
                TvIcon { x: 751; y: 29; width: 15; height: 17; kind: "left"; ink: panel.selectedIndex === index ? "#07594d" : "#65ffe3" }
                Text { x: 780; width: 150; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: modelData.value; font.family: typeface.name; font.pixelSize: 18; font.weight: Font.DemiBold; color: panel.selectedIndex === index ? "#07594d" : "#65ffe3" }
                TvIcon { x: 940; y: 29; width: 15; height: 17; kind: "right"; ink: panel.selectedIndex === index ? "#07594d" : "#65ffe3" }
                MouseArea { anchors.fill: parent; onClicked: panel.chosen(index) }
            }
        }
    }
    Rectangle { x: 207; y: 568; width: 972; height: 1; color: "#454545" }
    Text { x: 207; y: 585; width: 720; text: panel.selectedIndex < 2 ? "Les sauts nécessitent les repères détectés par votre serveur Plex.\nLe Plex Pass peut être requis. Sans repère, la lecture continue normalement." : panel.selectedIndex === 4 || panel.selectedIndex === 5 ? "La musique s’arrête automatiquement au démarrage d’une vidéo.\nLes thèmes sont ceux disponibles dans votre bibliothèque Plex." : panel.selectedIndex === 12 ? "Désactiver efface les accès enregistrés, sans interrompre cette session.\nUne nouvelle association sera nécessaire après fermeture de l’application." : "Vos réglages sont enregistrés automatiquement sur ce Devialet."; font.family: typeface.name; font.pixelSize: 14; lineHeight: 1.15; color: "#c4c4c4" }
    Rectangle { x: 955; y: 586; width: 226; height: 44; radius: 22; color: "#e0181818"; border.color: "#818181"; border.width: 1.2
        GlowFrame { visible: panel.selectedIndex === panel.preferences.length; corner: 22 }
        Text { anchors.centerIn: parent; text: "Terminé"; font.family: typeface.name; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#f7f7f7" }
        MouseArea { anchors.fill: parent; onClicked: panel.chosen(panel.preferences.length) }
    }
    Row { x: 207; y: 651; spacing: 24
        Repeater { model: [{label:"Naviguer",icon:"arrows",size:124},{label:"Choisir / Modifier",icon:"ok",size:176},{label:"Retour",icon:"left",size:110}]
            Item { width: modelData.size; height: 30
                Rectangle { width: 29; height: 29; radius: 15; color: "transparent"; border.color: "#9d9d9d"
                    TvIcon { anchors.centerIn: parent; width: 19; height: 19; kind: modelData.icon; visible: modelData.icon !== "ok"; ink: "#cfcfcf" }
                    Text { anchors.centerIn: parent; text: "OK"; visible: modelData.icon === "ok"; font.family: typeface.name; font.pixelSize: 11; color: "#cfcfcf" }
                }
                Text { x: 43; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.family: typeface.name; font.pixelSize: 14; color: "#c4c4c4" }
                Rectangle { x: parent.width; y: 2; width: 1; height: 26; color: "#454545"; visible: index < 2 }
            }
        }
    }
}
