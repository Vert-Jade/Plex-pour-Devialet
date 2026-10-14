import QtQuick 2.4
Item {
    id: card
    property var media: ({})
    property var api
    property bool highlighted: false
    property bool captions: true
    signal clicked()
    width: 184; height: captions ? 320 : 276
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Rectangle {
        x: 12; y: 10; width: 160; height: 240; color: card.media.type === "category" ? "#454545" : "#303030"
        scale: card.highlighted ? 1.055 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
        Text { anchors.centerIn: parent; width: 140; text: card.media.title || ""; font.family: typeface.name; font.pixelSize: 22; color: "#eee"; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
        Image { anchors.fill: parent; source: card.api.imageUrl((card.media.type === "episode" ? card.media.grandparentThumb || card.media.parentThumb || card.media.thumb : card.media.thumb || card.media.parentThumb || card.media.grandparentThumb) || "",320,480); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Canvas { width: 25; height: 25; anchors.right: parent.right; visible: !card.media.viewCount && !card.media.viewOffset && ["movie","episode"].indexOf(card.media.type) >= 0
            onPaint: { var c=getContext("2d");c.fillStyle="#59d6a6";c.beginPath();c.moveTo(0,0);c.lineTo(25,0);c.lineTo(25,25);c.closePath();c.fill(); }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 4; color: "#555"; visible: !!card.media.viewOffset; Rectangle { height: 4; width: parent.width * Math.min(1,(card.media.viewOffset || 0) / (card.media.duration || 1)); color: "#59d6a6" } }
        GlowFrame { visible: card.highlighted; corner: 5 }
    }
    Text { x: 5; y: 266; width: 174; text: card.media.title || ""; visible: card.captions; font.family: typeface.name; font.pixelSize: 18; color: card.highlighted ? "white" : "#d0d0d0"; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
    Text { x: 5; y: 294; width: 174; text: card.media.cloudOnly ? "Absent du serveur" : card.media.year || (card.media.leafCount ? card.media.leafCount + " titres" : ""); visible: card.captions; font.family: typeface.name; font.pixelSize: 16; color: "#aaa"; horizontalAlignment: Text.AlignHCenter }
    MouseArea { anchors.fill: parent; onClicked: card.clicked() }
}
