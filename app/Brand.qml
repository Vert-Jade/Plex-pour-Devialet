import QtQuick 2.4

Item {
    id: brand
    property bool compact: false
    property int titleSize: compact ? 18 : 29
    property int logoWidth: compact ? 62 : 100
    width: compact ? 150 : 470
    height: compact ? 96 : 92

    Text {
        id: title
        textFormat: Text.PlainText
        width: parent.width
        text: brand.compact ? "Le Pavillon\nde Jade" : "Le Pavillon de Jade"
        horizontalAlignment: brand.compact ? Text.AlignHCenter : Text.AlignLeft
        font.family: "Noto Sans"
        font.pixelSize: brand.titleSize
        font.weight: Font.DemiBold
        color: "#f6f6f6"
    }
    Row {
        y: title.height + (brand.compact ? 3 : 6)
        x: brand.compact ? (parent.width - width) / 2 : 0
        spacing: 9
        Text {
            textFormat: Text.PlainText
            text: "pour"
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Noto Sans"
            font.pixelSize: brand.compact ? 12 : 17
            color: "#bbbbbb"
        }
        Image {
            width: brand.logoWidth
            height: width * 0.45
            source: "assets/plex-logo.svg"
            sourceSize.width: width * 3
            fillMode: Image.PreserveAspectFit
        }
    }
}
