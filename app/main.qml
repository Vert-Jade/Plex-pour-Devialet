import QtQuick 2.4
import QtMultimedia 5.5
import fbx.application 1.0
import "Plex.js" as Plex
import "Playback.js" as Playback

Application {
    id: root
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    FontLoader { source: "fonts/NotoSans-SemiBold.ttf" }
    property bool watching: false
    property var playingItem: ({})
    property int resumeOffset: 0
    property bool resumePending: false
    property bool resumeSeekIssued: false
    property int lastPosition: 0
    property bool controlsVisible: true
    property string playbackMessage: ""
    property var consumedMarkers: ({})
    property string skipNotice: ""
    property string currentThemeUrl: ""
    property int streamBase: 0
    property bool switchingSource: false
    property bool clearingPlayer: false
    property bool pausedIntent: false
    property bool optionsOpen: false
    property bool optionsWasPaused: false
    property int pendingSeek: -1
    property var playbackHealth: null
    property bool waitingNext: false
    property var nextMedia: ({})
    property int nextSeconds: 15
    property int nextChoice: 0
    property double lastInteraction: Date.now()
    property bool automaticContinuation: false
    readonly property int videoDuration: Number(playingItem.duration || 0) || streamBase + player.duration
    function handleUrl(url) { return false; }
    Component.onCompleted: console.log("DEVIALET_APP_READY")
    PlexService { id: plex
        onNextEpisodeReady: {if(!root.waitingNext)return;if(!media.ratingKey){root.cancelNext();return;}root.nextMedia=media;root.nextSeconds=Plex.allowNextCountdown(root.playingItem,root.lastInteraction,Date.now()) ? 15 : -1;nextPanel.forceActiveFocus();}
    }
    PlaybackSession {
        id: stream; api: plex
        onSourceStopping: {
            pauseAfterStart.stop();
            root.switchingSource=true;root.clearingPlayer=true;root.resumePending=false;root.resumeSeekIssued=false;root.playbackHealth=null;root.controlsVisible=true;
            player.stop();player.source="";root.clearingPlayer=false;
            root.playbackMessage="Préparation de la lecture…";watchdog.restart();
        }
        onSourceReady: {
            root.streamBase=streaming ? offset : 0;root.lastPosition=offset;
            root.resumeOffset=offset;root.resumePending=!streaming && offset>0;
            watchdog.restart();player.source=url;player.play();
        }
        onFailed: {
            watchdog.stop();seekDelay.stop();root.pendingSeek=-1;
            root.resumePending=false;root.resumeSeekIssued=false;root.playbackHealth=null;
            root.clearingPlayer=true;root.switchingSource=true;player.stop();player.source="";
            root.clearingPlayer=false;root.switchingSource=false;
            root.playbackMessage=message;root.controlsVisible=true;
        }
    }
    function stopPlayback(completed) {
        if(completed)lastPosition=videoDuration;
        plex.timeline(playingItem, lastPosition, videoDuration, "stopped");
        watching = false; optionsOpen=false; seekDelay.stop();pendingSeek=-1;stream.stop();
        watchdog.stop(); hideControls.stop(); player.stop(); player.source = "";
        skipNotice = ""; skipToast.stop();
        if(plex.finishPlayback(!!completed))return;
        if(completed && plex.autoNextEpisode && playingItem.type==="episode" && !playingItem.isExtra){waitingNext=true;nextMedia=({});nextChoice=0;nextSeconds=15;nextPanel.forceActiveFocus();plex.prepareNextEpisode(playingItem);}
        else shell.forceActiveFocus();
    }
    function cancelNext() {waitingNext=false;nextMedia=({});plex.cancelNextEpisode();shell.forceActiveFocus();}
    function startNext(automatic) {if(!nextMedia.ratingKey)return;var item=nextMedia;waitingNext=false;nextMedia=({});automaticContinuation=!!automatic;plex.startNextEpisode(item);automaticContinuation=false;if(!watching)shell.forceActiveFocus();}
    Timer {interval:1000;repeat:true;running:root.waitingNext && !!root.nextMedia.ratingKey && root.nextSeconds>0;onTriggered:{root.nextSeconds--;if(root.nextSeconds===0)root.startNext(true);}}
    function reveal() { controlsVisible = true; hideControls.restart(); }
    function playbackFailure() {
        if(!watching || clearingPlayer) return;
        watchdog.stop();controlsVisible=true;
        if(!stream.fallback(lastPosition)) stream.fail("Lecture impossible avec ces réglages. Menu : changer la qualité, les pistes ou réessayer.");
    }
    function seekPlayback(position, immediate) {
        var target=Math.max(0,Math.min(Math.max(0,videoDuration-1000),Math.floor(position)));
        if(stream.streaming) {
            pendingSeek=target;lastPosition=target;
            if(immediate) { seekDelay.stop();pendingSeek=-1;stream.prepare(target); } else seekDelay.restart();
        } else if(player.seekable) { resumeOffset=target;lastPosition=target;resumeSeekIssued=false;resumePending=true;resumeDeadline.restart();playbackHealth=null; }
        else if(!stream.fallback(target)) stream.fail("Ce fichier ne permet pas ce déplacement. Réessayez depuis les options de lecture.");
    }
    function setPlaybackPaused(paused) {
        if (pausedIntent === paused) return;
        pausedIntent=paused;
        if (pausedIntent) player.pause();
        else if(!switchingSource && !stream.error) player.play();
    }
    function openPlaybackOptions() {
        if(optionsOpen) return;
        optionsWasPaused=pausedIntent || player.playbackState===MediaPlayer.PausedState;
        pausedIntent=true;player.pause();optionsOpen=true;controlsVisible=true;hideControls.stop();
    }
    function closePlaybackOptions() {
        optionsOpen=false;pausedIntent=optionsWasPaused;playback.forceActiveFocus();
        if(!pausedIntent && !switchingSource && !stream.error) player.play();
        reveal();
    }
    MediaPlayer {
        id: player
        volume: root.watching ? 1 : plex.themeVolume / 100
        onPlaying: {
            if (root.watching) {
                root.switchingSource=false;root.playbackMessage = ""; watchdog.stop(); root.reveal(); console.log("DEVIALET_PLAYBACK_STARTED");
                // The embedded backend must finish its Playing transition first.
                if(root.pausedIntent) pauseAfterStart.restart();
            } else console.log("DEVIALET_THEME_STARTED");
        }
        onPositionChanged: { if (root.watching && !root.switchingSource && !root.resumePending && root.pendingSeek<0) root.lastPosition = Math.min(root.videoDuration,root.streamBase+position); }
        onPaused: if (root.watching && !root.switchingSource) { root.controlsVisible = true; hideControls.stop(); plex.timeline(root.playingItem, root.lastPosition, root.videoDuration, "paused"); }
        onErrorChanged: {
            if (error !== MediaPlayer.NoError && root.watching) {
                console.log("DEVIALET_PLAYBACK_ERROR " + error);
                root.playbackFailure();
            } else if (error !== MediaPlayer.NoError) { stop(); console.log("DEVIALET_THEME_UNAVAILABLE " + error); }
        }
        onStatusChanged: {
            if (status === MediaPlayer.EndOfMedia && root.watching && !root.switchingSource) root.stopPlayback(true);
        }
    }
    Timer {
        interval: 250; running: root.watching && root.resumePending; repeat: true
        onTriggered: {
            if (root.resumeSeekIssued && Math.abs(player.position-root.resumeOffset)<2000) { root.resumePending=false;root.playbackHealth=null; }
            else if (!root.resumeSeekIssued && !root.switchingSource && player.seekable && player.duration>0) { root.resumeSeekIssued=true;player.seek(root.resumeOffset); }
        }
    }
    Timer { id: watchdog; interval: 45000; onTriggered: root.playbackFailure() }
    Timer { id: pauseAfterStart; interval:1; onTriggered:if(root.watching && root.pausedIntent && !root.switchingSource && player.playbackState===MediaPlayer.PlayingState)player.pause() }
    // A seek may never complete even when the user has paused playback.
    Timer { id: resumeDeadline; interval:12000; running:root.watching && root.resumePending && !root.switchingSource; onTriggered:root.playbackFailure() }
    Timer { interval:1000;repeat:true;running:root.watching && !root.switchingSource && !root.pausedIntent && !root.optionsOpen && !root.playbackMessage
        onRunningChanged: if(!running)root.playbackHealth=null
        onTriggered: { root.playbackHealth=Playback.monitor(root.playbackHealth,root.lastPosition);if(root.playbackHealth.failed)root.playbackFailure(); }
    }
    Timer { id: seekDelay; interval: 300; onTriggered: { var target=root.pendingSeek;root.pendingSeek=-1;if(root.watching && target>=0) stream.prepare(target); } }
    Timer { id: hideControls; interval: 6000; onTriggered: if (!root.optionsOpen && player.playbackState === MediaPlayer.PlayingState) root.controlsVisible = false }
    Timer { interval: 10000; running: root.watching && !root.switchingSource && player.playbackState === MediaPlayer.PlayingState; repeat: true; onTriggered: plex.timeline(root.playingItem, root.lastPosition, root.videoDuration, "playing") }
    Timer {
        interval: 250; repeat: true
        running: root.watching && !root.switchingSource && !root.resumePending && root.pendingSeek<0 && player.playbackState === MediaPlayer.PlayingState
        onTriggered: {
            if (!stream.streaming && !player.seekable) return;
            var marker = Plex.skipMarker(root.playingItem.Marker,root.lastPosition,root.videoDuration,plex.autoSkipIntro,plex.autoSkipCredits,root.consumedMarkers);
            if (!marker) return;
            root.consumedMarkers[marker.key] = true;
            root.seekPlayback(marker.target,true);
            root.skipNotice = marker.type === "intro" ? "Intro passée" : "Générique passé";
            skipToast.restart();
        }
    }
    Timer { id: skipToast; interval: 2500; onTriggered: root.skipNotice = "" }
    Rectangle { anchors.fill: parent; color: "#000000" }
    Image { anchors.fill: parent; source: "assets/login-lounge.png"; fillMode: Image.PreserveAspectCrop; visible: plex.state === "auth" || plex.state === "starting"; asynchronous: true }
    Rectangle { anchors.fill: parent; color: "#33000000"; visible: plex.state === "auth" || plex.state === "starting" }
    VideoOutput { anchors.fill: parent; source: player; visible: root.watching }
    Item {
        id: canvas; width: 1280; height: 720; clip: true
        scale: Math.min(root.width / width, root.height / height) * Math.max(90,Math.min(100,plex.uiScale)) / 100
        anchors.centerIn: parent
        Shell {
            id: shell; anchors.fill: parent; api: plex; visible: !root.watching && !root.waitingNext
            onThemeRequested: {
                if (root.watching) return;
                if (!url) { if (root.currentThemeUrl) { player.stop(); player.source = ""; root.currentThemeUrl = ""; } }
                else if (root.currentThemeUrl !== url) { player.stop(); root.currentThemeUrl = url; player.source = url; player.play(); }
            }
            onStartPlayback: {
                if(!root.automaticContinuation)root.lastInteraction=Date.now();
                root.currentThemeUrl = ""; player.stop();
                root.playingItem = media; root.resumePending = false; root.lastPosition = offset;root.streamBase=0;
                root.pausedIntent=false;root.optionsOpen=false;root.pendingSeek=-1;seekDelay.stop();
                root.consumedMarkers = ({}); root.skipNotice = "";
                root.playbackMessage = media.isExtra ? "Ouverture du bonus…" : "Ouverture de la vidéo…"; root.watching = true; root.controlsVisible = true;
                stream.begin(url,media,offset);playback.forceActiveFocus();
            }
        }
        FocusScope {
            id: playback; anchors.fill: parent; visible: root.watching
            Rectangle {
                x: 970; y: 58; width: 240; height: 52; radius: 5; color: "#ee303030"; visible: !!root.skipNotice
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.skipNotice; color: "#59d6a6"; font.family: typeface.name; font.pixelSize: 21 }
            }
            Keys.onPressed: {
                root.lastInteraction=Date.now();
                root.reveal();
                if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_MediaStop) { root.stopPlayback(); event.accepted = true; }
                else if (event.key === Qt.Key_Menu || event.key === Qt.Key_Up || event.key === Qt.Key_Down) { root.openPlaybackOptions();event.accepted=true; }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) { root.seekPlayback(root.lastPosition + (event.key === Qt.Key_Left ? -10000 : 10000),false); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select || event.key === Qt.Key_Space || event.key === Qt.Key_MediaTogglePlayPause || event.key === Qt.Key_MediaPlay || event.key === Qt.Key_MediaPause) {
                    root.setPlaybackPaused(event.key===Qt.Key_MediaPlay ? false : event.key===Qt.Key_MediaPause ? true : !root.pausedIntent);
                    event.accepted = true;
                }
            }
            Rectangle {
                x: 0; y: 492; width: 1280; height: 228; radius: 0; color: "#ed202020"; visible: root.controlsVisible
                Text { textFormat: Text.PlainText; font.family: typeface.name; x: 68; y: 22; width: 1144; text: Plex.label(root.playingItem); elide: Text.ElideRight; color: "#f5f5f5"; font.pixelSize: 28; font.weight: Font.DemiBold }
                Text { textFormat: Text.PlainText; font.family: typeface.name; x: 68; y: 66; width: 1144; text: root.playbackMessage || (root.pausedIntent ? "En pause · " : "")+stream.status; color: "#cccccc"; font.pixelSize: 18; wrapMode: Text.Wrap }
                Text { textFormat: Text.PlainText; font.family:typeface.name;x:68;y:99;text:root.pausedIntent ? "" : "Fin vers "+Qt.formatTime(new Date(Date.now()+Math.max(0,root.videoDuration-root.lastPosition)),"hh:mm");color:"#aaaaaa";font.pixelSize:14 }
                Rectangle { x: 68; y: 122; width: 1144; height: 5; radius: 2; color: "#555555"; Rectangle { height: parent.height; width: parent.width * Math.min(1, root.lastPosition / Math.max(1, root.videoDuration)); color: "#59d6a6" } }
                Text { textFormat: Text.PlainText; font.family: typeface.name; x: 68; y: 150; text: "OK  Pause     Flèches  Avancer / Reculer     Menu  Audio, sous-titres et qualité"; color: "#cccccc"; font.pixelSize: 15 }
                Text { textFormat: Text.PlainText; font.family: typeface.name; anchors.right: parent.right; anchors.rightMargin: 68; y: 150; text: Plex.clock(root.lastPosition) + " / " + Plex.clock(root.videoDuration); color: "#59d6a6"; font.pixelSize: 20 }
            }
        }
        PlaybackOptions {
            anchors.fill:parent;visible:root.watching && root.optionsOpen;session:stream
            onClosed: {root.lastInteraction=Date.now();root.closePlaybackOptions();}
            onChosen: { root.lastInteraction=Date.now();seekDelay.stop();root.pendingSeek=-1;if(kind==="chapter"){root.seekPlayback(value,true);root.closePlaybackOptions();}else stream.change(kind,value,root.lastPosition); }
        }
        FocusScope {id:nextPanel;anchors.fill:parent;visible:root.waitingNext
            Keys.onPressed:{event.accepted=true;root.nextSeconds=-1;root.lastInteraction=Date.now();if(event.key===Qt.Key_Back || event.key===Qt.Key_Escape || event.key===Qt.Key_Backspace)root.cancelNext();else if(event.key===Qt.Key_Left || event.key===Qt.Key_Right)root.nextChoice=1-root.nextChoice;else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Select){if(root.nextChoice===1)root.cancelNext();else root.startNext();}}
            Rectangle {anchors.fill:parent;color:"#080808"}
            Image {x:540;width:740;height:720;source:plex.imageUrl(root.nextMedia.art || root.nextMedia.thumb || "",1280,720);fillMode:Image.PreserveAspectCrop;asynchronous:true}
            Image {anchors.fill:parent;source:"assets/cinema-shade.svg"}
            Text { textFormat: Text.PlainText;x:96;y:220;text:root.nextMedia.ratingKey ? "ÉPISODE SUIVANT" : "Recherche de l’épisode suivant…";font.family:typeface.name;font.pixelSize:20;color:"#65ffe3"}
            Text { textFormat: Text.PlainText;x:96;y:275;width:900;height:150;text:Plex.label(root.nextMedia);visible:!!root.nextMedia.ratingKey;wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;font.family:typeface.name;font.pixelSize:36;color:"white"}
            Row {x:96;y:484;spacing:20
                TvButton {width:320;height:60;text:root.nextSeconds>0 ? "Lire dans "+root.nextSeconds+" secondes" : "Lire maintenant";available:!!root.nextMedia.ratingKey;highlighted:root.nextChoice===0;onClicked:root.startNext()}
                TvButton {width:240;height:60;text:"Annuler";highlighted:root.nextChoice===1;onClicked:root.cancelNext()}
            }
            Text { textFormat: Text.PlainText;x:96;y:600;text:"Retour  Annuler l’enchaînement";font.family:typeface.name;font.pixelSize:18;color:"#bbbbbb"}
        }
    }
}
