    // Injected only by tools/check-playback.py --integration. No timeline writes.
    property var qaConfig: null
    property int qaPhase: 0
    property int qaFailures: 0
    property bool qaFetching: false
    property bool qaDone: false
    property bool qaSavedIntro: true
    property int qaSavedAudio: 0
    property int qaSavedMode: 0
    property int qaSavedQuality: 0
    property bool qaSavedNext: true
    property bool qaSavedCredits: true
    property string qaSavedAudioLanguage: ""
    property string qaSavedSubtitleLanguage: ""
    property int qaSavedSubtitlePolicy: 0
    property double qaPauseStarted: 0
    property double qaSoakStarted: 0
    property double qaSoakPosition: 0
    property double qaSoakLastCheck: 0
    property int qaSoakRetry: 0
    property bool qaSoakStreaming: false
    property double qaResumeBase: 90000
    property double qaTrackPosition: 0
    property int qaCreditsEnd: 0
    property string qaCreditsKey: ""
    Timer { interval:5000;repeat:true;running:!root.qaDone
        onTriggered:console.log("QA_STATE phase="+root.qaPhase+" streaming="+stream.streaming+" retry="+stream.retryStage+" position="+player.position+" absolute="+root.lastPosition+" resume="+root.resumePending+" seekable="+player.seekable+" duration="+player.duration+" state="+player.playbackState+" status="+player.status+" error="+player.error)
    }
    function qaTimeline(item, position, duration, state) {}
    function qaReport(label, okay) {
        console.log((okay ? "QA_PASS " : "QA_FAIL ")+label);
        if(!okay)qaFailures++;
    }
    function qaFinish() {
        if(qaDone)return;qaDone=true;
        if(watching)stopPlayback();
        root.cancelNext();plex.autoNextEpisode=qaSavedNext;plex.autoSkipIntro=qaSavedIntro;plex.autoSkipCredits=qaSavedCredits;plex.playbackAudio=qaSavedAudio;plex.playbackMode=qaSavedMode;plex.playbackQuality=qaSavedQuality;
        plex.audioLanguage=qaSavedAudioLanguage;plex.subtitleLanguage=qaSavedSubtitleLanguage;plex.subtitlePolicy=qaSavedSubtitlePolicy;
        console.log("QA_DONE failures="+qaFailures);
    }
    Timer { interval:1000;repeat:true;running:!root.qaDone
        onTriggered:{
            if(!root.qaFetching){
                root.qaFetching=true;var xhr=new XMLHttpRequest();
                xhr.onreadystatechange=function(){if(xhr.readyState===XMLHttpRequest.DONE && xhr.status===200)root.qaConfig=JSON.parse(xhr.responseText);};
                xhr.open("GET",Qt.resolvedUrl("qa-config.json"));xhr.send();return;
            }
            if(!root.qaConfig || (root.qaPhase===0 && plex.state!=="auth"))return;
            if(root.qaPhase===0){
                // Use only the isolated QA application's state, without cloud login.
                plex.serverUrl=root.qaConfig.serverUrl;plex.serverToken=root.qaConfig.token;
                plex.libraries=root.qaConfig.libraries;plex.connectionLabel="Réseau local";plex.state="library";
                root.qaSavedNext=plex.autoNextEpisode;plex.autoNextEpisode=true;root.qaSavedIntro=plex.autoSkipIntro;root.qaSavedCredits=plex.autoSkipCredits;root.qaSavedAudio=plex.playbackAudio;root.qaSavedMode=plex.playbackMode;root.qaSavedQuality=plex.playbackQuality;
                root.qaSavedAudioLanguage=plex.audioLanguage;root.qaSavedSubtitleLanguage=plex.subtitleLanguage;root.qaSavedSubtitlePolicy=plex.subtitlePolicy;
                plex.audioLanguage="";plex.subtitleLanguage="";plex.subtitlePolicy=0;
                console.log("QA_SAVED_OPTIONS mode="+root.qaSavedMode+" quality="+root.qaSavedQuality+" audio="+root.qaSavedAudio);
                plex.autoSkipIntro=true;plex.playbackAudio=0;plex.playbackMode=root.qaConfig.direct ? 0 : 1;plex.playbackQuality=0;
                var media=root.qaConfig.media;media.Marker=[{type:"intro",startTimeOffset:62000,endTimeOffset:90000}];
                root.qaPhase=1;shell.startPlayback("",media,60000);return;
            }
            if(stream.error && root.qaPhase!==83){root.qaReport("main_server_error",false);root.qaFinish();return;}
            if(root.switchingSource || root.resumePending || stream.busy)return;
            if(root.qaPhase===1 && root.lastPosition>=91000 && player.position>1000){
                console.log("QA_OUTPUT "+stream.status);
                if(stream.subtitleId)root.qaReport("selected_subtitles_burned",stream.status.indexOf("incrustés")>=0);
                root.qaReport("main_intro_and_absolute_timeline",root.lastPosition<100000 && (root.qaConfig.direct ? !stream.streaming && !stream.sessionId : stream.offset===90000));
                if(root.qaConfig.soakSeconds>0){
                    root.qaSoakStarted=Date.now();root.qaSoakLastCheck=root.qaSoakStarted;
                    root.qaSoakPosition=root.lastPosition;root.qaSoakRetry=stream.retryStage;root.qaSoakStreaming=stream.streaming;
                    console.log("QA_SOAK_BEGIN seconds="+root.qaConfig.soakSeconds+" direct="+root.qaConfig.direct);
                    root.qaPhase=11;return;
                }
                root.qaPhase=12;
            }
            if(root.qaPhase===11){
                var elapsed=Date.now()-root.qaSoakStarted;
                if(Date.now()-root.qaSoakLastCheck>=10000){
                    var healthy=player.playbackState===MediaPlayer.PlayingState && player.hasAudio && player.hasVideo && root.lastPosition-root.qaSoakPosition>=7000 && stream.retryStage===root.qaSoakRetry && stream.streaming===root.qaSoakStreaming;
                    root.qaReport("continuous_playback_"+Math.floor(elapsed/1000)+"s",healthy);
                    if(!healthy){root.qaFinish();return;}
                    root.qaSoakPosition=root.lastPosition;root.qaSoakLastCheck=Date.now();
                }
                if(elapsed<root.qaConfig.soakSeconds*1000)return;
                console.log("QA_SOAK_DONE seconds="+Math.floor(elapsed/1000));
                root.qaResumeBase=root.lastPosition;root.qaPhase=12;
            }
            if(root.qaPhase===12){
                if(root.qaConfig.direct){
                    root.qaReport("direct_original_has_image_sound_and_resume",player.hasAudio && player.hasVideo && player.position>=90000 && stream.retryStage===0);
                    player.pause();root.qaPhase=10;return;
                }
                root.openPlaybackOptions();root.qaPhase=2;return;
            }
            if(root.qaPhase===10 && stream.streaming && stream.retryStage===1 && player.position>1000){
                root.qaReport("direct_stall_falls_back_at_same_position",root.lastPosition>=Math.floor(root.qaResumeBase/1000)*1000 && root.lastPosition<root.qaResumeBase+20000 && player.hasAudio && player.hasVideo);
                root.openPlaybackOptions();root.qaPhase=2;return;
            }
            if(root.qaPhase===2){
                root.qaReport("main_options_pause",root.optionsOpen && player.playbackState===MediaPlayer.PausedState);
                var tracks=(root.qaConfig.media.Media[0].Part[0].Stream || []).filter(function(s){return s.streamType===2;});
                var alternate=tracks.filter(function(s){return Number(s.id)!==stream.audioId;});
                var selected=alternate.length ? alternate[alternate.length-1] : tracks[0];
                root.qaTrackPosition=root.lastPosition;
                console.log("QA_TRACK audio language="+(selected.languageCode || "unknown")+" codec="+(selected.codec || "unknown"));
                stream.change("audio",Number(selected.id),root.lastPosition);root.qaPhase=3;return;
            }
            if(root.qaPhase===3 && player.playbackState===MediaPlayer.PausedState){
                console.log("QA_POSITION track_switch actual="+root.lastPosition+" expected="+root.qaTrackPosition+" offset="+stream.offset+" native="+player.position);
                // HTTP conversion offsets are whole seconds, even in pause.
                root.qaReport("main_track_switch_keeps_pause",root.lastPosition>=Math.floor(root.qaTrackPosition/1000)*1000 && root.lastPosition<root.qaTrackPosition+2000);
                root.closePlaybackOptions();root.seekPlayback(180000,true);root.qaPhase=4;return;
            }
            if(root.qaPhase===4 && player.position>1500){
                console.log("QA_POSITION seek actual="+root.lastPosition+" expected=180000 offset="+stream.offset+" native="+player.position);
                // The native position getter leads its QML notification by up
                // to one tick. Check the absolute clock against both values.
                root.qaReport("main_seek_and_resume",root.lastPosition>=180000 && root.lastPosition<190000 && Math.abs(root.lastPosition-(180000+player.position))<1500 && !root.optionsOpen);
                stream.change("output",1,root.lastPosition);root.qaPhase=5;return;
            }
            if(root.qaPhase===5 && player.position>1500){
                root.qaReport(root.qaConfig.direct ? "recovery_stays_in_stereo" : "main_surround",stream.status.indexOf(root.qaConfig.direct ? "AAC" : "AC3")>=0 && player.hasAudio && player.hasVideo);
                // Simulate a stalled backend without a user pause intent.
                player.pause();root.qaPhase=6;return;
            }
            if(root.qaPhase===6 && stream.retryStage===(root.qaConfig.direct ? 2 : 1) && player.playbackState===MediaPlayer.PlayingState && player.position>1000){
                root.qaReport("main_stall_recovery",root.lastPosition>=180000 && root.lastPosition<200000 && stream.status.indexOf("AAC")>=0);
                root.stopPlayback();root.qaReport("main_stop_releases_session",!stream.active && !stream.sessionId && !root.watching);
                if(root.qaConfig.media.type==="episode") {root.stopPlayback(true);root.qaPhase=7;return;}
                root.qaFinish();
            }
            if(root.qaPhase===7 && root.nextMedia.ratingKey){
                root.qaReport("postplay_controlled_end_and_countdown",root.waitingNext && root.nextSeconds>0 && root.nextSeconds<=15 && root.nextMedia.ratingKey!==root.qaConfig.media.ratingKey);
                var next=root.nextMedia;root.cancelNext();root.qaReport("postplay_cancel_releases_focus",!root.waitingNext && !root.watching);
                root.waitingNext=true;root.nextMedia=next;root.startNext();root.qaPhase=8;return;
            }
            if(root.qaPhase===8 && root.watching && player.position>1000){
                root.qaReport("postplay_next_episode_image_and_sound",player.hasAudio && player.hasVideo && root.playingItem.ratingKey!==root.qaConfig.media.ratingKey);
                root.setPlaybackPaused(true);root.setPlaybackPaused(true);
                root.qaPhase=81;return;
            }
            if(root.qaPhase===81 && player.playbackState===MediaPlayer.PausedState){
                if(!root.qaPauseStarted){root.qaPauseStarted=Date.now();return;}
                if(Date.now()-root.qaPauseStarted<35000)return;
                root.qaReport("pause_key_idempotent",root.pausedIntent && player.playbackState===MediaPlayer.PausedState);
                root.qaReport("extended_pause_keeps_session",stream.active && (!stream.streaming || !!stream.sessionId) && !stream.error);
                root.setPlaybackPaused(false);root.setPlaybackPaused(false);
                root.qaPhase=82;return;
            }
            if(root.qaPhase===82 && player.playbackState===MediaPlayer.PlayingState){
                root.qaReport("play_key_idempotent",!root.pausedIntent);
                stream.retryStage=3;root.playbackFailure();
                root.qaPhase=83;return;
            }
            if(root.qaPhase===83){
                root.qaReport("terminal_failure_releases_encoder_and_source",!!stream.error && !stream.sessionId && !stream.streaming && player.source.toString()==="" && !root.resumePending);
                stream.change("retry",0,root.lastPosition);root.qaPhase=9;return;
            }
            if(root.qaPhase===9 && root.watching && player.position>1000){
                root.qaReport("explicit_retry_after_terminal_failure",!stream.error && player.hasAudio && player.hasVideo);
                // A controlled credits marker must skip once while keeping the
                // following scene playable, before testing a real end of stream.
                root.qaCreditsEnd=Math.ceil(root.lastPosition/1000)*1000+6000;
                root.qaCreditsKey="credits:"+(root.qaCreditsEnd-3000)+":"+root.qaCreditsEnd;
                root.playingItem.Marker=[{type:"credits",startTimeOffset:root.qaCreditsEnd-3000,endTimeOffset:root.qaCreditsEnd}];
                plex.autoSkipCredits=true;root.qaPhase=91;return;
            }
            if(root.qaPhase===91 && root.lastPosition>=root.qaCreditsEnd && player.position>1000){
                root.qaReport("credits_skip_preserves_following_scene",!!root.consumedMarkers[root.qaCreditsKey] && root.watching && !root.waitingNext && player.hasAudio && player.hasVideo && root.lastPosition<root.qaCreditsEnd+4000);
                // Let the backend reach a real end of stream; do not inject it.
                plex.autoSkipCredits=false;root.seekPlayback(root.videoDuration-8000,true);
                root.qaPhase=90;return;
            }
            if(root.qaPhase===90 && !root.watching){
                root.qaReport("native_end_of_stream_releases_player",!stream.active && !stream.sessionId && player.source.toString()==="");
                root.qaReport("native_end_of_stream_opens_postplay",root.waitingNext);
                root.qaFinish();
            }
        }
    }
    Timer { interval:240000+(root.qaConfig ? root.qaConfig.soakSeconds*1000 : 0);running:!root.qaDone;onTriggered:{root.qaReport("main_timeout_phase_"+root.qaPhase,false);root.qaFinish();} }
