import QtQuick 2.4

Canvas {
    id: icon
    property string kind: "library"
    property color ink: "#dcdcdc"
    width: 24; height: 24
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d"); c.clearRect(0,0,width,height);
        c.save(); c.scale(width / 24, height / 24); c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.8; c.lineCap = "round"; c.lineJoin = "round";
        c.beginPath();
        if (kind === "down") { c.moveTo(6,9); c.lineTo(12,15); c.lineTo(18,9); }
        else if (kind === "up") { c.moveTo(6,15);c.lineTo(12,9);c.lineTo(18,15); }
        else if (kind === "left") { c.moveTo(15,5); c.lineTo(8,12); c.lineTo(15,19); }
        else if (kind === "right") { c.moveTo(9,5); c.lineTo(16,12); c.lineTo(9,19); }
        else if (kind === "first") { c.moveTo(5,5);c.lineTo(5,19);c.moveTo(17,5);c.lineTo(10,12);c.lineTo(17,19); }
        else if (kind === "reel") { c.arc(12,11,9,0,Math.PI*2);c.moveTo(12,20);c.lineTo(22,20);c.stroke();c.beginPath();for(var ri=0;ri<4;ri++){var ra=ri*Math.PI/2;c.moveTo(14+5*Math.cos(ra),11+5*Math.sin(ra));c.arc(12+5*Math.cos(ra),11+5*Math.sin(ra),2,0,Math.PI*2);}c.fill();c.beginPath(); }
        else if (kind === "pin") { c.moveTo(8,3);c.lineTo(16,3);c.lineTo(15,10);c.lineTo(19,15);c.lineTo(5,15);c.lineTo(9,10);c.closePath();c.moveTo(12,15);c.lineTo(12,22); }
        else if (kind === "more") { for(var mi=5;mi<=19;mi+=7){c.moveTo(mi+1.5,12);c.arc(mi,12,1.5,0,Math.PI*2);}c.fill();c.beginPath(); }
        else if (kind === "back") { c.moveTo(9,5);c.lineTo(4,10);c.lineTo(9,15);c.moveTo(4,10);c.lineTo(14,10);c.bezierCurveTo(21,10,21,19,14,19); }
        else if (kind === "menu") { for(var my=6;my<=18;my+=6){c.moveTo(5,my);c.lineTo(19,my);} }
        else if (kind === "horizontal") { c.moveTo(8,6);c.lineTo(3,12);c.lineTo(8,18);c.moveTo(16,6);c.lineTo(21,12);c.lineTo(16,18); }
        else if (kind === "vertical") { c.moveTo(6,8);c.lineTo(12,3);c.lineTo(18,8);c.moveTo(6,16);c.lineTo(12,21);c.lineTo(18,16); }
        else if (kind === "check") { c.moveTo(5,12); c.lineTo(10,17); c.lineTo(19,7); }
        else if (kind === "plus") { c.moveTo(12,4);c.lineTo(12,20);c.moveTo(4,12);c.lineTo(20,12); }
        else if (kind === "folder") { c.moveTo(2,5);c.lineTo(9,5);c.lineTo(11,8);c.lineTo(22,8);c.lineTo(22,21);c.lineTo(2,21);c.closePath(); }
        else if (kind === "arrows") { c.moveTo(9,5);c.lineTo(12,2);c.lineTo(15,5);c.moveTo(9,19);c.lineTo(12,22);c.lineTo(15,19);c.moveTo(5,9);c.lineTo(2,12);c.lineTo(5,15);c.moveTo(19,9);c.lineTo(22,12);c.lineTo(19,15); }
        else if (kind === "info") { c.moveTo(12,10);c.lineTo(12,20);c.moveTo(10,20);c.lineTo(15,20);c.moveTo(10,10);c.lineTo(12,10);c.moveTo(12,4);c.lineTo(12,5); }
        else if (kind === "skip") { c.moveTo(3,5);c.lineTo(11,12);c.lineTo(3,19);c.closePath();c.moveTo(13,5);c.lineTo(21,12);c.lineTo(13,19);c.closePath();c.fill(); }
        else if (kind === "credits") { c.moveTo(3,22);c.lineTo(3,3);c.lineTo(21,3);c.lineTo(21,15);c.lineTo(3,15);for(var fy=0;fy<3;fy++)for(var fx=0;fx<4;fx++)if((fy+fx)%2===0)c.fillRect(3+fx*4.5,3+fy*4,4.5,4); }
        else if (kind === "rewind") { c.arc(12,13,8,-Math.PI*.8,Math.PI*.9);c.moveTo(3,4);c.lineTo(3,10);c.lineTo(9,10); }
        else if (kind === "screen") { c.rect(2,3,20,14);c.moveTo(12,17);c.lineTo(12,22);c.moveTo(7,22);c.lineTo(17,22); }
        else if (kind === "music") { c.moveTo(9,18);c.lineTo(9,4);c.lineTo(21,2);c.lineTo(21,16);c.moveTo(9,7);c.lineTo(21,5);c.moveTo(9,18);c.ellipse(2,16,7,5);c.moveTo(21,16);c.ellipse(14,14,7,5); }
        else if (kind === "volume") { c.moveTo(3,9);c.lineTo(7,9);c.lineTo(12,4);c.lineTo(12,20);c.lineTo(7,15);c.lineTo(3,15);c.closePath();c.moveTo(16,7);c.bezierCurveTo(21,9,21,15,16,17); }
        else if (kind === "play") { c.moveTo(7,4); c.lineTo(20,12); c.lineTo(7,20); c.closePath(); c.fill(); }
        else if (kind === "bookmark") { c.moveTo(6,3);c.lineTo(18,3);c.lineTo(18,22);c.lineTo(12,17);c.lineTo(6,22);c.closePath(); }
        else if (kind === "home") { c.moveTo(2,11);c.lineTo(12,2);c.lineTo(22,11);c.moveTo(5,9);c.lineTo(5,22);c.lineTo(10,22);c.lineTo(10,15);c.lineTo(15,15);c.lineTo(15,22);c.lineTo(20,22);c.lineTo(20,9); }
        else if (kind === "search") { c.arc(10,10,7,0,Math.PI*2);c.moveTo(15,15);c.lineTo(22,22); }
        else if (kind === "settings") { c.arc(12,12,6,0,Math.PI*2);c.moveTo(15,12);c.arc(12,12,3,0,Math.PI*2);for(var i=0;i<8;i++){var a=i*Math.PI/4;c.moveTo(12+6*Math.cos(a),12+6*Math.sin(a));c.lineTo(12+10*Math.cos(a),12+10*Math.sin(a));} }
        else if (kind === "user") { c.arc(12,7,3.5,0,Math.PI*2); c.moveTo(4,22); c.lineTo(4,20); c.bezierCurveTo(4,11,20,11,20,20); c.lineTo(20,22); }
        else if (kind === "server") { c.rect(3,3,18,7); c.rect(3,14,18,7); c.moveTo(6,6.5); c.lineTo(7,6.5); c.moveTo(6,17.5); c.lineTo(7,17.5); }
        else if (kind === "series") { c.rect(3,6,18,13); c.moveTo(9,22); c.lineTo(15,22); c.moveTo(8,2); c.lineTo(12,6); c.lineTo(16,2); }
        else if (kind === "film") { c.rect(3,4,18,16); c.moveTo(3,9); c.lineTo(21,9); c.moveTo(8,4); c.lineTo(8,9); c.moveTo(16,4); c.lineTo(16,9); }
        else { c.rect(3,4,4,16); c.rect(10,4,4,16); c.moveTo(17,4); c.lineTo(21,4); c.lineTo(23,20); c.lineTo(19,20); c.closePath(); }
        c.stroke(); c.restore();
    }
}
