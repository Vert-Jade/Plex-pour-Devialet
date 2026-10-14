.pragma library

// Conservative HTTP Matroska profile for the embedded Qt player. PMS decodes
// the source; the Player receives H.264 and a single AAC or AC3 audio track.
var qualities = [
    {title:"Automatique · jusqu’à 1080p",bitrate:12000,resolution:"1920x1080"},
    {title:"1080p · 20 Mbit/s",bitrate:20000,resolution:"1920x1080"},
    {title:"1080p · 8 Mbit/s",bitrate:8000,resolution:"1920x1080"},
    {title:"720p · 4 Mbit/s",bitrate:4000,resolution:"1280x720"},
    {title:"480p · 1,5 Mbit/s",bitrate:1500,resolution:"854x480"},
    {title:"360p · 700 kbit/s",bitrate:700,resolution:"640x360"}
];
function streams(item, version, type) {
    var media=(item.Media || [])[version] || {}, part=(media.Part || [])[0] || {};
    return (part.Stream || []).filter(function(s){return Number(s.streamType) === type && Number(s.id) > 0;});
}
function selectedId(rows, fallback) {
    for (var i=0;i<rows.length;i++) if (rows[i].selected) return Number(rows[i].id);
    return fallback && rows.length ? Number(rows[0].id) : 0;
}
function languageMatches(stream,language) {
    var aliases={fr:"fra",fre:"fra",en:"eng",ja:"jpn",es:"spa",de:"deu",ger:"deu",it:"ita"};
    var code=String(stream.languageCode || stream.languageTag || "").toLowerCase().split("-")[0];
    return !!language && (aliases[code] || code)===language;
}
function preferredTracks(item,version,audioLanguage,subtitleLanguage,policy) {
    var audio=streams(item,version,2),subs=streams(item,version,3),audioId=selectedId(audio,true),subtitleId=selectedId(subs,false);
    var preferred=audio.filter(function(s){return languageMatches(s,audioLanguage);});if(preferred.length)audioId=Number(preferred[0].id);
    var matching=subs.filter(function(s){return languageMatches(s,subtitleLanguage);}),chosenAudio=audio.filter(function(s){return Number(s.id)===audioId;})[0] || {};
    if(policy===1)subtitleId=0;
    else if(policy===2 || policy===3) {
        var foreign=!!(subtitleLanguage || audioLanguage) && !languageMatches(chosenAudio,subtitleLanguage || audioLanguage);
        var candidates=subtitleLanguage ? matching : subs;
        if(policy===3 && !foreign)candidates=candidates.filter(function(s){return !!s.forced;});
        else candidates.sort(function(a,b){return Number(!!a.forced)-Number(!!b.forced);});
        subtitleId=candidates.length ? Number(candidates[0].id) : 0;
    } else if(matching.length && subtitleId) subtitleId=Number(matching[0].id);
    return {audioId:audioId,subtitleId:subtitleId};
}
function trackTitle(s) {
    var language=s.language || s.languageCode || "Langue non précisée";
    var title=s.displayTitle || s.extendedDisplayTitle || language;
    if (s.title && title.indexOf(s.title)<0) title += " · " + s.title;
    if (s.codec && title.toLowerCase().indexOf(s.codec.toLowerCase())<0) title += " · " + s.codec.toUpperCase();
    if (s.forced && !/forc/i.test(title)) title += " · Forcés";
    if ((s.hearingImpaired || s.accessibility) && !/sdh|malentend/i.test(title)) title += " · Malentendants";
    return title;
}
function trackOptions(item, version, type) {
    var rows=streams(item,version,type).map(function(s){return {title:trackTitle(s),value:Number(s.id)};});
    if (type === 3) rows.unshift({title:"Désactivés",value:0});
    if (!rows.length) rows.push({title:"Piste par défaut",value:0});
    return rows;
}
function versions(item) {
    return (item.Media || []).map(function(m,i) {
        return {value:i,title:(m.videoResolution ? String(m.videoResolution).toUpperCase() : "Version "+(i+1)) + (m.videoCodec ? " · "+m.videoCodec.toUpperCase() : "") + (m.bitrate ? " · "+(Number(m.bitrate)/1000).toFixed(1)+" Mbit/s" : "")};
    });
}
function metadataPath(item) {
    if (/^\/library\/metadata\/[^\r\n?#]+$/.test(item.key || "")) return item.key;
    return /^\d+$/.test(String(item.ratingKey || "")) ? "/library/metadata/"+item.ratingKey : "";
}
function directPart(item, options) {
    // Qt 5's player cannot select audio/subtitle tracks. Keep the user's Plex
    // choices by using the server when they differ from the file's default.
    if (options.modeIndex || options.qualityIndex || options.retryStage || options.subtitleId || options.audioOutput) return null;
    var parts=((item.Media || [])[options.mediaIndex] || {}).Part || [];
    if (parts.length !== 1 || !/^\/library\/parts\/[^\r\n?#]+$/.test(parts[0].key || "")) return null;
    var audio=streams(item,options.mediaIndex,2), nativeTrack=audio.filter(function(s){return !!s.default;})[0] || audio[0];
    if (nativeTrack && Number(nativeTrack.id) !== options.audioId) return null;
    return parts[0];
}
function monitor(previous, position) {
    var state=previous || {position:position,clock:0,stalled:0,events:[]};
    var clock=state.clock+1, stalled=position>state.position+100 ? 0 : state.stalled+1;
    var events=state.events.filter(function(t){return clock-t<60;});
    if (stalled===3) events.push(clock);
    return {position:position,clock:clock,stalled:stalled,events:events,failed:stalled>=20 || events.length>=3};
}
function quality(index, connection, retry) {
    var q=qualities[Math.max(0,Math.min(qualities.length-1,index))] || qualities[0];
    if (index === 0 && connection !== "Réseau local") q=qualities[connection === "Via relais Plex" ? 4 : 3];
    // First recovery retains the quality ceiling. Further failures lower it;
    // never raise an explicitly selected or relay-limited bitrate.
    if (retry>=2) { var ceiling=qualities[retry>=3 ? 4 : 3];if(q.bitrate>ceiling.bitrate)q=ceiling; }
    return q;
}
function parameters(item, options, session, client, connection) {
    var q=quality(options.qualityIndex,connection,options.retryStage);
    var surround=options.audioOutput === 1 && !options.retryStage;
    var audio=surround ? "ac3" : "aac", channels=surround ? 6 : 2;
    var profile="add-transcode-target(type=videoProfile&context=streaming&protocol=http&container=mkv&videoCodec=h264&audioCodec="+audio+"&replace=true)"
        +"+add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=41&replace=true)"
        +"+add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.bitDepth&value=8&replace=true)"
        +"+add-limitation(scope=videoCodec&scopeName=h264&type=match&name=video.profile&list=baseline|constrained baseline|main|high&replace=true)"
        +"+add-limitation(scope=videoAudioCodec&scopeName="+audio+"&type=upperBound&name=audio.channels&value="+channels+"&replace=true)";
    return {path:metadataPath(item),mediaIndex:options.mediaIndex,partIndex:-1,protocol:"http",
        directPlay:0,directStream:options.modeIndex === 1 || options.retryStage ? 0 : 1,directStreamAudio:0,
        audioChannelCount:channels,maxVideoBitrate:q.bitrate,videoBitrate:q.bitrate,videoResolution:q.resolution,
        videoQuality:100,secondsPerSegment:4,mediaBufferSize:32768,autoAdjustQuality:0,
        subtitles:options.subtitleId ? "burn" : "none",advancedSubtitles:"burn",subtitleSize:options.subtitleSize || 100,
        offset:Math.floor(Math.max(0,options.offset || 0)/1000),copyts:0,fastSeek:1,
        session:session,"X-Plex-Session-Identifier":session,"X-Plex-Client-Identifier":client,
        "X-Plex-Client-Profile-Name":"Generic","X-Plex-Client-Profile-Extra":profile,"X-Plex-Platform":"Generic",
        "X-Plex-Product":"Plex pour Devialet","X-Plex-Version":"0.4.0"};
}
function decision(body) {
    var c=body.MediaContainer || {}, rows=c.Metadata || [];
    var media=rows.length ? (rows[0].Media || [])[0] || {} : {};
    var parts=media.Part || [], streams=parts.length ? parts[0].Stream || [] : [];
    if (Number(c.generalDecisionCode)>=2000 || Number(c.transcodeDecisionCode)>=2000 || !parts.length)
        return {ok:false,label:"Plex ne peut pas convertir ce média avec les réglages actuels."};
    var video=streams.filter(function(s){return Number(s.streamType)===1;})[0] || {};
    var audio=streams.filter(function(s){return Number(s.streamType)===2;})[0] || {};
    var burn=streams.some(function(s){return Number(s.streamType)===3 && s.decision==="burn";});
    return {ok:true,label:(video.decision==="copy" ? "Vidéo originale" : "Conversion vidéo") + (audio.codec ? " · "+audio.codec.toUpperCase()+" "+(audio.channels===6 ? "5.1" : "stéréo") : "")+(burn ? " · Sous-titres incrustés" : "")};
}
