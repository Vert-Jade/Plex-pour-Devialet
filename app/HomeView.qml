import QtQuick 2.4
import "Plex.js" as Plex

Item {
    id: home
    property var api
    property var controller
    property var media: controller.hero
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    Rectangle { anchors.fill: parent; color: "#000000" }
    Image { x: 166; width: 1114; height: 720; source: api.imageUrl(home.media.art || "",1600,900); fillMode: Image.PreserveAspectCrop; asynchronous: true }
    Image { anchors.fill: parent; source: "assets/home-shade.svg" }
    Text { textFormat: Text.PlainText; x: 199; y: 25; width: 820; text: api.welcomeName ? "Bonjour " + api.welcomeName : "Votre cinéma, à la maison"; font.family: typeface.name; font.pixelSize: 16; color: "#59d6a6"; elide: Text.ElideRight }
    Text { textFormat: Text.PlainText; x: 200; y: 180; width: 850; visible:!api.hubs.length; text:api.homeNotice || "Votre accueil se prépare…";wrapMode:Text.Wrap;font.family:typeface.name;font.pixelSize:26;color:"#dddddd" }
    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#14000000" } GradientStop { position: .38; color: "#00000000" } GradientStop { position: .7; color: "#cc000000" } GradientStop { position: 1; color: "#ff000000" } } }
    Text { textFormat: Text.PlainText; x: 199; y: 56; text: home.media.type === "episode" || home.media.type === "show" || home.media.type === "season" ? ((home.media.Genre || []).some(function(g){return /anim/i.test(g.tag);}) ? "SÉRIE ANIMÉE" : "SÉRIE") : "FILM"; color: "#c1c1c1"; font.family: typeface.name; font.pixelSize: 11; font.letterSpacing: 3; visible: !!controller.displayedItems.length }
    Text { textFormat: Text.PlainText; x: 199; y: 77; width: 1000; text: Plex.label(home.media); color: "#f8f8f8"; font.family: typeface.name; font.pixelSize: 30; font.weight: Font.DemiBold; elide: Text.ElideRight; visible: !!controller.displayedItems.length }
    Row { x: 200; y: 123; spacing: 23; visible: !!controller.displayedItems.length
        Text { textFormat: Text.PlainText; text: home.media.year || ""; font.family: typeface.name; font.pixelSize: 15; color: "#f5f5f5" }
        Text { textFormat: Text.PlainText; text: Plex.duration(home.media.duration); visible: !!home.media.duration; font.family: typeface.name; font.pixelSize: 15; color: "#f5f5f5" }
        Text { textFormat: Text.PlainText; text: Plex.age(home.media.contentRating); font.family: typeface.name; font.pixelSize: 15; color: "#f5f5f5" }
        Rectangle { width: 30; height: 18; y: 3; radius: 2; color: "transparent"; border.color: "#c1c1c1"; visible: !!Plex.qualityBadge(home.media)
            Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: Plex.qualityBadge(home.media); color: "#cccccc"; font.family: typeface.name; font.pixelSize: 11 }
        }
    }
    Text { textFormat: Text.PlainText; x: 200; y: 160; width: 507; height: 80; text: home.media.summary || ""; color: "#cecece"; font.family: typeface.name; font.pixelSize: 14; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; lineHeightMode: Text.FixedHeight; lineHeight: 20 }
    Text { textFormat: Text.PlainText; x: 200; y: 246; width: 690; text: (home.media.Role || []).length ? "Avec " + home.media.Role.slice(0,3).map(function(r){return r.tag;}).join(", ") : ""; color: "#b8b8b8"; font.family: typeface.name; font.pixelSize: 14; elide: Text.ElideRight }
    Row { x: 199; y: 282; spacing: 20; visible: !!controller.displayedItems.length
        Rectangle { width: 207; height: 42; radius: 21; color: "#c50a3324"; border.color: "#65ffe3"; border.width: 1.5
            GlowFrame { corner: 21; strength: controller.zone === 5 && controller.heroButton === 0 ? 1 : .65 }
            TvIcon { x: 27; y: 12; width: 18; height: 18; kind: "play"; ink: "#fcfcfc" }
            Text { textFormat: Text.PlainText; x: 55; width: 140; anchors.verticalCenter: parent.verticalCenter; text: home.media.type === "show" ? "Voir les saisons" : home.media.type === "season" ? "Voir les épisodes" : home.media.viewOffset ? "Continuer la lecture" : "Lire"; font.family: typeface.name; font.pixelSize: 13; font.weight: Font.DemiBold; color: "white" }
            MouseArea { anchors.fill: parent; onClicked: controller.homeAction(0) }
        }
        Item { width: 96; height: 42
            Rectangle { y: 5; width: 32; height: 32; radius: 16; color: "#44181818"; border.color: "#707070"; TvIcon { anchors.centerIn: parent; width: 20; height: 20; kind: "plus" } GlowFrame { visible: controller.zone === 5 && controller.heroButton === 1; corner: 16 } }
            Text { textFormat: Text.PlainText; x: 44; anchors.verticalCenter: parent.verticalCenter; text: "Ma liste"; font.family: typeface.name; font.pixelSize: 12; color: "#bfbfbf" }
            MouseArea { anchors.fill: parent; onClicked: controller.homeAction(1) }
        }
        Item { width: 130; height: 42
            Rectangle { y: 5; width: 32; height: 32; radius: 16; color: "#44181818"; border.color: "#707070"; TvIcon { anchors.centerIn: parent; width: 20; height: 20; kind: "info" } GlowFrame { visible: controller.zone === 5 && controller.heroButton === 2; corner: 16 } }
            Text { textFormat: Text.PlainText; x: 44; anchors.verticalCenter: parent.verticalCenter; text: "Plus d’infos"; font.family: typeface.name; font.pixelSize: 12; color: "#bfbfbf" }
            MouseArea { anchors.fill: parent; onClicked: controller.homeAction(2) }
        }
    }
    ListView {
        id: rows; objectName: "homeRows"; x: 180; y: 341; width: 1100; height: 379; clip: true; interactive: false
        model: api.hubs; currentIndex: controller.hubIndex; highlightRangeMode: ListView.ApplyRange; preferredHighlightBegin: 0; preferredHighlightEnd: 305; highlightMoveDuration: 150
        delegate: Item { width: 1100; height: 305; property int rowIndex: index; property var rowData: modelData
            Text { textFormat: Text.PlainText; x: 20; text: rowData.title; font.family: typeface.name; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#f5f5f5" }
            Text { textFormat: Text.PlainText; x: 20; y: 74; visible: !rowData.items.length; text: "Aucune lecture en cours. Vos vidéos commencées apparaîtront ici."; font.family: typeface.name; font.pixelSize: 18; color: "#c2c2c2" }
            ListView { x: 0; y: 27; width: 1100; height: 278; clip: true; orientation: ListView.Horizontal; interactive: false; model: rowData.items
                currentIndex: controller.hubIndex === rowIndex ? controller.itemIndex : 0; highlightRangeMode: ListView.ApplyRange; preferredHighlightBegin: 0; preferredHighlightEnd: 1032; highlightMoveDuration: 140
                delegate: HomeCard { api: home.api; media: modelData; continuing: rowIndex === 0; highlighted: controller.zone === 2 && controller.hubIndex === rowIndex && controller.itemIndex === index && !controller.sheet && !api.error
                    onClicked: { controller.zone = 2; controller.hubIndex = rowIndex; controller.itemIndex = index; controller.openCurrent(); controller.takeFocus(); }
                }
            }
        }
    }
    Text { textFormat: Text.PlainText; x: 1135; y: 25; width: 105; horizontalAlignment: Text.AlignRight; text: controller.timeText; font.family: typeface.name; font.pixelSize: 16; color: "#efefef" }
}
