import QtQuick 2.4
import "Plex.js" as Plex

Item {
    id: card
    property var api
    property var media: ({})
    property bool highlighted: false
    property bool continuing: false
    signal clicked()
    width: 172; height: 265
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Rectangle {
        x: 19; y: 7; width: 154; height: 211; radius: 5; color: "#181818"
        Image { anchors.fill: parent; anchors.margins: 2; source: card.api.imageUrl((card.media.type === "episode" ? card.media.grandparentThumb || card.media.parentThumb || card.media.thumb : card.media.thumb || card.media.parentThumb) || "",320,480); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 2; anchors.horizontalCenter: parent.horizontalCenter; width: 150; height: 4; radius: 2; visible: card.continuing; color: "#5e5e5e"
            Rectangle { width: parent.width * Math.min(1,(card.media.viewOffset || 0) / Math.max(1,card.media.duration || 1)); height: parent.height; radius: 2; color: "#65ffe3" }
        }
        GlowFrame { visible: card.highlighted; corner: 6 }
    }
    Text { textFormat: Text.PlainText; x: 19; y: 226; width: 158; text: card.media.type === "episode" ? (Plex.episodeCode(card.media) ? Plex.episodeCode(card.media)+" · " : "") + (card.media.title || "") : card.media.title || ""; font.family: typeface.name; font.pixelSize: 12; color: card.highlighted ? "#ffffff" : "#c5c5c5"; elide: Text.ElideRight }
    Text { textFormat: Text.PlainText; x: 19; y: 244; width: 158; text: card.continuing && card.media.duration ? Math.ceil(Math.max(0,card.media.duration-(card.media.viewOffset || 0))/60000)+" min restantes" : card.media.year || ""; font.family: typeface.name; font.pixelSize: 11; color: "#a2a2a2"; elide: Text.ElideRight }
    MouseArea { anchors.fill: parent; onClicked: card.clicked() }
}
