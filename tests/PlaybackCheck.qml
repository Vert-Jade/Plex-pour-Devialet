import QtQuick 2.4
import QtMultimedia 5.5
import fbx.application 1.0
import "Playback.js" as Playback

Application {
    id:root
    property var item:({})
    property int stage:0
    property int ticks:0
    property int startPosition:-1
    property int base:0
    property bool done:false
    property bool changing:false
    property bool started:false
    property int failures:0
    property bool quick:false
    property bool requireBurn:false
    function handleUrl(url){return false;}
    QtObject { id:api
        property string serverUrl:""
        property string serverToken:""
        property var libraries:[]
        property string connectionLabel:"Réseau local"
        property int playbackQuality:3
        property int playbackMode:0
        property int playbackAudio:0
        property int subtitleSize:100
        function headers(token){return {"Accept":"application/json","X-Plex-Token":token,"X-Plex-Client-Identifier":"devialet-playback-qa","X-Plex-Platform":"Generic"};}
    }
    PlaybackSession {
        id:session;api:api
        onSourceStopping:{changing=true;started=false;tick.stop();deadline.restart();player.stop();player.source="";changing=false;}
        onSourceReady:{base=offset;console.log("QA_SOURCE "+stage+" "+offset+" "+streaming);console.log("QA_OUTPUT "+session.status);if(requireBurn && session.status.indexOf("incrustés")<0){console.log("QA_FAIL subtitles_not_burned");root.failures++;root.next();return;}player.source=url;player.play();}
        onFailed:{console.log("QA_FAIL server "+stage);root.failures++;root.next();}
    }
    MediaPlayer {
        id:player;volume:0.20
        onPlaying:if(!done && !started){started=true;ticks=0;startPosition=position;tick.start();deadline.stop();console.log("QA_STARTED "+stage);}
        onErrorChanged:if(error!==MediaPlayer.NoError && !changing && !done){console.log("QA_FAIL player "+stage+" "+error+" "+errorString.replace(/https?:\/\/\S+/g,"[URL]"));root.failures++;root.next();}
    }
    VideoOutput { anchors.fill:parent;source:player }
    Rectangle { x:30;y:30;width:620;height:60;color:"#dd000000"
        Text { anchors.centerIn:parent;color:"#59d6a6";font.pixelSize:22;text:"Vérification de lecture · étape "+(stage+1)+" / 5" }
    }
    Timer { id:tick;interval:1000;repeat:true
        onTriggered:{
            ticks++;
            if(ticks===2 && stage===0){player.pause();pauseCheck.start();tick.stop();return;}
            if(ticks>=6){
                var okay=player.position-startPosition>1500 && player.hasVideo;
                console.log((okay ? "QA_PASS " : "QA_FAIL progress ")+stage+" position="+player.position+" base="+base+" duration="+player.duration+" video="+player.hasVideo+" audio="+player.hasAudio);
                if(!okay)root.failures++;root.next();
            }
        }
    }
    Timer { id:pauseCheck;interval:1000
        onTriggered:{var okay=player.playbackState===MediaPlayer.PausedState;console.log(okay ? "QA_PAUSE_OK" : "QA_FAIL pause");if(!okay)root.failures++;player.play();tick.start();}
    }
    Timer { id:deadline;interval:45000
        onTriggered:{console.log("QA_FAIL timeout "+stage);root.failures++;root.next();}
    }
    function next(){
        if(done)return;tick.stop();pauseCheck.stop();deadline.stop();
        stage++;
        if(stage>=(quick ? 1 : 5)){done=true;changing=true;player.stop();session.stop();console.log("QA_DONE failures="+failures);return;}
        var audio=Playback.streams(item,0,2),subs=Playback.streams(item,0,3);
        session.modeIndex=1;session.audioId=Number(audio[audio.length-1].id);session.subtitleId=subs.length ? Number(subs[0].id) : 0;
        session.audioOutput=stage===3 ? 1 : 0;
        if(stage===4){session.subtitleId=0;session.qualityIndex=4;}
        session.prepare(stage===1 ? 120000 : stage===2 ? 240000 : stage===3 ? 300000 : 360000);
    }
    Component.onCompleted:{
        var xhr=new XMLHttpRequest();
        xhr.onreadystatechange=function(){if(xhr.readyState!==XMLHttpRequest.DONE)return;if(xhr.status!==200){console.log("QA_FAIL config");console.log("QA_DONE failures=1");return;}
            var config=JSON.parse(xhr.responseText);api.serverUrl=config.serverUrl;api.serverToken=config.token;api.libraries=config.libraries;item=config.media;quick=!!config.quick;requireBurn=!!config.requireBurn;if(quick)api.playbackMode=1;session.begin("",item,60000,config.versionIndex || 0);
        };
        xhr.open("GET",Qt.resolvedUrl("qa-config.json"));xhr.send();
    }
}
