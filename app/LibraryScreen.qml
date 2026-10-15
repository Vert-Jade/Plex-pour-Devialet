import QtQuick 2.4

FocusScope {
    id: screen
    enabled: visible
    property var api
    property int selected: 0
    property bool optionsOpen: false
    property int optionIndex: 0
    readonly property var classifications: [{title:"Non précisée",value:"none"},{title:"Public averti · Films et séries",value:"mature"},{title:"18+ · Contenus explicites",value:"adult"}]
    readonly property var selectedLibrary: api.libraries[selected] || ({})
    function classificationIndex() { return api.libraryFlag(selectedLibrary.key,"adult") ? 2 : api.libraryFlag(selectedLibrary.key,"mature") ? 1 : 0; }
    function openOptions() { if(!api.libraries.length)return; optionIndex=classificationIndex();optionsOpen=true; }
    onSelectedChanged: scroll.restart()
    onVisibleChanged: {if(visible){selected=0;optionsOpen=false;forceActiveFocus();scroll.restart();}else focus=false;}
    function toggle(){if(api.libraries.length)api.toggleLibrary(selected,"pinned");}
    Keys.onPressed: {
        event.accepted=true;
        if(event.key===Qt.Key_Back || event.key===Qt.Key_Escape || event.key===Qt.Key_Backspace){if(optionsOpen)optionsOpen=false;else api.closeLibraries();}
        else if(event.key===Qt.Key_Up || event.key===Qt.Key_Down){var d=event.key===Qt.Key_Up ? -1 : 1;if(optionsOpen)optionIndex=Math.max(0,Math.min(2,optionIndex+d));else selected=Math.max(0,Math.min(api.libraries.length-1,selected+d));}
        else if(event.key===Qt.Key_Right || event.key===Qt.Key_Menu)openOptions();
        else if(event.key===Qt.Key_Left && optionsOpen)optionsOpen=false;
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Select){if(optionsOpen){api.classifyLibrary(selected,classifications[optionIndex].value);optionsOpen=false;}else toggle();}
    }
    Rectangle {anchors.fill:parent;color:"#080808"}
    FontLoader {id:typeface;source:"fonts/NotoSans-Regular.ttf"}
    Text { textFormat: Text.PlainText;x:96;y:60;text:"Mes bibliothèques";font.family:typeface.name;font.pixelSize:40;color:"white"}
    Text { textFormat: Text.PlainText;x:98;y:125;width:1080;text:api.firstLibrarySetup ? "Choisissez les bibliothèques de votre menu et de votre accueil." : "Vos choix sont mémorisés pour ce profil et ce serveur.";font.family:typeface.name;font.pixelSize:20;color:"#bdbdbd"}
    ListView {id:list;objectName:"libraryPreferencesList";x:84;y:222;width:1112;height:366;clip:true;interactive:false;model:api.libraries;currentIndex:screen.selected;spacing:6
        onModelChanged:scroll.restart()
        Timer {id:scroll;interval:1;onTriggered:{list.currentIndex=screen.selected;list.positionViewAtIndex(list.currentIndex,ListView.Contain);}}
        delegate:Item {id:libraryRow;width:1112;height:72
            Rectangle {x:12;y:8;width:1080;height:56;radius:7;color:screen.selected===index && !screen.optionsOpen ? "#f3f3f3" : "#171717"
                GlowFrame {visible:screen.selected===index && !screen.optionsOpen;corner:7}
            }
            TvIcon {x:30;y:24;width:24;height:24;kind:modelData.type==="show" ? "series" : "film";ink:screen.selected===index && !screen.optionsOpen ? "#101010" : "#bdbdbd"}
            Text {textFormat:Text.PlainText;x:78;y:22;width:660;text:modelData.title;elide:Text.ElideRight;font.family:typeface.name;font.pixelSize:22;color:screen.selected===index && !screen.optionsOpen ? "#101010" : "white"}
            Text {textFormat:Text.PlainText;x:756;y:26;width:210;horizontalAlignment:Text.AlignRight;text:api.libraryFlag(modelData.key,"adult") ? "18+ · Explicite" : api.libraryFlag(modelData.key,"mature") ? "Public averti" : "";font.family:typeface.name;font.pixelSize:14;color:screen.selected===index && !screen.optionsOpen ? "#505050" : "#999999"}
            TvIcon {x:995;y:24;width:24;height:24;kind:"pin";visible:api.libraryFlag(modelData.key,"pinned");ink:screen.selected===index && !screen.optionsOpen ? "#07594d" : "#59d6a6"}
            TvIcon {x:1046;y:24;width:24;height:24;kind:"more";ink:screen.selected===index && !screen.optionsOpen ? "#101010" : "#bdbdbd"}
            MouseArea {x:12;y:8;width:1014;height:56;onClicked:{screen.selected=index;screen.toggle();screen.forceActiveFocus();}}
            MouseArea {x:1030;y:8;width:62;height:56;onClicked:{screen.selected=index;screen.openOptions();screen.forceActiveFocus();}}
        }
    }
    Text {textFormat:Text.PlainText;x:98;y:612;width:1080;text:api.libraries.length ? "Épinglez vos favoris pour les retrouver dans le menu et sur l’accueil." : "Aucune bibliothèque disponible pour ce profil.";font.family:typeface.name;font.pixelSize:17;color:"#bdbdbd"}
    RemoteHints {x:98;y:664;actions:[{key:"vertical",label:"Parcourir"},{key:"ok",label:"Épingler / Retirer"},{key:"menu",label:"Options"},{key:"back",label:"Retour"}]}
    Rectangle {anchors.fill:parent;color:"#da000000";visible:screen.optionsOpen
        Rectangle {x:260;y:130;width:760;height:440;radius:14;color:"#1b1b1b";border.color:"#444444"
            Text {textFormat:Text.PlainText;x:30;y:26;width:700;text:screen.selectedLibrary.title || "Bibliothèque";font.family:typeface.name;font.pixelSize:27;color:"white";elide:Text.ElideRight}
            Text {textFormat:Text.PlainText;x:30;y:77;text:"Classification de cette bibliothèque";font.family:typeface.name;font.pixelSize:19;color:"#bdbdbd"}
            Column {x:30;y:124;spacing:10
                Repeater {model:screen.classifications;delegate:TvButton {width:700;height:52;text:modelData.title;icon:screen.classificationIndex()===index ? "check" : "";highlighted:screen.optionIndex===index;onClicked:{api.classifyLibrary(screen.selected,modelData.value);screen.optionsOpen=false;screen.forceActiveFocus();}}}
            }
            Text {textFormat:Text.PlainText;x:30;y:328;width:700;text:"Seuls les contenus explicites sont exclus par le filtre de recherche.\nL’accès des enfants se règle avec les profils et les droits Plex.";font.family:typeface.name;font.pixelSize:16;color:"#bdbdbd";wrapMode:Text.Wrap;lineHeight:1.3}
            RemoteHints {x:30;y:396;keySize:26;textSize:14;actions:[{key:"ok",label:"Choisir"},{key:"back",label:"Annuler"}]}
        }
    }
}
