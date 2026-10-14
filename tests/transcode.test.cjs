const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
function library(file){const c={};vm.createContext(c);vm.runInContext(fs.readFileSync(file,'utf8').replace('.pragma library',''),c);return c;}
const Plex=library('app/Plex.js'),Playback=library('app/Playback.js');
const item={ratingKey:'42',key:'/library/metadata/42',librarySectionID:'1',duration:600000,Media:[{videoCodec:'hevc',videoResolution:'4k',Part:[{id:10,key:'/library/parts/10/video.mkv',Stream:[{id:1,streamType:2,codec:'truehd',language:'Français',selected:true},{id:2,streamType:2,codec:'dca',language:'Anglais'},{id:3,streamType:3,codec:'pgs',language:'Français',forced:true,selected:true},{id:4,streamType:3,codec:'ass',language:'Anglais'}]}]},{videoCodec:'h264',Part:[{id:11,Stream:[{id:7,streamType:2,codec:'aac',selected:true}]}]}]};
const accepted={MediaContainer:{generalDecisionCode:1001,transcodeDecisionCode:1001,Metadata:[{Media:[{Part:[{Stream:[{streamType:1,codec:'h264',decision:'transcode'},{streamType:2,codec:'aac',channels:2,decision:'transcode'},{streamType:3,codec:'pgs',decision:'burn'}]}]}]}]}};
function setup(){
 const events=[],stops=[];
 const s={Plex,Playback,Date,Math,Number,console:{log(){}},media:{},generation:0,sessionId:'',active:false,streaming:false,offset:0,error:'',status:'',retryStage:0,mediaIndex:0,audioId:0,subtitleId:0,qualityIndex:0,modeIndex:0,audioOutput:0,subtitleSize:100,
 api:{serverUrl:'https://server',serverToken:'secret',libraries:[{key:'1'}],connectionLabel:'Réseau local',headers(token){return {'X-Plex-Token':token,'X-Plex-Client-Identifier':'device'};}},
 request:{cancel(){},send(method,url,headers,done,failed){s.pending={method,url,headers,done,failed};}},heartbeat:{cancel(){}},sourceStopping(){events.push('stop');},sourceReady(url,offset,streaming){events.push({url,offset,streaming});},failed(message){events.push({error:message});},
 XMLHttpRequest:function(){this.open=(method,url)=>{this.url=url;};this.setRequestHeader=()=>{};this.send=()=>stops.push(this.url);}
 };
 s.session=s;vm.createContext(s);const src=fs.readFileSync('app/PlaybackSession.qml','utf8');
 // QML declarations sit between the methods; extract balanced function bodies.
 const names=['release','stop','begin','resetTracks','options','fail','prepare','networkFailure','fallback','change'];
 for(const name of names){let start=src.indexOf('    function '+name+'('),body=src.indexOf('{',start),depth=1,i=body+1;for(;depth;i++){if(src[i]==='{')depth++;if(src[i]==='}')depth--;}vm.runInContext(src.slice(start,i),s);}
 return {s,events,stops};
}
function prepare(s){s.pending.done({});s.pending.done(accepted);}
test('HTTP Matroska profile converts incompatible video/audio and burns selected subtitles',()=>{
 const p=Playback.parameters(item,{qualityIndex:0,mediaIndex:0,subtitleId:3,modeIndex:0,audioOutput:0,offset:123456},'session','device','Réseau local');
 assert.equal(p.directPlay,0);assert.equal(p.directStream,1);assert.equal(p.directStreamAudio,0);assert.equal(p.subtitles,'burn');assert.equal(p.advancedSubtitles,'burn');assert.equal(p.offset,123);assert.equal(p.partIndex,-1);
 assert.equal(p.protocol,'http');assert.match(p['X-Plex-Client-Profile-Extra'],/container=mkv&videoCodec=h264&audioCodec=aac/);assert.match(p['X-Plex-Client-Profile-Extra'],/video.bitDepth&value=8/);
 assert.equal(Playback.quality(0,'À distance',0).bitrate,4000);assert.equal(Playback.quality(0,'Via relais Plex',0).bitrate,1500);
});
test('selected language and subtitles use the part API before starting conversion',()=>{
 const {s,events}=setup();s.begin('https://server/original',item,123456);
 assert.equal(s.pending.method,'PUT');let q=new URL(s.pending.url).searchParams;
 assert.equal(q.get('audioStreamID'),'1');assert.equal(q.get('subtitleStreamID'),'3');assert.equal(q.get('allParts'),'1');
 prepare(s);const ready=events.at(-1);assert.equal(ready.offset,123000);assert.equal(ready.streaming,true);assert.match(ready.url,/start.mkv/);assert.match(s.status,/incrustés/);
 s.change('audio',2,134567);assert.equal(new URL(s.pending.url).searchParams.get('audioStreamID'),'2');
 s.change('subtitles',0,134567);assert.equal(new URL(s.pending.url).searchParams.get('subtitleStreamID'),'0');s.pending.done({});assert.equal(new URL(s.pending.url).searchParams.get('subtitles'),'none');
});
test('version changes reset track IDs, options persist, and foreign track IDs are refused',()=>{
 const {s}=setup();s.begin('https://server/original',item,0);prepare(s);
 s.change('version',1,45000);assert.equal(s.audioId,7);assert.equal(s.subtitleId,0);assert.match(s.pending.url,/parts\/11/);
 s.change('audio',999,45000);assert.equal(s.audioId,7);
 s.change('quality',3,45000);assert.equal(s.api.playbackQuality,3);
 s.change('output',1,45000);assert.equal(s.api.playbackAudio,1);s.pending.done({});assert.match(new URL(s.pending.url).searchParams.get('X-Plex-Client-Profile-Extra'),/audioCodec=ac3/);
});
test('seek/restart stops the old encoder, stale responses and stop cannot reopen playback',()=>{
 const {s,events,stops}=setup();s.begin('https://server/original',item,60000);s.pending.done({});const old=s.pending;
 s.prepare(300000);assert.equal(stops.length,1);old.done(accepted);assert.equal(events.filter(x=>x.url).length,0);
 const pending=s.pending;s.stop();pending.done({});assert.equal(s.active,false);assert.equal(events.filter(x=>x.url).length,0);
});
test('automatic recovery is bounded and lowers video quality plus audio complexity',()=>{
 const {s}=setup();s.begin('https://server/original',item,0);prepare(s);s.audioOutput=1;
 assert.equal(s.fallback(130000),true);s.pending.done({});let q=new URL(s.pending.url).searchParams;
 assert.equal(q.get('directStream'),'0');assert.equal(q.get('videoResolution'),'1920x1080');assert.equal(q.get('audioChannelCount'),'2');
 assert.equal(s.fallback(131000),true);s.pending.done({});assert.equal(new URL(s.pending.url).searchParams.get('videoResolution'),'1280x720');
 assert.equal(s.fallback(132000),true);s.pending.done({});assert.equal(new URL(s.pending.url).searchParams.get('videoResolution'),'854x480');assert.equal(s.fallback(133000),false);
 assert.equal(Playback.quality(5,'Réseau local',3).bitrate,700);
 assert.equal(Playback.quality(0,'Via relais Plex',2).bitrate,1500);
});
function directItem(){const copy=structuredClone(item);copy.Media[0].Part[0].Stream.forEach(s=>{s.selected=s.streamType===2 && s.id===1;s.default=s.id===1;});return copy;}
test('automatic mode opens the original file without contacting the transcoder, including unknown codecs',()=>{
 const {s,events}=setup();s.begin('',directItem(),123456);
 assert.equal(s.pending,undefined);assert.equal(s.sessionId,'');assert.equal(s.retryStage,0);
 const ready=events.at(-1);assert.equal(ready.streaming,false);assert.equal(ready.offset,123456);
 assert.match(ready.url,/\/library\/parts\/10\/video.mkv/);assert.match(s.status,/Lecture directe/);
});
test('forced conversion, explicit quality and non-default tracks preserve the requested settings',()=>{
 for(const options of [{modeIndex:1},{qualityIndex:3},{subtitleId:3},{audioId:2},{audioOutput:1}]){
  assert.equal(Playback.directPart(directItem(),{mediaIndex:0,audioId:1,...options}),null);
 }
 const multipart=directItem();multipart.Media[0].Part.push({...multipart.Media[0].Part[0],id:99});
 assert.equal(Playback.directPart(multipart,{mediaIndex:0,audioId:1}),null);
 const {s}=setup();s.api.playbackMode=1;s.begin('',directItem(),0);assert.equal(s.pending.method,'PUT');
});
test('failure falls back at the same position and stays converted across seeks and track changes',()=>{
 const {s,events,stops}=setup();s.begin('',directItem(),60000);
 assert.equal(s.fallback(66555),true);prepare(s);
 assert.equal(events.at(-1).streaming,true);assert.equal(events.at(-1).offset,66000);
 s.prepare(90000);prepare(s);assert.equal(s.retryStage,1);assert.equal(events.at(-1).streaming,true);
 s.change('subtitles',0,95000);prepare(s);assert.equal(s.retryStage,1);assert.equal(events.at(-1).streaming,true);
 s.change('audio',999,96000);assert.equal(s.retryStage,1);
 s.change('retry',0,100000);assert.equal(s.retryStage,0);assert.equal(events.at(-1).streaming,false);assert.equal(s.sessionId,'');assert.equal(stops.length,3);
});
test('native default audio wins over file order, while another Plex selection uses the server',()=>{
 const media=directItem();const tracks=media.Media[0].Part[0].Stream;
 tracks[0].default=false;tracks[1].default=true;
 assert.equal(Playback.directPart(media,{mediaIndex:0,audioId:1}),null);
 assert.equal(Playback.directPart(media,{mediaIndex:0,audioId:2}).id,10);
});
test('playback health tolerates brief jitter, detects long or repeated stalls, and expires old stalls',()=>{
 let state=null,position=0;
 for(let i=0;i<120;i++){position+=1000;state=Playback.monitor(state,position);assert.equal(state.failed,false);}
 for(let i=0;i<19;i++)state=Playback.monitor(state,position);
 assert.equal(state.failed,false);state=Playback.monitor(state,position);assert.equal(state.failed,true);
 state=null;position=0;
 for(let i=0;i<3;i++){
  for(let j=0;j<3;j++)state=Playback.monitor(state,position);
  if(i<2){assert.equal(state.failed,false);position+=1000;state=Playback.monitor(state,position);}
 }
 assert.equal(state.failed,true);
 for(let i=0;i<61;i++){position+=1000;state=Playback.monitor(state,position);}
 assert.equal(state.failed,false);assert.equal(state.events.length,0);
});
test('hidden media never triggers conversion; denied access remains a useful error',()=>{
 const {s,events}=setup();s.begin('https://server/original',{...item,librarySectionID:'18'},0);assert.equal(s.pending,undefined);assert.match(events.at(-1).error,/disponible/);
 s.begin('https://server/original',item,0);s.pending.failed(403);assert.match(s.error,/droits/);
 assert.equal(Playback.decision({MediaContainer:{transcodeDecisionCode:2001}}).ok,false);
});
test('track labels preserve ASS/PGS, forced and accessibility information',()=>{
 const opts=Playback.trackOptions(item,0,3);assert.equal(opts[0].value,0);assert.match(opts[1].title,/PGS.*Forcés/);assert.match(opts[2].title,/ASS/);
 assert.match(Playback.trackTitle({codec:'srt',hearingImpaired:true}),/Malentendants/);
 assert.equal(Playback.metadataPath({key:'https://foreign.example',ratingKey:'evil'}),'');
});
test('starting an alternate version selects only streams belonging to that version',()=>{
 const {s}=setup();s.begin('https://server/original',item,60000,1);
 assert.equal(s.mediaIndex,1);assert.equal(s.audioId,7);assert.equal(s.subtitleId,0);
 assert.match(s.pending.url,/parts\/11/);s.pending.done({});assert.equal(new URL(s.pending.url).searchParams.get('mediaIndex'),'1');
});

test('language preferences select matching tracks and fall back without inventing tracks',()=>{
 const item={Media:[{Part:[{Stream:[{id:1,streamType:2,languageCode:'eng',selected:1},{id:2,streamType:2,languageCode:'fre'},{id:3,streamType:3,languageCode:'fra'},{id:4,streamType:3,languageCode:'fra',forced:1}]}]}]};
 const p=Playback.preferredTracks(item,0,'fra','fra',3);assert.equal(p.audioId,2);assert.equal(p.subtitleId,4);
 assert.equal(Playback.preferredTracks(item,0,'eng','fra',3).subtitleId,3);
 assert.equal(Playback.preferredTracks(item,0,'jpn','fra',1).audioId,1);
 assert.equal(Playback.preferredTracks(item,0,'jpn','fra',1).subtitleId,0);
});
