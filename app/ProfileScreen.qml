import QtQuick 2.4

FocusScope {
    id: screen
    enabled: visible
    property var api
    property int selected: 0
    onSelectedChanged: profileScroll.restart()
    property bool pinMode: false
    property string pin: ""
    property int digit: 0
    readonly property var digits: ["1","2","3","4","5","6","7","8","9","Effacer","0","Valider"]
    onVisibleChanged: {if(visible){selected=0;pinMode=false;pin="";digit=0;forceActiveFocus();}else focus=false;}
    function activate() {
        if(api.profilesLoading)return;
        if(pinMode){
            if(digit===9)pin=pin.slice(0,-1);
            else if(digit===11){if(pin.length===4){var code=pin;pin="";api.chooseProfile(selected,code);}}
            else if(pin.length<4)pin+=digits[digit];
            return;
        }
        if(selected===api.profiles.length){api.loadProfiles();return;}
        var p=api.profiles[selected];if(!p)return;
        if(p.protected===true || p.protected==="1" || p.protected==="true"){pinMode=true;pin="";digit=0;}
        else api.chooseProfile(selected,"");
    }
    Keys.onPressed: {
        event.accepted=true;
        if(event.key===Qt.Key_Back || event.key===Qt.Key_Escape || event.key===Qt.Key_Backspace){if(pinMode){pinMode=false;pin="";}else api.cancelProfiles();}
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Select)activate();
        else if(!api.profilesLoading){
            var d=event.key===Qt.Key_Down ? 1 : event.key===Qt.Key_Up ? -1 : 0;
            if(pinMode){if(d)digit=Math.max(0,Math.min(11,digit+d*3));else if(event.key===Qt.Key_Left || event.key===Qt.Key_Right)digit=Math.max(0,Math.min(11,digit+(event.key===Qt.Key_Left ? -1 : 1)));}
            else selected=Math.max(0,Math.min(api.profiles.length,selected+d));
        }
    }
    Rectangle {anchors.fill:parent;color:"#080808"}
    FontLoader {id:typeface;source:"fonts/NotoSans-Regular.ttf"}
    Brand {x:96;y:36;titleSize:23;logoWidth:70;height:76}
    Text { textFormat: Text.PlainText;x:96;y:130;text:screen.pinMode ? "Code PIN du profil" : "Qui regarde ?";font.family:typeface.name;font.pixelSize:42;font.weight:Font.DemiBold;color:"white"}
    Text { textFormat: Text.PlainText;x:98;y:193;width:1080;text:api.profilesLoading ? "Connexion à Plex…" : api.profileError || (screen.pinMode ? "Saisissez les quatre chiffres de votre code Plex Home." : "Chaque profil retrouve ses bibliothèques et ses lectures en cours.");font.family:typeface.name;font.pixelSize:20;color:api.profileError ? "#ffbaba" : "#bdbdbd";wrapMode:Text.Wrap}
    ListView {x:84;y:254;width:1112;height:374;clip:true;interactive:false;visible:!screen.pinMode;spacing:10;currentIndex:screen.selected;highlightRangeMode:ListView.ApplyRange;highlightMoveDuration:100
        id: profileList
        onCurrentIndexChanged: profileScroll.restart()
        onModelChanged: profileScroll.restart()
        Timer { id: profileScroll; interval: 1; onTriggered: {profileList.currentIndex=screen.selected;profileList.positionViewAtIndex(profileList.currentIndex,ListView.Contain);} }
        model:api.profiles.concat([{title:"Actualiser les profils"}])
        delegate:Item {width:1112;height:70
            TvButton {x:12;y:8;width:1080;height:54;text:(modelData.title || modelData.username || "Profil")+(String(modelData.id || "")===api.profileId ? " · Actuel" : "")+((modelData.protected===true || modelData.protected==="1") ? " · PIN" : "");icon:"user";highlighted:screen.selected===index;onClicked:{screen.selected=index;screen.activate();screen.forceActiveFocus();}}
        }
    }
    Text { textFormat: Text.PlainText;x:96;y:255;width:1080;horizontalAlignment:Text.AlignHCenter;visible:screen.pinMode;text:(screen.pin+"____").slice(0,4).replace(/[0-9]/g,"●").split("").join("    ");font.family:typeface.name;font.pixelSize:32;color:"#65ffe3"}
    Grid {x:442;y:326;columns:3;spacing:14;visible:screen.pinMode
        Repeater {model:screen.digits;delegate:TvButton {width:122;height:56;text:modelData;textSize:18;highlighted:index===screen.digit;onClicked:{screen.digit=index;screen.activate();screen.forceActiveFocus();}}}
    }
    RemoteHints { x:98;y:664;actions:[{key:"arrows",label:"Choisir"},{key:"ok",label:"Valider"},{key:"back",label:"Retour"}] }
}
