import QtQuick 2.4

FocusScope {
    id: screen
    enabled: visible
    property var api
    property int selected: 0
    property int column: 0
    onSelectedChanged: scroll.restart()
    onVisibleChanged: {if(visible){selected=0;column=0;forceActiveFocus();scroll.restart();}else focus=false;}
    function toggle(){api.toggleLibrary(selected,column===0 ? "pinned" : "adult");}
    Keys.onPressed: {
        event.accepted=true;
        if(event.key===Qt.Key_Back || event.key===Qt.Key_Escape || event.key===Qt.Key_Backspace)api.closeLibraries();
        else if(event.key===Qt.Key_Up || event.key===Qt.Key_Down)selected=Math.max(0,Math.min(api.libraries.length-1,selected+(event.key===Qt.Key_Up ? -1 : 1)));
        else if(event.key===Qt.Key_Left || event.key===Qt.Key_Right)column=1-column;
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Select)toggle();
    }
    Rectangle {anchors.fill:parent;color:"#080808"}
    FontLoader {id:typeface;source:"fonts/NotoSans-Regular.ttf"}
    Text { textFormat: Text.PlainText;x:96;y:60;text:"Mes bibliothèques";font.family:typeface.name;font.pixelSize:40;color:"white"}
    Text { textFormat: Text.PlainText;x:98;y:125;width:1080;text:api.firstLibrarySetup ? "Choisissez les bibliothèques de votre menu et de votre accueil." : "Vos choix sont mémorisés pour ce profil et ce serveur.";font.family:typeface.name;font.pixelSize:20;color:"#bdbdbd"}
    Text { textFormat: Text.PlainText;x:735;y:190;width:190;horizontalAlignment:Text.AlignHCenter;text:"ÉPINGLÉE";font.family:typeface.name;font.pixelSize:15;color:"#bdbdbd"}
    Text { textFormat: Text.PlainText;x:946;y:190;width:190;horizontalAlignment:Text.AlignHCenter;text:"ADULTES";font.family:typeface.name;font.pixelSize:15;color:"#bdbdbd"}
    ListView {id:list;objectName:"libraryPreferencesList";x:84;y:222;width:1112;height:366;clip:true;interactive:false;model:api.libraries;currentIndex:screen.selected;spacing:6
        onModelChanged:scroll.restart()
        Timer {id:scroll;interval:1;onTriggered:{list.currentIndex=screen.selected;list.positionViewAtIndex(list.currentIndex,ListView.Contain);}}
        delegate:Item {id:libraryRow;width:1112;height:72
            property int libraryIndex: index
            property var library:modelData
            Rectangle {x:12;y:8;width:1080;height:56;radius:7;color:screen.selected===index ? "#262626" : "#171717"}
            Text { textFormat: Text.PlainText;x:30;y:21;width:600;text:modelData.title;elide:Text.ElideRight;font.family:typeface.name;font.pixelSize:22;color:"white"}
            Row {x:650;y:8;spacing:16
                Repeater {model:["pinned","adult"]
                    TvButton {width:196;height:56;text:api.libraryFlag(libraryRow.library.key,modelData) ? "Oui" : "Non";icon:api.libraryFlag(libraryRow.library.key,modelData) ? "check" : "";highlighted:screen.selected===libraryRow.libraryIndex && screen.column===index
                        onClicked:{screen.selected=libraryRow.libraryIndex;screen.column=index;screen.toggle();screen.forceActiveFocus();}
                    }
                }
            }
        }
    }
    Text { textFormat: Text.PlainText;x:98;y:612;width:1080;text:"Signaler une bibliothèque adulte permet de filtrer ses résultats, même sans classification Plex.\nLe filtre de recherche se règle dans Paramètres. Les droits d’accès se gèrent dans Plex.";font.family:typeface.name;font.pixelSize:16;color:"#bdbdbd";lineHeight:1.3}
    Text { textFormat: Text.PlainText;x:98;y:682;text:"Flèches  Naviguer     OK  Modifier     Retour  Revenir";font.family:typeface.name;font.pixelSize:16;color:"#bdbdbd"}
}
