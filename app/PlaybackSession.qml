import QtQuick 2.4
import "Plex.js" as Plex
import "Playback.js" as Playback

Item {
    id: session
    property var api
    property var media: ({})
    property string originalUrl: ""
    property int mediaIndex: 0
    property int audioId: 0
    property int subtitleId: 0
    property int qualityIndex: 0
    property int modeIndex: 0
    property int audioOutput: 0
    property int subtitleSize: 100
    property int retryStage: 0
    property int offset: 0
    property int generation: 0
    property bool active: false
    property bool streaming: false
    property bool busy: request.busy
    property string sessionId: ""
    property string status: ""
    property string error: ""
    signal sourceStopping()
    signal sourceReady(string url, int offset, bool streaming)
    signal failed(string message)
    Request { id: request }
    Request { id: heartbeat }
    property var cleanupRequests: []
    Timer { interval:1000; repeat:true; running:session.cleanupRequests.length>0; onTriggered:session.pruneCleanup() }
    Timer { interval: 20000; repeat: true; running: session.active && !!session.sessionId
        onTriggered: heartbeat.send("GET",api.serverUrl+Plex.pathWithQuery("/video/:/transcode/universal/ping",{session:session.sessionId}),api.headers(api.serverToken),function(){},function(){},5000)
    }
    function release() {
        heartbeat.cancel();
        if (!sessionId) return;
        var old=sessionId; sessionId="";
        // Keep cleanup independent without creating/destroying QML request
        // objects during native playback transitions (unstable on the Player).
        var current=null;
        try {
            current=new XMLHttpRequest();
            if (cleanupRequests.length>=16) finishCleanup(cleanupRequests[0].xhr,true);
            cleanupRequests=cleanupRequests.concat([{xhr:current,expires:Date.now()+5000}]);
            current.onreadystatechange=function() {
                if (current.readyState===XMLHttpRequest.DONE) finishCleanup(current,false);
            };
            current.open("GET",api.serverUrl+Plex.pathWithQuery("/video/:/transcode/universal/stop",{session:old}));
            var h=api.headers(api.serverToken);
            for (var key in h) current.setRequestHeader(key,h[key]);
            current.send();
        } catch(e) { if(current) finishCleanup(current,true); }
    }
    function finishCleanup(current, abort) {
        current.onreadystatechange=null;
        cleanupRequests=cleanupRequests.filter(function(entry){return entry.xhr!==current;});
        if (abort) { try { current.abort(); } catch(e) {} }
    }
    function pruneCleanup() {
        var pending=cleanupRequests.slice(),now=Date.now();
        for(var i=0;i<pending.length;i++) if(pending[i].expires<=now) finishCleanup(pending[i].xhr,true);
    }
    function stop() { generation++; request.cancel(); active=false; release(); streaming=false; }
    Component.onDestruction: stop()
    function begin(url, item, position, version) {
        stop(); media=item; originalUrl=url; mediaIndex=Math.max(0,Math.min((item.Media || []).length-1,Number(version) || 0)); retryStage=0; active=true; error="";
        qualityIndex=api.playbackQuality || 0; modeIndex=api.playbackMode || 0; audioOutput=api.playbackAudio || 0; subtitleSize=api.subtitleSize || 100;
        resetTracks(); prepare(position);
    }
    function resetTracks() {
        var tracks=Playback.preferredTracks(media,mediaIndex,api.audioLanguage || "",api.subtitleLanguage || "",api.subtitlePolicy || 0);
        audioId=tracks.audioId;subtitleId=tracks.subtitleId;
    }
    function options() { return {mediaIndex:mediaIndex,audioId:audioId,subtitleId:subtitleId,qualityIndex:qualityIndex,modeIndex:modeIndex,audioOutput:audioOutput,subtitleSize:subtitleSize,retryStage:retryStage,offset:offset}; }
    function fail(message) {
        generation++; request.cancel(); release(); streaming=false;
        // Keep the media/options available for an explicit retry.
        error=message; status=""; failed(message);
    }
    function prepare(position) {
        if (!active) return;
        generation++; var version=generation;request.cancel();release();error="";
        offset=Math.max(0,Math.min(Math.floor(position || 0),Math.max(0,Number(media.duration || position || 0)-1000)));
        sourceStopping();status="Préparation par Plex…";
        if (!Plex.allowedMedia(media,api.libraries) || media.cloudOnly) { fail("Ce média n’est pas disponible.");return; }
        if (!Playback.metadataPath(media)) {
            if (media.isExtra && originalUrl.indexOf(api.serverUrl+"/") === 0) { streaming=false;status="Bande-annonce · Lecture directe";sourceReady(originalUrl,offset,false); }
            else fail("Plex ne fournit pas de source convertible pour ce média.");
            return;
        }
        var direct=Playback.directPart(media,options());
        if (direct) {
            streaming=false;status="Lecture directe · Qualité originale";
            console.log("DEVIALET_DIRECT_READY");
            sourceReady(Plex.mediaUrl(api.serverUrl,direct.key,api.serverToken),offset,false);return;
        }
        var selected=(media.Media || [])[mediaIndex] || {}, part=(selected.Part || [])[0];
        if (!part || !Number(part.id)) { fail("Les informations du fichier sont incomplètes. Rouvrez sa fiche.");return; }
        var selection={allParts:1};
        if (audioId) selection.audioStreamID=audioId;
        selection.subtitleStreamID=subtitleId;
        request.send("PUT",api.serverUrl+Plex.pathWithQuery("/library/parts/"+Number(part.id),selection),api.headers(api.serverToken),function() {
            if (!active || version!==generation) return;
            sessionId="devialet-"+Date.now().toString(36)+"-"+Math.random().toString(36).slice(2);
            var h=api.headers(api.serverToken), params=Playback.parameters(media,options(),sessionId,h["X-Plex-Client-Identifier"],api.connectionLabel);
            request.send("GET",api.serverUrl+Plex.pathWithQuery("/video/:/transcode/universal/decision",params),h,function(body) {
                if (!active || version!==generation) return;
                var result=Playback.decision(body);
                if (!result.ok) { if (!fallback(offset)) fail(result.label);return; }
                streaming=true;status=result.label;
                console.log("DEVIALET_TRANSCODE_READY");
                sourceReady(Plex.mediaUrl(api.serverUrl,Plex.pathWithQuery("/video/:/transcode/universal/start.mkv",params),api.serverToken),Math.floor(offset/1000)*1000,true);
            },function(code) { if (version===generation) networkFailure(code); },30000);
        },function(code) { if (version===generation) networkFailure(code); });
    }
    function networkFailure(code) {
        fail(code===401 || code===403 ? "Plex refuse la conversion. Vérifiez les droits de lecture et de transcodage du compte." : code===-1 ? "Plex met trop de temps à répondre. Réessayez ou réduisez la qualité." : "Le serveur Plex n’a pas pu préparer la lecture. Réessayez depuis les options.");
    }
    function fallback(position) {
        if (!active || !Playback.metadataPath(media) || retryStage>=3) return false;
        retryStage++;prepare(position);return true;
    }
    function change(kind,value,position) {
        if (!active) return;
        if (kind==="version") { if (!Playback.versions(media).some(function(v){return v.value===value;})) return;mediaIndex=value;retryStage=0;resetTracks(); }
        else if (kind==="audio" || kind==="subtitles") {
            var opts=Playback.trackOptions(media,mediaIndex,kind==="audio" ? 2 : 3);
            if (!opts.some(function(v){return v.value===value;})) return;
            if (kind==="audio") audioId=value; else subtitleId=value;
        } else if (kind==="quality") { retryStage=0;qualityIndex=Math.max(0,Math.min(Playback.qualities.length-1,value));api.playbackQuality=qualityIndex; }
        else if (kind==="mode") { retryStage=0;modeIndex=value===1 ? 1 : 0;api.playbackMode=modeIndex; }
        else if (kind==="output") { audioOutput=value===1 ? 1 : 0;api.playbackAudio=audioOutput; }
        else if (kind==="size") { subtitleSize=Math.max(75,Math.min(150,value));api.subtitleSize=subtitleSize; }
        else if (kind==="retry") retryStage=0;
        else return;
        prepare(position);
    }
}
