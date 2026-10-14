import QtQuick 2.4
import "../../app"

Item {
    id:root
    width:1280;height:720
    property string lastKind:""
    property int lastValue:-1
    property bool closed:false
    function addChapters() {
        var item=session.media;item.duration=600000;
        item.Chapter=[{startTimeOffset:0,title:"Ouverture"},{startTimeOffset:120000,title:"La rencontre"},{startTimeOffset:300000,title:"Le départ"}];
        session.media=JSON.parse(JSON.stringify(item));
    }
    Rectangle { anchors.fill:parent;color:"black" }
    QtObject { id:api
        property string serverUrl:"http://fixture.invalid"
        property string serverToken:""
        property var libraries:[{key:"1"}]
        property int playbackQuality:0
        property int playbackMode:0
        property int playbackAudio:0
        property int subtitleSize:100
        function headers(token) { return {}; }
    }
    PlaybackSession {
        id:session;api:api;status:"Conversion vidéo · AAC stéréo · Sous-titres incrustés"
        audioId:1;subtitleId:3
        media:({ratingKey:"42",librarySectionID:"1",Media:[{videoResolution:"4k",videoCodec:"hevc",Part:[{id:10,Stream:[{id:1,streamType:2,codec:"truehd",displayTitle:"Français · TrueHD 7.1",selected:true},{id:2,streamType:2,codec:"dca",displayTitle:"Anglais · DTS-HD MA 5.1"},{id:3,streamType:3,codec:"pgs",displayTitle:"Français",forced:true,selected:true},{id:4,streamType:3,codec:"ass",displayTitle:"Anglais · ASS"}]}]}]})
    }
    Item {
        width:1280;height:720;anchors.centerIn:parent;scale:Math.min(parent.width/width,parent.height/height)*.95
        PlaybackOptions {
            id:options;objectName:"playbackOptions";anchors.fill:parent;session:session
            Component.onCompleted:forceActiveFocus()
            onChosen:{root.lastKind=kind;root.lastValue=value;}
            onClosed:root.closed=true
        }
    }
}
