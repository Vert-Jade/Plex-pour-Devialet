import QtQuick 2.4

Item {
    id: login
    property var api
    property bool rememberFocused: false
    signal connectRequested()
    signal rememberToggled()
    anchors.fill: parent
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }

    // Coordinates reproduce the supplied reference at the default 95% TV safe area.
    Image { x: 95; y: 92; width: 165; height: 75; sourceSize.width: 660; source: "assets/plex-logo.svg"; fillMode: Image.PreserveAspectFit }
    Text { x: 95; y: 197; text: "VOTRE CINÉMA SUR DEVIALET"; font.family: typeface.name; font.pixelSize: 14; font.letterSpacing: 2; color: "#59d6a6" }
    Text { x: 94; y: 251; width: 550; text: api.welcomeName ? "Bonjour " + api.welcomeName : "Installez-vous."; font.family: typeface.name; font.pixelSize: 52; font.weight: Font.DemiBold; color: "#f6f6f6"; elide: Text.ElideRight }
    Text { x: 95; y: 339; text: "Vos films, vos séries, en un instant."; font.family: typeface.name; font.pixelSize: 28; color: "#c2c2c2" }

    Rectangle {
        x: 661; y: 103; width: 490; height: 479; radius: 20
        color: "#ed141414"; border.color: "#71777777"; border.width: 1
        Canvas { anchors.fill: parent
            onPaint: {
                var c=getContext("2d");c.clearRect(0,0,width,height);
                var g=c.createRadialGradient(width-40,height-20,0,width-40,height-20,200);
                g.addColorStop(0,"#2849ba91");g.addColorStop(1,"#0049ba91");c.fillStyle=g;
                var r=20;c.beginPath();c.moveTo(r,0);c.lineTo(width-r,0);c.quadraticCurveTo(width,0,width,r);
                c.lineTo(width,height-r);c.quadraticCurveTo(width,height,width-r,height);c.lineTo(r,height);
                c.quadraticCurveTo(0,height,0,height-r);c.lineTo(0,r);c.quadraticCurveTo(0,0,r,0);c.closePath();c.fill();
            }
        }
        Rectangle { x: 44; y: 54; width: 38; height: 3; color: "#59d6a6" }
        Text {
            x: 44; y: 89; width: 402
            text: api.state === "starting" ? "Heureux de vous retrouver" : api.code ? "Votre code de connexion" : "Bienvenue chez vous"
            font.family: typeface.name; font.pixelSize: api.state === "starting" ? 26 : 29; font.weight: Font.DemiBold; color: "#f6f6f6"
        }
        Text {
            x: 44; y: 146; width: 402
            text: api.code ? "Sur votre téléphone, ouvrez" : api.state === "starting" ? "Nous retrouvons votre bibliothèque…" : /^Retrouvez vos films/.test(api.message) ? "Retrouvez vos films et séries\nsur votre télévision." : api.message
            font.family: typeface.name; font.pixelSize: 22; lineHeight: 1.12; wrapMode: Text.Wrap; color: "#c4c4c4"
        }
        Text { x: 44; y: 235; visible: !api.code && api.state !== "starting"; text: api.rememberAccount ? "Une association suffit." : "Connexion pour cette session."; font.family: typeface.name; font.pixelSize: 22; color: "#c4c4c4" }
        Text { x: 44; y: 183; visible: !!api.code; text: "plex.tv/link"; font.family: typeface.name; font.pixelSize: 28; font.weight: Font.DemiBold; color: "#59d6a6" }
        Row {
            x: 44; y: 237; spacing: 14; visible: !!api.code
            Repeater {
                model: 4
                Rectangle {
                    width: 90; height: 76; radius: 7; color: "#bb101010"; border.color: "#666666"
                    Text { anchors.centerIn: parent; text: api.code.charAt(index); font.family: typeface.name; font.pixelSize: 43; font.weight: Font.DemiBold; color: "#59d6a6" }
                }
            }
        }
        Text { x: 44; y: 321; visible: !!api.code; text: "Saisissez ce code, puis validez « Link »."; font.family: typeface.name; font.pixelSize: 16; color: "#c4c4c4" }
        TvButton {
            x: 44; y: api.code ? 359 : 337; width: 402; height: api.code ? 54 : 64
            visible: api.state === "auth"; available: !api.busy; highlighted: !login.rememberFocused; textSize: 21; glow: false
            text: api.busy ? "Connexion…" : api.code ? "Obtenir un nouveau code" : "Associer mon compte Plex"
            onClicked: login.connectRequested()
        }
        Rectangle {x:44;y:425;width:402;height:38;radius:6;color:login.rememberFocused ? "#244539" : "transparent";visible:api.state==="auth";border.color:login.rememberFocused ? "#65ffe3" : "transparent"
            Rectangle {x:14;y:9;width:20;height:20;radius:3;color:api.rememberAccount ? "#59d6a6" : "transparent";border.color:"#aaaaaa";TvIcon {anchors.fill:parent;kind:"check";ink:"#080808";visible:api.rememberAccount}}
            Text {x:46;anchors.verticalCenter:parent.verticalCenter;text:"Rester connecté";font.family:typeface.name;font.pixelSize:17;color:"#eeeeee"}
            MouseArea {anchors.fill:parent;onClicked:login.rememberToggled()}
        }
        Text {x:44;y:429;width:402;horizontalAlignment:Text.AlignHCenter;visible:api.state==="starting";text:"Connexion automatique";font.family:typeface.name;font.pixelSize:16;color:"#b5b5b5"}
    }
    Text { x: 70; y: 665; text: "CINÉMA"; font.family: typeface.name; font.pixelSize: 14; font.letterSpacing: 3; color: "#a8a8a8" }
}
