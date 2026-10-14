import QtQuick 2.4

Item {
    id: blur
    objectName: "backdropBlur"
    property url source
    property bool imageReady: false
    anchors.fill: parent
    // Cache the native image-provider snapshot. Weighted compositing gives a soft
    // blur without optional shader modules or a low-resolution pixelated image.
    layer.enabled: !!source
    layer.smooth: true
    property var samples: makeSamples()
    function makeSamples() {
        var result=[], cumulative=0;
        for(var y=-8;y<=8;y+=2)for(var x=-8;x<=8;x+=2){
            var weight=Math.exp(-(x*x+y*y)/40); cumulative+=weight;
            result.push({x:x,y:y,opacity:weight/cumulative});
        }
        return result;
    }
    onSourceChanged: imageReady = false
    Repeater {
        model: blur.samples
        Image {
            x: modelData.x; y: modelData.y; width: blur.width; height: blur.height
            source: blur.source; fillMode: Image.Stretch; smooth: true; cache: true
            opacity: modelData.opacity
            onStatusChanged: if (status === Image.Ready) blur.imageReady = true
        }
    }
}
