const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const plex = {};
vm.createContext(plex);
vm.runInContext(fs.readFileSync('app/Plex.js','utf8').replace('.pragma library',''),plex);
const intro = {type:'intro',startTimeOffset:10000,endTimeOffset:80000};
const credits = {type:'credits',startTimeOffset:500000,endTimeOffset:550000};

test('down and up only hide or reveal playback commands, including while paused',()=>{
    const source=fs.readFileSync('app/main.qml','utf8');
    const Qt=Object.fromEntries(['Down','Up','Back','Escape','Backspace','MediaStop','Menu','Left','Right','Return','Enter','Select','Space','MediaTogglePlayPause','MediaPlay','MediaPause'].map((k,i)=>['Key_'+k,i]));
    const state={Qt,Date,controlsVisible:true,pausedIntent:false,optionsOpen:false,lastPosition:45000,
        hideControls:{stop(){}},reveal(){state.controlsVisible=true;},openPlaybackOptions(){state.optionsOpen=true;},stopPlayback(){state.stopped=true;},seekPlayback(p){state.sought=p;},setPlaybackPaused(p){state.pausedIntent=p;}};
    vm.createContext(state);vm.runInContext(source.slice(source.indexOf('    function handlePlaybackKey('),source.indexOf('    function playbackFailure(')),state);
    for(const paused of [false,true]){
        state.pausedIntent=paused;assert.equal(state.handlePlaybackKey(Qt.Key_Down),true);assert.equal(state.controlsVisible,false);assert.equal(state.pausedIntent,paused);assert.equal(state.optionsOpen,false);
        state.handlePlaybackKey(Qt.Key_Down);assert.equal(state.controlsVisible,false);
        state.handlePlaybackKey(Qt.Key_Up);assert.equal(state.controlsVisible,true);assert.equal(state.pausedIntent,paused);assert.equal(state.optionsOpen,false);
    }
    state.handlePlaybackKey(Qt.Key_Right);assert.equal(state.sought,55000);
    state.handlePlaybackKey(Qt.Key_Menu);assert.equal(state.optionsOpen,true);
    assert.equal(state.handlePlaybackKey(-1),false);state.handlePlaybackKey(Qt.Key_Back);assert.equal(state.stopped,true);
});

test('dedicated play/pause commands are idempotent and do not restart a failed source',()=>{
    let plays=0,pauses=0;
    const context={pausedIntent:false,switchingSource:false,stream:{error:''},player:{play(){plays++;},pause(){pauses++;}}};
    const source=fs.readFileSync('app/main.qml','utf8');
    const start=source.indexOf('    function setPlaybackPaused('),end=source.indexOf('    function openPlaybackOptions',start);
    vm.createContext(context);vm.runInContext(source.slice(start,end),context);
    context.setPlaybackPaused(true);context.setPlaybackPaused(true);assert.equal(pauses,1);
    context.setPlaybackPaused(false);context.setPlaybackPaused(false);assert.equal(plays,1);
    context.setPlaybackPaused(true);context.stream.error='Failed';context.setPlaybackPaused(false);assert.equal(plays,1);
    context.stream.error='';context.switchingSource=true;context.setPlaybackPaused(true);context.setPlaybackPaused(false);assert.equal(plays,1);
});
test('autoplay pauses after two hours without interaction for long episodes',()=>{
    assert.equal(plex.allowNextCountdown({duration:1320000},0,7199999),true);
    assert.equal(plex.allowNextCountdown({duration:1320000},0,7200000),false);
    assert.equal(plex.allowNextCountdown({duration:1320000},7200000,7200001),true);
    assert.equal(plex.allowNextCountdown({duration:600000},0,7200000),true);
});
test('chapters reject invalid offsets and external artwork',()=>{
    const rows=plex.chapters({duration:600000,Chapter:[{startTimeOffset:0},{startTimeOffset:-1},{startTimeOffset:600000},{startTimeOffset:'NaN'},{startTimeOffset:120000,thumb:'https://example.org/image'}]});
    assert.equal(rows.length,2);assert.equal(rows[1].value,120000);assert.equal(rows[1].thumb,'');
});
test('embedded Qt XML collections are indexed, not NodeList.item',()=>{
    const child={nodeType:1,nodeName:'User',attributes:[{nodeName:'id',nodeValue:'42'}],childNodes:[]};
    const root={nodeType:1,attributes:[{nodeName:'size',nodeValue:'1'}],childNodes:[{nodeType:3},child]};
    assert.equal(plex.xmlNode(root).User[0].id,'42');
    assert.throws(()=>plex.xmlNode(null));
});
test('intro skips at its start, only when enabled and within the marker',()=>{
    assert.equal(plex.skipMarker([intro],9999,600000,true,true,{}),null);
    assert.equal(plex.skipMarker([intro],10000,600000,true,true,{}).target,80000);
    assert.equal(plex.skipMarker([intro],80000,600000,true,true,{}),null);
    assert.equal(plex.skipMarker([intro],20000,600000,false,true,{}),null);
});
test('credits jump to marker end and preserve the post-credit scene',()=>{
    const result = plex.skipMarker([credits],510000,600000,true,true,{});
    assert.equal(result.target,550000);
    assert.equal(plex.skipMarker([credits],510000,600000,true,false,{}),null);
    assert.equal(plex.skipMarker([credits],560000,600000,true,true,{}),null);
    const final = {...credits,startTimeOffset:580000,endTimeOffset:600000,final:1};
    assert.equal(plex.skipMarker([final],590000,600000,true,true,{}).target,600000);
});
test('consumed markers cannot loop after a delayed seek or deliberate rewind',()=>{
    const result=plex.skipMarker([intro],15000,600000,true,true,{});
    const consumed={[result.key]:true};
    assert.equal(plex.skipMarker([intro],16000,600000,true,true,consumed),null);
    assert.equal(plex.skipMarker([intro],10000,600000,true,true,consumed),null);
    assert.equal(plex.skipMarker([intro,credits],510000,600000,true,true,consumed).type,'credits');
});
test('missing, malformed and out-of-range markers never cause a seek',()=>{
    for (const marker of [null,{}, {...intro,startTimeOffset:-1},{...intro,endTimeOffset:900000},{...intro,endTimeOffset:9000},{...intro,startTimeOffset:null},{...intro,endTimeOffset:'bad'},{...intro,type:'commercial'}]) {
        assert.equal(plex.skipMarker([marker],15000,600000,true,true,{}),null);
    }
    assert.equal(plex.skipMarker(undefined,15000,600000,true,true,{}),null);
    assert.equal(plex.skipMarker([intro],15000,0,true,true,{}),null);
});
