import QtQuick 2.4

Canvas {
    id: glow
    objectName: "focusGlow"
    property real corner: 8
    property real strength: 1
    property color ink: "#65ffe3"
    antialiasing: true
    smooth: true
    anchors.fill: parent
    anchors.margins: -14
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCornerChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onInkChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onPaint: {
        var c=getContext("2d"); c.clearRect(0,0,width,height);
        var x=14,y=14,w=width-28,h=height-28,r=Math.min(corner,w/2,h/2);
        function outline() {
            c.beginPath();c.moveTo(x+r,y);c.lineTo(x+w-r,y);c.quadraticCurveTo(x+w,y,x+w,y+r);
            c.lineTo(x+w,y+h-r);c.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
            c.lineTo(x+r,y+h);c.quadraticCurveTo(x,y+h,x,y+h-r);c.lineTo(x,y+r);c.quadraticCurveTo(x,y,x+r,y);c.closePath();
        }
        c.strokeStyle=ink;
        for (var i=24;i>=4;i-=2) { c.globalAlpha=(.013+(24-i)*.0012)*strength;c.lineWidth=i;outline();c.stroke(); }
        c.globalAlpha=strength;c.lineWidth=1.8;outline();c.stroke();c.globalAlpha=1;
    }
}
