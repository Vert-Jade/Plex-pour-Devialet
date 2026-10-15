import QtQuick 2.4
import "Plex.js" as Plex

Item {
    id: page
    property var api
    property var controller
    readonly property var media: api.detail
    readonly property var cast: media.Role || []
    readonly property var bonus: Plex.extras(media).map(function(e,i){return {media:e,index:i};}).filter(function(e){return Number(e.media.extraType)!==1;})
    readonly property var actions: (media.cloudOnly ? [] : [{id:0,icon:"play",title:media.type==="show" ? "Voir les saisons" : media.type==="season" ? "Voir les épisodes" : media.viewOffset ? "Reprendre" : "Lire"}])
        .concat(!media.cloudOnly && media.viewOffset && ["movie","episode"].indexOf(media.type)>=0 ? [{id:1,icon:"rewind",title:"Lire depuis le début"}] : [])
        .concat(Plex.trailers(media).length ? [{id:5,icon:"reel",title:"Bande-annonce"}] : [])
        .concat(!media.cloudOnly ? [{id:4,icon:"bookmark",title:"Ma liste"},{id:2,icon:"check",title:media.viewCount ? "Marquer non vu" : "Marquer vu"}] : [])
        .concat([{id:3,icon:"info",title:"Informations du fichier"}])
    readonly property var sections: [0,1].concat(cast.length ? [2] : []).concat(bonus.length ? [3] : [])
    readonly property int actionIndex: Math.max(0,actions.map(function(a){return a.id;}).indexOf(controller.detailButton))
    readonly property bool focused: controller.detailFocused
    onActionsChanged: if (actions.length && actions.map(function(a){return a.id;}).indexOf(controller.detailButton)<0) controller.detailButton=actions[0].id
    onVisibleChanged: if (visible) { canvas.contentY=0; }
    function move(dx,dy) {
        if(dy) {
            var index=sections.indexOf(controller.detailZone);
            controller.detailZone=sections[Math.max(0,Math.min(sections.length-1,index+dy))];
            controller.detailSecondary=0;
        }
        if(dx) {
            if(controller.detailZone===0) controller.detailButton=actions[Math.max(0,Math.min(actions.length-1,actionIndex+dx))].id;
            else if(controller.detailZone>=2) controller.detailSecondary=Math.max(0,Math.min((controller.detailZone===2 ? cast.length : bonus.length)-1,controller.detailSecondary+dx));
        }
        ensureVisible();
    }
    function ensureVisible() {
        var bottom=controller.detailZone===3 ? extrasRow.y+extrasRow.height : controller.detailZone===2 ? castRow.y+castRow.height : 0;
        canvas.contentY=Math.min(Math.max(0,canvas.contentHeight-canvas.height),Math.max(0,bottom-canvas.height+20));
    }
    function activate() {
        if(api.busy)return;
        if(controller.detailZone===1){controller.sheet="synopsis";return;}
        if(controller.detailZone===2){
            if(media.cloudOnly || !cast[controller.detailSecondary] || !cast[controller.detailSecondary].id){api.notice="Filmographie indisponible pour cet interprète.";return;}
            controller.rememberFocus(true);controller.detailOpen=false;controller.zone=2;api.openActor(controller.detailSecondary);return;
        }
        if(controller.detailZone===3){var extra=bonus[controller.detailSecondary];if(extra)api.playExtra(extra.index);return;}
        var action=actions[actionIndex];if(!action)return;
        if(action.id===0 || action.id===1) {
            if(media.type==="show" || media.type==="season"){controller.rememberFocus();controller.detailOpen=false;controller.zone=2;api.openChildren();}
            else api.play(action.id===0);
        } else if(action.id===2)api.markWatched();
        else if(action.id===3)controller.sheet="info";
        else if(action.id===4)api.toggleWatchlist(media);
        else if(action.id===5) {
            if(Plex.trailers(media).length===1)api.playTrailer(0);
            else {controller.sheetIndex=0;controller.sheet="trailers";}
        }
    }
    FontLoader { id: typeface; source:"fonts/NotoSans-Regular.ttf" }
    Rectangle { anchors.fill:parent; color:"#080808" }
    Image { x:280; width:parent.width-x; height:720; source:page.visible ? api.imageUrl(media.art || "",1600,900) : ""; fillMode:Image.PreserveAspectCrop; asynchronous:true }
    Image { anchors.fill:parent; source:"assets/cinema-shade.svg" }
    Flickable {
        id:canvas; objectName:"detailCanvas"; anchors.fill:parent; anchors.bottomMargin:64; clip:true; interactive:false
        contentWidth:width; contentHeight:Math.max(height,extrasRow.visible ? extrasRow.y+extrasRow.height+25 : castRow.visible ? castRow.y+castRow.height+25 : 500)
        Behavior on contentY { NumberAnimation { duration:150 } }
        Text { textFormat:Text.PlainText;x:94;y:35;width:1080;text:api.browseTitle;font.family:typeface.name;font.pixelSize:17;color:"#bdbdbd";elide:Text.ElideRight }
        Text { textFormat:Text.PlainText;x:94;y:83;width:1080;height:105;text:Plex.label(media);font.family:typeface.name;font.pixelSize:40;font.weight:Font.DemiBold;color:"#fafafa";wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight }
        Text { textFormat:Text.PlainText;x:96;y:192;width:1040;text:[media.year || "",Plex.duration(media.duration),Plex.age(media.contentRating),Plex.qualityBadge(media)].filter(function(v){return !!v;}).join("   ·   ");font.family:typeface.name;font.pixelSize:18;color:"#d0d0d0";elide:Text.ElideRight }
        Text { textFormat:Text.PlainText;x:96;y:233;width:850;height:78;text:media.cloudOnly ? "Ce titre est dans votre Watchlist Plex, mais n’est pas disponible sur ce serveur." : media.summary || "Aucun résumé disponible.";font.family:typeface.name;font.pixelSize:19;color:"#c7c7c7";wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;lineHeight:1.15 }
        Row { x:94;y:330;spacing:18
            Repeater { model:page.actions
                Item { width:modelData.id===0 ? 240 : 54;height:54
                    TvButton { anchors.fill:parent; visible:modelData.id===0; text:modelData.title; icon:"play"; highlighted:page.focused && controller.detailZone===0 && controller.detailButton===modelData.id; onClicked:{controller.detailZone=0;controller.detailButton=modelData.id;page.activate();controller.takeFocus();} }
                    IconButton { anchors.fill:parent; visible:modelData.id!==0; icon:modelData.icon; label:modelData.title; highlighted:page.focused && controller.detailZone===0 && controller.detailButton===modelData.id; onClicked:{controller.detailZone=0;controller.detailButton=modelData.id;page.activate();controller.takeFocus();} }
                }
            }
        }
        Text { textFormat:Text.PlainText;x:94;y:394;width:1080;text:page.focused && controller.detailZone===0 && controller.detailButton!==0 ? page.actions[page.actionIndex].title : "";font.family:typeface.name;font.pixelSize:16;color:"#65ffe3" }
        Item { x:94;y:430;width:200;height:34
            Rectangle { anchors.fill:parent;radius:6;color:page.focused && controller.detailZone===1 ? "#f3f3f3" : "transparent";GlowFrame {visible:page.focused && controller.detailZone===1;corner:6} }
            Text { textFormat:Text.PlainText;anchors.centerIn:parent;text:"Lire le résumé complet";font.family:typeface.name;font.pixelSize:16;color:page.focused && controller.detailZone===1 ? "#101010" : "#bdbdbd" }
            MouseArea {anchors.fill:parent;onClicked:{controller.detailZone=1;page.activate();controller.takeFocus();}}
        }
        Item { id:castRow; x:80;y:487;width:1120;height:190;visible:page.cast.length>0
            Text {textFormat:Text.PlainText;x:14;text:"Distribution";font.family:typeface.name;font.pixelSize:24;font.weight:Font.DemiBold;color:"#f7f7f7"}
            ListView { id:castList;objectName:"castList";y:35;width:parent.width;height:155;clip:true;interactive:false;orientation:ListView.Horizontal;model:page.cast;currentIndex:controller.detailZone===2 ? controller.detailSecondary : 0;highlightRangeMode:ListView.ApplyRange;preferredHighlightBegin:0;preferredHighlightEnd:width-160;highlightMoveDuration:120
                delegate:Item { width:160;height:155
                    Rectangle { x:14;y:12;width:94;height:94;radius:6;color:"#272727";border.color:"#414141"
                        TvIcon {anchors.centerIn:parent;width:42;height:42;kind:"user";visible:portrait.status!==Image.Ready}
                        Image {id:portrait;anchors.fill:parent;source:api.imageUrl(modelData.thumb || "",188,188);fillMode:Image.PreserveAspectCrop;asynchronous:true}
                        GlowFrame {visible:page.focused && controller.detailZone===2 && controller.detailSecondary===index;corner:6}
                    }
                    Text {textFormat:Text.PlainText;x:14;y:114;width:140;text:modelData.tag || "";font.family:typeface.name;font.pixelSize:16;color:"white";elide:Text.ElideRight}
                    Text {textFormat:Text.PlainText;x:14;y:137;width:140;text:modelData.role || "";font.family:typeface.name;font.pixelSize:13;color:"#bdbdbd";elide:Text.ElideRight}
                    MouseArea {anchors.fill:parent;onClicked:{controller.detailZone=2;controller.detailSecondary=index;page.activate();controller.takeFocus();}}
                }
            }
        }
        Item { id:extrasRow;x:80;y:castRow.visible ? 710 : 487;width:1120;height:240;visible:page.bonus.length>0
            Text {textFormat:Text.PlainText;x:14;text:"Bonus";font.family:typeface.name;font.pixelSize:24;font.weight:Font.DemiBold;color:"#f7f7f7"}
            ListView { objectName:"extrasList";y:35;width:parent.width;height:205;clip:true;interactive:false;orientation:ListView.Horizontal;model:page.bonus;currentIndex:controller.detailZone===3 ? controller.detailSecondary : 0;highlightRangeMode:ListView.ApplyRange;preferredHighlightBegin:0;preferredHighlightEnd:width-270;highlightMoveDuration:120
                delegate:Item {width:270;height:205
                    Rectangle {x:14;y:12;width:240;height:135;radius:6;color:"#242424"
                        TvIcon {anchors.centerIn:parent;width:40;height:40;kind:"film"}
                        Image {anchors.fill:parent;source:api.imageUrl(modelData.media.thumb || "",480,270);fillMode:Image.PreserveAspectCrop;asynchronous:true}
                        GlowFrame {visible:page.focused && controller.detailZone===3 && controller.detailSecondary===index;corner:6}
                    }
                    Text {textFormat:Text.PlainText;x:14;y:157;width:240;text:modelData.media.title || "Bonus";font.family:typeface.name;font.pixelSize:17;color:"white";elide:Text.ElideRight}
                    Text {textFormat:Text.PlainText;x:14;y:183;width:240;text:Plex.duration(modelData.media.duration);font.family:typeface.name;font.pixelSize:14;color:"#bdbdbd"}
                    MouseArea {anchors.fill:parent;onClicked:{controller.detailZone=3;controller.detailSecondary=index;page.activate();controller.takeFocus();}}
                }
            }
        }
    }
    Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:64;color:"#ed080808"}
    RemoteHints { x:94;y:674;keySize:28;textSize:14;actions:[{key:"arrows",label:"Parcourir"},{key:"ok",label:"Choisir"},{key:"back",label:"Retour aux affiches"}] }
}
