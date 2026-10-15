import QtQuick 2.4
import "Playback.js" as Playback
import "Plex.js" as Plex

FocusScope {
    id: panel
    property var session
    property int row: 0
    property int choice: 0
    onRowChanged: optionScroll.restart()
    onChoiceChanged: optionScroll.restart()
    property string submenu: ""
    property var choices: []
    readonly property bool convertible: !!Playback.metadataPath(session.media)
    readonly property var rows: !convertible ? [{title:"Reprendre la vidéo",kind:"resume",value:0,options:[]},{title:"Réessayer la lecture",kind:"retry",value:0,options:[]}] : (Plex.chapters(session.media).length ? [{title:"Chapitres",kind:"chapter",value:-1,options:Plex.chapters(session.media)}] : []).concat([
        {title:"Version du fichier",kind:"version",value:session.mediaIndex,options:Playback.versions(session.media)},
        {title:"Piste audio",kind:"audio",value:session.audioId,options:Playback.trackOptions(session.media,session.mediaIndex,2)},
        {title:"Sous-titres",kind:"subtitles",value:session.subtitleId,options:Playback.trackOptions(session.media,session.mediaIndex,3)},
        {title:"Qualité",kind:"quality",value:session.qualityIndex,options:Playback.qualities.map(function(q,i){return {title:q.title,value:i};})},
        {title:"Sortie audio",kind:"output",value:session.audioOutput,options:[{title:"Automatique · Original, sinon stéréo",value:0},{title:"Surround 5.1 · Dolby Digital",value:1}]},
        {title:"Mode de lecture",kind:"mode",value:session.modeIndex,options:[{title:"Automatique · Lecture directe en priorité",value:0},{title:"Compatibilité · Toujours convertir",value:1}]},
        {title:"Taille des sous-titres",kind:"size",value:session.subtitleSize,options:[{title:"Petite · 75 %",value:75},{title:"Normale · 100 %",value:100},{title:"Grande · 125 %",value:125},{title:"Très grande · 150 %",value:150}]},
        {title:"Réessayer la lecture",kind:"retry",value:0,options:[]}
    ])
    signal chosen(string kind,int value)
    signal closed()
    onVisibleChanged: if (visible) { row=0;submenu="";forceActiveFocus(); }
    function valueTitle(r) { if(!r.options.length)return "";for(var i=0;i<r.options.length;i++) if(r.options[i].value===r.value) return r.options[i].title;return "Par défaut"; }
    function activate() {
        if (submenu) { if (choices.length) chosen(submenu,choices[choice].value);submenu="";return; }
        var selected=rows[row];
        if (selected.kind==="resume") { closed();return; }
        if (selected.kind==="retry") { chosen("retry",0);return; }
        submenu=selected.kind;choices=selected.options;choice=0;
        for(var i=0;i<choices.length;i++) if(choices[i].value===selected.value) choice=i;
    }
    Keys.onPressed: {
        if(event.key===Qt.Key_Back || event.key===Qt.Key_Escape || event.key===Qt.Key_Backspace || event.key===Qt.Key_Left) { if(submenu) submenu="";else closed();event.accepted=true; }
        else if(event.key===Qt.Key_Up || event.key===Qt.Key_Down) { var d=event.key===Qt.Key_Up ? -1 : 1;if(submenu) choice=Math.max(0,Math.min(choices.length-1,choice+d));else row=Math.max(0,Math.min(rows.length-1,row+d));event.accepted=true; }
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Select || event.key===Qt.Key_Right) { activate();event.accepted=true; }
        else if(event.key===Qt.Key_Menu) { closed();event.accepted=true; }
    }
    FontLoader { id: typeface;source:"fonts/NotoSans-Regular.ttf" }
    Rectangle { anchors.fill:parent;color:"#e8000000" }
    Text { textFormat: Text.PlainText; x:110;y:48;text:submenu ? rows[row].title : "Options de lecture";font.family:typeface.name;font.pixelSize:34;font.weight:Font.DemiBold;color:"white" }
    Text { textFormat: Text.PlainText; x:112;y:105;width:1056;text:session.error || session.status;elide:Text.ElideRight;font.family:typeface.name;font.pixelSize:17;color:session.error ? "#ffbaba" : "#59d6a6" }
    ListView {
        id: optionList; objectName: "optionList"
        x:98;y:148;width:1084;height:456;clip:true;interactive:false;spacing:9
        model:panel.submenu ? panel.choices : panel.rows;currentIndex:panel.submenu ? panel.choice : panel.row
        onCurrentIndexChanged: optionScroll.restart()
        onModelChanged: optionScroll.restart()
        Timer { id: optionScroll; interval: 1; onTriggered: {optionList.currentIndex=panel.submenu ? panel.choice : panel.row;optionList.positionViewAtIndex(optionList.currentIndex,ListView.Contain);} }
        highlightRangeMode:ListView.ApplyRange;preferredHighlightBegin:0;preferredHighlightEnd:376;highlightMoveDuration:100
        delegate:Item { width:1084;height:72
            property bool selected:index===(panel.submenu ? panel.choice : panel.row)
            Rectangle { x:14;y:12;width:1056;height:59;radius:7;color:parent.selected ? "#f4f4f4" : "#202020";border.color:parent.selected ? "#59d6a6" : "#404040"
                GlowFrame { visible:parent.parent.selected;corner:7 }
                Image { x:8;y:3;width:94;height:53;visible:panel.submenu==="chapter" && !!modelData.thumb;source:visible ? session.api.imageUrl(modelData.thumb,188,106) : "";fillMode:Image.PreserveAspectCrop;asynchronous:true }
                Text { textFormat: Text.PlainText; x:panel.submenu==="chapter" ? 116 : 20;anchors.verticalCenter:parent.verticalCenter;width:panel.submenu ? 900 : 315;text:modelData.title;font.family:typeface.name;font.pixelSize:20;color:parent.parent.selected ? "#111111" : "white";elide:Text.ElideRight }
                Text { textFormat: Text.PlainText; x:340;anchors.verticalCenter:parent.verticalCenter;width:690;visible:!panel.submenu;text:panel.submenu ? "" : panel.valueTitle(modelData);horizontalAlignment:Text.AlignRight;font.family:typeface.name;font.pixelSize:18;color:parent.parent.selected ? "#145a40" : "#59d6a6";elide:Text.ElideRight }
                MouseArea { anchors.fill:parent;onClicked:{ if(panel.submenu) panel.choice=index;else panel.row=index;panel.activate();panel.forceActiveFocus(); } }
            }
        }
    }
    Rectangle { x:112;y:618;width:1056;height:1;color:"#383838" }
    Text { textFormat: Text.PlainText; x:112;y:628;width:1056;text:panel.convertible ? "La lecture reprend au même endroit après un changement." : "Ce bonus utilise la lecture directe ; les réglages de conversion ne sont pas disponibles.";font.family:typeface.name;font.pixelSize:15;color:"#a9a9a9";elide:Text.ElideRight }
    RemoteHints { x:112;y:663;actions:[{key:"vertical",label:"Naviguer"},{key:"ok",label:"Choisir"},{key:"back",label:panel.submenu ? "Retour" : "Reprendre la vidéo"}] }
}
