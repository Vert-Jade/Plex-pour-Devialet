const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const plex={};vm.createContext(plex);vm.runInContext(fs.readFileSync('app/Plex.js','utf8').replace('.pragma library',''),plex);
const AppInfo={};vm.createContext(AppInfo);vm.runInContext(fs.readFileSync('app/AppInfo.js','utf8').replace('.pragma library',''),AppInfo);
const source=fs.readFileSync('app/PlexService.qml','utf8').replace(/\r\n/g,'\n');
const functions=source.slice(source.indexOf('    function headers'),source.indexOf('    Timer {\n        id: poll'))+source.slice(source.indexOf('    function pollPin'),source.lastIndexOf('}'));
function setup(){
 const s={Plex:plex,console:{log(){}},Date,JSON,Math,accountToken:'saved',serverToken:'',serverUrl:'',saved:{authToken:'saved',clientId:'device',serverId:''},error:'',state:'starting',servers:[],history:[],libraries:[{key:'1',type:'movie',title:'Films'}],hubs:[],view:1,home:false,watchlist:false,watchlistReady:false,watchlistItems:[],searchText:'',pageSize:40,filterIndex:0,sortIndex:0,genreKey:'',page:0,busy:false,browseTitle:'Films',browsePath:'',section:{key:'1'},detail:{},code:'',pinId:'123',expiresAt:Date.now()+60000,
 poll:{running:false,start(){this.running=true},stop(){this.running=false}},
 network:{busy:false,cancel(){},send(method,url,headers,done,failed){s.pending={method,url,headers,done,failed}}},
 homeRequest:{busy:false,cancel(){},send(method,url,headers,done,failed){s.homePending={method,url,headers,done,failed}}},
 previewRequest:{busy:false,cancel(){},send(method,url,headers,done,failed){s.previewPending={method,url,headers,done,failed}}},previewDetail:{},previewLoaded(media){s.preview=media},notice:'',
 progressRequest:{busy:false,cancel(){},send(){}},libraryLoaded(){s.loaded=true},detailsLoaded(){s.detailed=true},genresLoaded(){},playbackRequested(){},
 items:[],globalSearch:false,searchGeneration:0,searchResults:[],searchNotice:'',progressQueue:[],pendingFeature:null,profiles:[],profilesLoading:false,profileName:'',profileId:'',profileError:'',
 profileRequest:{cancel(){},send(method,url,headers,done,failed,timeout,format){s.profilePending={method,url,headers,done,failed,format}}},
 refreshRequest:{cancel(){},send(method,url,headers,done,failed){s.refreshPending={method,url,headers,done,failed}}},
 nextRequest:{cancel(){},send(method,url,headers,done,failed){s.nextPending={method,url,headers,done,failed}}},nextEpisodeReady(item){s.nextReady=item},
 progressRetry:{running:false,stop(){this.running=false},restart(){this.running=true}}};
 Object.assign(s.saved,{autoSkipIntro:true,autoSkipCredits:true,rewindSeconds:0,uiScale:95,themeMusic:true,themeVolume:25,rememberAccount:true,allowAdultSearch:false,libraryPreferences:'{"scope":{"pinned":["1"],"adult":[]}}'});s.ownerToken='saved';s.libraryScope='scope';
 Object.defineProperties(s,{libraryPrefs:{get(){return plex.libraryPreferences(s.saved.libraryPreferences,s.libraryScope)}},pinnedLibraries:{get(){return s.libraries.filter(l=>s.libraryPrefs && s.libraryPrefs.pinned.includes(String(l.key)))}},adultLibraries:{get(){return s.libraryPrefs ? s.libraryPrefs.adult : []}}});
 s.api=s;s.AppInfo=AppInfo;vm.createContext(s);vm.runInContext(functions,s);return s;
}

test('global search queries allowed libraries only and filters hidden results',()=>{
 const s=setup();s.serverUrl='https://server';s.search('test');
 assert.equal(new URL(s.homePending.url).pathname,'/library/sections/1/all');
 s.homePending.done({MediaContainer:{Metadata:[{ratingKey:'1',type:'movie',title:'Allowed',librarySectionID:'1'},{ratingKey:'2',type:'movie',title:'Hidden',librarySectionID:'18'},{ratingKey:'3',type:'movie',title:'Scoped result'}]}});
 assert.equal(s.items.length,2);assert.ok(s.items.every(m=>m.librarySectionID==='1'));
 s.openMedia({ratingKey:'hidden',librarySectionID:'18',type:'movie'});assert.ok(s.error);assert.equal(s.detailed,undefined);
});
test('adult search defaults off, filters ratings and skips explicitly marked libraries',()=>{
 const s=setup();s.libraries.push({key:'2',title:'Private shelf',type:'movie'});
 s.toggleLibrary(1,'adult');s.search('film');
 s.homePending.done({MediaContainer:{Metadata:[{ratingKey:'1',type:'movie',contentRating:'XXX'},{ratingKey:'2',type:'movie',contentRating:'fr/18'}]}});
 assert.equal(s.items.length,1);assert.equal(s.items[0].ratingKey,'2');
 s.changePreference(13,1);assert.equal(s.searchResults.length,0);assert.equal(s.items.length,0);
 s.search('film');s.homePending.done({MediaContainer:{Metadata:[{ratingKey:'1',type:'movie',contentRating:'XXX'}]}});
 assert.match(s.homePending.url,/sections\/2\/all/);assert.equal(s.items.length,1);
});
test('pinning is per profile/server, and unpinned media never reaches Home',()=>{
 const s=setup();s.libraries.push({key:'2',title:'Another library',type:'movie'});
 s.showHome();s.pending.done({MediaContainer:{Metadata:[{ratingKey:'1',librarySectionID:'1'},{ratingKey:'2',librarySectionID:'2'}]}});
 assert.equal(s.items.length,1);s.toggleLibrary(0,'pinned');s.showHome();assert.equal(s.hubs.length,0);
 s.toggleLibrary(1,'pinned');assert.equal(s.pinnedLibraries[0].key,'2');
 s.libraryScope='other-profile';assert.equal(s.pinnedLibraries.length,0);assert.equal(s.adultLibraries.length,0);
 s.libraryScope='scope';assert.equal(s.pinnedLibraries[0].key,'2');
});

test('opening playable media requests markers; resume applies saved rewind only',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='server-token';
 s.openMedia({ratingKey:'42',librarySectionID:'1',type:'episode'});
 assert.equal(new URL(s.pending.url).searchParams.get('includeMarkers'),'1');
 s.pending.done({MediaContainer:{Metadata:[{ratingKey:'42',type:'episode',viewOffset:7000,Marker:[{type:'intro',startTimeOffset:0,endTimeOffset:2000}],Media:[{Part:[{key:'/library/parts/1/file.mkv'}]}]}]}});
 assert.equal(s.detail.Marker.length,1);s.saved.rewindSeconds=10;
 s.playbackRequested=(url,media,offset)=>{s.played={url,media,offset}};
 s.play(true);assert.equal(s.played.offset,0);
 s.detail.viewOffset=50000;s.play(true);assert.equal(s.played.offset,40000);
 s.play(false);assert.equal(s.played.offset,0);
});

test('settings write persistent values, clamp the safe area and survive logout',()=>{
 const s=setup();s.changePreference(0,1);s.changePreference(1,1);
 assert.equal(s.saved.autoSkipIntro,false);assert.equal(s.saved.autoSkipCredits,false);
 s.changePreference(2,1);assert.equal(s.saved.rewindSeconds,5);
 s.changePreference(2,-1);assert.equal(s.saved.rewindSeconds,0);
 for(let i=0;i<20;i++) s.changePreference(3,-1);
 assert.equal(s.saved.uiScale,90);
 for(let i=0;i<20;i++) s.changePreference(3,1);
 assert.equal(s.saved.uiScale,100);
 s.logout();assert.equal(s.saved.autoSkipIntro,false);assert.equal(s.saved.uiScale,100);
});

test('theme music uses allowed local library themes and follows the saved setting',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='secret';
 const episode={librarySectionID:'1',grandparentTheme:'/library/metadata/42/theme/1'};
 assert.match(s.themeUrl(episode),/^https:\/\/server\/library\/metadata\/42\/theme\/1/);
 assert.equal(s.themeUrl({...episode,librarySectionID:'18'}),'');
 assert.equal(s.themeUrl({...episode,theme:'https://foreign.example/theme.mp3'}),'');
 s.changePreference(4,1);assert.equal(s.themeUrl(episode),'');
 for(let i=0;i<30;i++)s.changePreference(5,1);
 assert.equal(s.saved.themeVolume,100);
 for(let i=0;i<30;i++)s.changePreference(5,-1);
 assert.equal(s.saved.themeVolume,5);
});

test('trailers play separately, cannot escape the server, never update movie progress',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='secret';
 const extra={title:'Trailer',ratingKey:'99',extraType:1,Media:[{container:'mp4',videoCodec:'h264',audioCodec:'aac',Part:[{key:'/services/iva/assets/1/video.mp4?fmt=4'}]}]};
 s.detail={ratingKey:'42',librarySectionID:'1',viewOffset:12345,Extras:{Metadata:[extra]}};
 s.playbackRequested=(url,media,offset)=>{s.played={url,media,offset}};
 s.playTrailer(0);assert.equal(s.played.offset,0);assert.equal(s.played.media.isExtra,true);assert.equal(s.detail.viewOffset,12345);
 let calls=0;s.progressRequest.send=()=>calls++;
 s.timeline(s.played.media,1000,120000,'playing');s.timeline(s.played.media,120000,120000,'stopped');assert.equal(calls,0);
 s.detail.librarySectionID='18';delete s.played;s.playTrailer(0);assert.equal(s.played,undefined);
 extra.Media[0].Part[0].key='https://foreign.example/video.mp4';assert.equal(plex.trailers(s.detail).length,0);
});

test('Watchlist action reads cloud state and writes only on explicit selection',()=>{
 const s=setup();s.accountToken='account-secret';s.serverUrl='https://server';
 s.toggleWatchlist({type:'movie',guid:'plex://movie/cloud-id',librarySectionID:'1'});
 assert.equal(s.pending.method,'GET');assert.match(s.pending.url,/metadata.provider.plex.tv\/library\/metadata\/cloud-id\/userState/);
 s.pending.done({MediaContainer:{UserState:{watchlistedAt:123}}});
 assert.equal(s.pending.method,'PUT');assert.match(s.pending.url,/removeFromWatchlist/);assert.equal(s.pending.headers['X-Plex-Token'],'account-secret');
 assert.equal(s.notice,'');s.pending.done({});assert.equal(s.notice,'Retiré de Ma liste');
 s.toggleWatchlist({type:'movie',guid:'plex://movie/cloud-id',librarySectionID:'1'});
 s.pending.done({MediaContainer:{UserState:{}}});assert.match(s.pending.url,/addToWatchlist/);
});

test('episode Watchlist action resolves its allowed parent series before the cloud',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='server-secret';
 s.toggleWatchlist({type:'episode',grandparentRatingKey:'series',librarySectionID:'1'});
 assert.equal(s.pending.url,'https://server/library/metadata/series');assert.equal(s.pending.headers['X-Plex-Token'],'server-secret');
 s.pending.done({MediaContainer:{Metadata:[{type:'show',guid:'plex://show/cloud-series',librarySectionID:'1'}]}});
 assert.match(s.pending.url,/cloud-series\/userState/);
 const pending=s.pending;s.toggleWatchlist({type:'movie',guid:'plex://movie/hidden',librarySectionID:'18'});assert.equal(s.pending,pending);
});

test('selected metadata preview stays read-only and rejects hidden responses',()=>{
 const s=setup();s.serverUrl='https://server';
 s.previewMedia({ratingKey:'42',librarySectionID:'1'});assert.equal(s.previewPending.method,'GET');
 s.previewPending.done({MediaContainer:{Metadata:[{ratingKey:'42',theme:'/library/metadata/42/theme/1'}]}});
 assert.equal(s.preview.librarySectionID,'1');assert.equal(s.preview.ratingKey,'42');
 s.previewMedia({ratingKey:'43',librarySectionID:'1'});s.previewPending.done({MediaContainer:{Metadata:[{ratingKey:'43',librarySectionID:'18'}]}});
 assert.equal(s.preview.ratingKey,'42');
});
test('association persists account token then discovers servers',()=>{
 const s=setup();s.connectAccount();s.pending.done({id:123,code:'ABCD',expiresIn:60});assert.equal(s.code,'ABCD');assert.equal(s.poll.running,true);
 s.pollPin();s.pending.done({authToken:'new-token'});assert.equal(s.saved.authToken,'new-token');assert.equal(s.accountToken,'new-token');assert.match(s.pending.url,/user$/);s.pending.done({title:'Test',id:1});assert.match(s.pending.url,/resources/);
});
test('network errors preserve remembered account; revoked access clears it',()=>{
 const s=setup();s.restore();s.pending.failed(0);assert.equal(s.saved.authToken,'saved');assert.equal(s.state,'starting');assert.ok(s.error);
 s.restore();s.pending.failed(401);assert.equal(s.saved.authToken,'');assert.equal(s.state,'auth');
});
test('expired PIN stops polling and does not make a request',()=>{
 const s=setup();s.expiresAt=0;s.pollPin();assert.equal(s.pending,undefined);assert.equal(s.poll.running,false);assert.match(s.message,/expiré/);
});
test('server connections prefer local HTTPS, forbid unencrypted remote and relay last',()=>{
 const result=plex.connections({connections:[{uri:'http://example.com:32400',local:false},{uri:'https://relay.example.com',relay:true},{uri:'https://remote.example.com'},{uri:'http://192.168.1.20:32400',local:true},{uri:'https://local.plex.direct:32400',local:true}]});
 assert.equal(result.length,4);assert.match(result[0].uri,/local.plex/);assert.match(result[3].uri,/relay/);
 assert.equal(plex.connections({httpsRequired:true,connections:[{uri:'http://192.168.1.20:32400',local:true}]}).length,0);
});
test('server identity mismatch never receives server credentials',()=>{
 const s=setup();s.activeServer={clientIdentifier:'expected',accessToken:'server-secret'};s.candidates=[{uri:'https://candidate.example.com'}];s.candidateIndex=0;s.tryConnection();
 assert.equal(s.pending.headers['X-Plex-Token'],undefined);s.pending.done({MediaContainer:{machineIdentifier:'other'}});assert.equal(s.serverToken,'');assert.ok(s.error);
});
test('filter changes reset page and send filtering to the entire server library',()=>{
 const s=setup();s.serverUrl='https://server.example.com';s.page=5;s.changeFilter(1);
 assert.equal(s.page,0);const u=new URL(s.pending.url);assert.equal(u.searchParams.get('unwatched'),'1');assert.equal(u.searchParams.get('X-Plex-Container-Start'),'0');
 s.pending.done({MediaContainer:{Metadata:[{title:'Result'}],size:1,totalSize:108}});assert.equal(s.total,108);assert.equal(s.items.length,1);
});
test('query encoding preserves genres, sorting and paging without injection',()=>{
 const path=plex.libraryPath({key:'2'},2,2,'A&B',40,40);const u=new URL('https://server'+path);
 assert.equal(u.searchParams.get('genre'),'A&B');assert.equal(u.searchParams.get('inProgress'),'1');assert.equal(u.searchParams.get('sort'),'addedAt:desc');assert.equal(u.searchParams.get('X-Plex-Container-Start'),'40');
 assert.equal(plex.mediaUrl('https://server','https://other/path','secret'),'');
 assert.equal(plex.mediaUrl('https://server','//other/path','secret'),'');
});
test('navigation restores a parent page after seasons or episodes',()=>{
 const s=setup();s.serverUrl='https://server';s.browseTitle='Series';s.page=3;s.detail={ratingKey:'42',title:'A series',type:'show'};s.openChildren();assert.equal(s.page,0);assert.equal(s.history.length,1);
 s.back();assert.equal(s.page,3);assert.equal(s.browsePath,'');assert.equal(s.browseTitle,'Series');
});
test('explicit sign out clears tokens and private library state',()=>{
 const s=setup();s.serverToken='secret';s.logout();assert.equal(s.saved.authToken,'');assert.equal(s.accountToken,'');assert.equal(s.serverToken,'');assert.equal(s.items.length,0);assert.equal(s.state,'auth');
});


test('TV tabs load the correct server endpoints and preserve pagination',()=>{
 const s=setup();s.serverUrl='https://server';
 s.selectView(2);assert.match(s.pending.url,/\/library\/sections\/1\/collections/);
 s.selectView(3);assert.match(s.pending.url,/\/playlists\?/);assert.equal(new URL(s.pending.url).searchParams.get('playlistType'),'video');
 s.selectView(4);assert.match(s.pending.url,/\/genre$/);
 s.pending.done({MediaContainer:{Directory:[{title:'Comedy',key:'12'}],size:1}});assert.equal(s.items[0].type,'category');assert.equal(s.items[0].key,'12');
});
test('home puts Continue Watching first and excludes hidden or unknown libraries',()=>{
 const s=setup();s.serverUrl='https://server';s.showHome();assert.match(s.pending.url,/continueWatching/);
 s.pending.done({MediaContainer:{Hub:[{Metadata:[{type:'movie',title:'Allowed',librarySectionID:1},{type:'movie',librarySectionID:2},{type:'movie'}]}]}});
 assert.equal(s.hubs.length,1);assert.equal(s.hubs[0].title,'Continuer à regarder');assert.equal(s.hubs[0].items.length,1);
 assert.match(s.homePending.url,/hubs\/sections\/1/);
 s.homePending.done({MediaContainer:{Hub:[{hubIdentifier:'movie.recentlyadded.1',Metadata:[{type:'movie',title:'New'}]},{hubIdentifier:'movie.toprated.1',Metadata:[{type:'movie',title:'Ignore'}]}]}});
 assert.equal(s.hubs.length,2);assert.equal(s.hubs[1].title,'Nouveaux ajouts · Films');assert.equal(s.hubs[1].items[0].librarySectionID,'1');
});
test('search is encoded and applies to the server, not the current page',()=>{
 const s=setup();s.serverUrl='https://server';s.page=8;s.search('  A&B  ');
 const u=new URL(s.homePending.url);assert.equal(u.searchParams.get('title'),'A&B');assert.equal(u.searchParams.get('X-Plex-Container-Start'),'0');assert.equal(s.view,1);
});
test('category and playlist return to the correct tab and page',()=>{
 const s=setup();s.serverUrl='https://server';s.view=4;s.page=0;s.detail={type:'category',title:'Comedy',key:'12'};s.openChildren();
 let u=new URL(s.pending.url);assert.equal(u.searchParams.get('genre'),'12');assert.equal(u.searchParams.getAll('X-Plex-Container-Start').length,1);
 s.back();assert.equal(s.view,4);assert.equal(s.browsePath,'');
 s.view=3;s.detail={type:'playlist',ratingKey:'99',title:'List'};s.openChildren();assert.match(s.pending.url,/\/playlists\/99\/items/);s.back();assert.equal(s.view,3);
});
test('watch state changes only after server confirmation',()=>{
 const s=setup();s.serverUrl='https://server';s.items=[{ratingKey:'1',viewCount:0,librarySectionID:'1'}];s.detail=s.items[0];s.markWatched();
 assert.equal(s.detail.viewCount,0);assert.match(s.pending.url,/\/:\/scrobble\?/);s.pending.done({});assert.equal(s.detail.viewCount,1);assert.equal(s.items[0].viewCount,1);
 s.markWatched();assert.match(s.pending.url,/unscrobble/);s.pending.failed(0);assert.equal(s.detail.viewCount,1);
});
test('additional sorts and watched filter have explicit server values',()=>{
 const u=new URL('https://server'+plex.libraryPath({key:'1'},3,11,'',0,40));assert.equal(u.searchParams.get('unwatched'),'0');assert.equal(u.searchParams.get('sort'),'duration:desc');
});

test('each library order has two directions and sorts the complete filtered result before paging',()=>{
 const expected=['titleSort:asc','titleSort:desc','addedAt:desc','addedAt:asc','year:desc','year:asc','originallyAvailableAt:desc','originallyAvailableAt:asc','rating:desc','rating:asc','duration:asc','duration:desc'];
 assert.deepEqual(Array.from(plex.librarySorts(),x=>x.value),expected);
 for(let index=0;index<expected.length;index++){
  const s=setup();s.serverUrl='https://server';s.sortIndex=-1;s.page=4;s.filterIndex=2;s.genreKey='A&B';s.changeSort(index);
  const u=new URL(s.pending.url);assert.equal(u.searchParams.get('sort'),expected[index]);assert.equal(u.searchParams.get('inProgress'),'1');assert.equal(u.searchParams.get('genre'),'A&B');assert.equal(u.searchParams.get('X-Plex-Container-Start'),'0');
  s.pending.done({MediaContainer:{Metadata:[],totalSize:100}});s.changePage(1);
  const next=new URL(s.pending.url);assert.equal(next.searchParams.get('sort'),expected[index]);assert.equal(next.searchParams.get('X-Plex-Container-Start'),'40');
 }
 const s=setup();for(const invalid of [-1,12,1.5,NaN])s.changeSort(invalid);assert.equal(s.pending,undefined);assert.equal(s.sortIndex,0);
});

test('library classification preserves pins, migrates previous settings and separates mature from explicit search',()=>{
 const s=setup();s.classifyLibrary(0,'mature');assert.deepEqual(Array.from(s.libraryPrefs.pinned),['1']);assert.deepEqual(Array.from(s.libraryPrefs.mature),['1']);assert.equal(s.adultLibraries.length,0);
 assert.equal(plex.adultSearchResult({contentRating:'fr/18'},s.libraries[0],s.adultLibraries),false);
 s.toggleLibrary(0,'pinned');assert.deepEqual(Array.from(s.libraryPrefs.mature),['1']);
 s.classifyLibrary(0,'adult');assert.equal(s.libraryPrefs.mature.length,0);assert.equal(plex.adultSearchResult({},s.libraries[0],s.adultLibraries),true);
 const saved=s.saved.libraryPreferences;s.classifyLibrary(-1,'none');s.classifyLibrary(0,'unknown');assert.equal(s.saved.libraryPreferences,saved);
 s.classifyLibrary(0,'none');assert.equal(s.adultLibraries.length,0);assert.equal(s.libraryPrefs.mature.length,0);
 s.libraryScope='another-profile';assert.equal(s.libraryPrefs,null);
});

test('empty Home cancels the pending catalogue request and invalid controls leave the current view intact',()=>{
 const s=setup();let canceled=0;s.network.cancel=()=>canceled++;
 s.saved.libraryPreferences='{"scope":{"pinned":[],"adult":[]}}';s.showHome();assert.equal(canceled,1);assert.equal(s.hubs.length,0);assert.ok(s.homeNotice);
 s.genres=[];const section=s.section;s.selectLibrary(900);assert.equal(s.section,section);
 for(const index of [-1,4,0.5,NaN])s.changeFilter(index);s.chooseGenre(1);
 assert.equal(s.pending,undefined);assert.equal(s.filterIndex,0);
});

test('Back can cancel a pending detail request without canceling another operation',()=>{
 const s=setup();let canceled=0;s.network.cancel=()=>canceled++;
 s.network.busy=true;s.lastAction='detail';assert.equal(s.cancelDetails(),true);assert.equal(canceled,1);
 s.lastAction='items';assert.equal(s.cancelDetails(),false);assert.equal(canceled,1);
 s.lastAction='detail';s.network.busy=false;assert.equal(s.cancelDetails(),false);
});

test('libraries sort in French alphabetical order without hardcoded name exclusions',()=>{
 const rows=[{key:'18',title:'18+',type:'movie'},{title:'Séries',type:'show'},{title:'Émissions TV',type:'show'},{title:'Concerts',type:'movie'},{title:'+ 18',type:'movie'},{title:'Films',type:'movie'}];
 assert.equal(plex.visibleLibraries(rows).map(s=>s.title).join('|'),'+ 18|18+|Concerts|Émissions TV|Films|Séries');
 const s=setup();s.serverUrl='https://server';s.saved.sectionKey='18';s.loadLibraries();s.pending.done({MediaContainer:{Directory:rows}});assert.equal(s.libraries.length,6);assert.equal(s.section.key,'18');assert.equal(s.home,true);
});
test('watchlist uses cloud token, resolves local files and removes hidden-only matches',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='local-secret';s.showWatchlist();
 assert.match(s.pending.url,/https:\/\/discover.provider.plex.tv\/library\/sections\/watchlist/);assert.equal(s.pending.headers['X-Plex-Token'],'saved');
 const rows=[{guid:'plex://movie/abc',type:'movie',title:'Allowed'},{guid:'plex://movie/def',type:'movie',title:'Hidden'},{guid:'plex://show/123',type:'show',title:'Unavailable',thumb:'https://untrusted.invalid/p.jpg'}];
 s.pending.done({MediaContainer:{Metadata:rows,totalSize:3}});assert.match(s.pending.url,/library\/all/);assert.equal(s.pending.headers['X-Plex-Token'],'local-secret');
 s.pending.done({MediaContainer:{Metadata:[{guid:rows[0].guid,ratingKey:'10',librarySectionID:1,type:'movie'},{guid:rows[1].guid,ratingKey:'20',librarySectionID:2,type:'movie'}]}});
 assert.equal(s.items.length,2);assert.equal(s.total,2);assert.equal(s.items[0].ratingKey,'10');assert.equal(s.items[0].cloudOnly,false);assert.equal(s.items[1].cloudOnly,true);assert.equal(s.items[1].thumb,'');
});
test('public watchlist artwork never receives server or account tokens',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='secret';assert.equal(s.imageUrl('https://image.tmdb.org/t/p/original/test.jpg',320,480),'https://image.tmdb.org/t/p/w342/test.jpg');assert.equal(s.imageUrl('https://example.com/test.jpg',320,480),'');
});
test('home background replies cannot append rows after leaving Home',()=>{
 const s=setup();s.serverUrl='https://server';s.home=true;s.loadHomeRecent(0);const old=s.homePending;s.home=false;s.hubs=[];old.done({MediaContainer:{Hub:[{hubIdentifier:'movie.recentlyadded.1',Metadata:[{type:'movie'}]}]}});assert.equal(s.hubs.length,0);
});

test('Watchlist fetches subsequent cloud pages before exposing the resolved list',()=>{
 const s=setup();s.serverUrl='https://server';s.showWatchlist();
 s.pending.done({MediaContainer:{Metadata:[{guid:'plex://movie/a',type:'movie'}],totalSize:2}});
 s.pending.done({MediaContainer:{Metadata:[{guid:'plex://movie/a',ratingKey:'1',librarySectionID:1}]}});
 assert.equal(s.watchlistReady,false);assert.equal(new URL(s.pending.url).searchParams.get('X-Plex-Container-Start'),'1');
 s.pending.done({MediaContainer:{Metadata:[{guid:'plex://movie/b',type:'movie'}],totalSize:2}});
 s.pending.done({MediaContainer:{Metadata:[{guid:'plex://movie/b',ratingKey:'2',librarySectionID:2}]}});
 assert.equal(s.watchlistReady,true);assert.equal(s.total,1);assert.equal(s.items[0].ratingKey,'1');
});

test('global search follows every allowed library page and ignores cancelled responses',()=>{
 const s=setup();s.serverUrl='https://server';s.libraries.push({key:'2',title:'Series',type:'show'});s.search('titre');
 const first=s.homePending;first.done({MediaContainer:{totalSize:2,Metadata:[{ratingKey:'1',type:'movie'}]}});
 assert.equal(new URL(s.homePending.url).searchParams.get('X-Plex-Container-Start'),'1');
 s.homePending.done({MediaContainer:{totalSize:2,Metadata:[{ratingKey:'2',type:'movie'}]}});
 assert.match(s.homePending.url,/sections\/2\/all/);
 s.homePending.done({MediaContainer:{Metadata:[{ratingKey:'3',type:'show'},{ratingKey:'secret',type:'movie',librarySectionID:'18'}]}});
 assert.equal(s.items.length,3);assert.equal(s.total,3);
 s.search('old');const old=s.homePending;s.search('new');old.done({MediaContainer:{Metadata:[{ratingKey:'old',type:'movie'}]}});assert.equal(s.searchResults.length,0);
 s.selectLibrary(0);s.homePending.done({MediaContainer:{Metadata:[{ratingKey:'late',type:'movie'}]}});assert.equal(s.globalSearch,false);assert.equal(s.searchResults.length,0);
});

test('the final timeline survives a busy request and retries a transient failure',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='token';s.detail={ratingKey:'1',librarySectionID:'1',viewOffset:0};s.items=[s.detail];
 s.progressRequest.busy=true;s.timeline(s.detail,1000,10000,'playing');s.timeline(s.detail,4500,10000,'stopped');
 assert.equal(s.progressQueue.length,1);assert.equal(s.progressQueue[0].state,'stopped');assert.equal(s.items[0].viewOffset,4500);
 s.progressRequest.busy=false;s.progressRequest.send=(method,url,h,done,failed)=>{s.progressPending={url,done,failed}};s.flushProgress();
 assert.equal(new URL(s.progressPending.url).searchParams.get('time'),'4500');s.progressPending.failed(0);assert.equal(s.progressQueue.length,1);assert.equal(s.progressRetry.running,true);
 s.progressRetry.running=false;s.flushProgress();s.progressPending.done({});assert.equal(s.progressQueue.length,0);assert.match(s.refreshPending.url,/metadata\/1/);
});

test('profile PIN failure keeps the current user; successful switch clears all cached media',()=>{
 const s=setup();s.serverUrl='https://server';s.serverToken='old';s.items=[{ratingKey:'old'}];s.searchResults=[{ratingKey:'old'}];s.home=true;
 s.loadProfiles();assert.equal(s.profilePending.method,'GET');assert.equal(s.profilePending.format,'xml');
 s.profilePending.done({User:[{id:'2',title:'Family',protected:'1'}]});s.chooseProfile(0,'1234');
 assert.equal(new URL(s.profilePending.url).searchParams.get('pin'),'1234');s.profilePending.failed(401);assert.equal(s.serverToken,'old');assert.equal(s.items.length,1);
 s.chooseProfile(0,'5678');s.profilePending.done({authenticationToken:'profile-token'});
 assert.equal(s.accountToken,'profile-token');assert.equal(s.saved.profileToken,'profile-token');assert.equal(s.saved.authToken,'saved');assert.equal(s.items.length,0);assert.equal(s.searchResults.length,0);assert.equal(s.serverToken,'');assert.match(s.pending.url,/resources/);
 s.logout();assert.equal(s.saved.profileToken,'');assert.equal(s.profileName,'');
});

test('revoked profile token never silently restores the owner',()=>{
 const s=setup();s.saved.profileToken='revoked';s.accountToken='revoked';s.restore();s.pending.failed(401);
 assert.equal(s.state,'profiles');assert.equal(s.accountToken,'');assert.equal(s.saved.authToken,'saved');assert.match(s.profilePending.url,/home\/users$/);
});

test('an expired session-only profile keeps the owner available for profile selection',()=>{
 const s=setup();s.accountToken='revoked';s.saved.profileToken='';s.saved.authToken='';s.saved.rememberAccount=false;
 s.items=[{ratingKey:'cached'}];s.restore();s.pending.failed(401);
 assert.equal(s.state,'profiles');assert.equal(s.ownerToken,'saved');assert.equal(s.accountToken,'');assert.equal(s.items.length,0);
 assert.equal(s.saved.authToken,'');assert.equal(s.profilePending.headers['X-Plex-Token'],'saved');
});

test('folder navigation handles PMS JSON entries, local paging and parent restoration',()=>{
 const s=setup();s.serverUrl='https://server';s.selectView(5);
 assert.equal(new URL(s.pending.url).pathname,'/library/sections/1/folder');
 const folders=Array.from({length:43},(_,i)=>({title:'Folder '+i,key:'/library/sections/1/folder?parent='+i}));
 s.pending.done({MediaContainer:{Metadata:folders,size:43}});
 assert.equal(s.total,43);assert.equal(s.items.length,40);assert.equal(s.items[0].type,'folder');
 s.changePage(1);s.pending.done({MediaContainer:{Metadata:folders,size:43}});assert.equal(s.items.length,3);
 s.openItem(0);assert.match(s.pending.url,/folder\?parent=40$/);assert.equal(s.page,0);
 s.pending.done({MediaContainer:{Metadata:[{ratingKey:'42',type:'movie',key:'/library/metadata/42'}]}});
 s.openItem(0);assert.match(s.pending.url,/metadata\/42\?includeMarkers=1/);
 s.back();assert.equal(s.page,1);assert.equal(s.view,5);assert.equal(s.browsePath,'');
});

test('folder listings accept XML-style Directory rows and refuse foreign or traversing paths',()=>{
 const s=setup();s.selectView(5);
 s.pending.done({MediaContainer:{Directory:[{key:'/library/sections/1/folder?parent=2',title:'Allowed'},
 {key:'/library/sections/2/folder',title:'Other'},{key:'https://foreign.example/',title:'External'},
 {key:'/library/sections/1/../folder',title:'Traversal'}]}});
 assert.equal(s.items.length,1);assert.equal(s.items[0].title,'Allowed');
 s.openMedia({type:'folder',key:'/library/sections/2/folder',librarySectionID:'1'});
 assert.ok(s.error);assert.equal(s.history.length,0);
});

test('cinema trailer continues to its film only on completion and once',()=>{
 const s=setup();s.serverUrl='https://server';s.saved.cinemaTrailers=true;
 s.detail={ratingKey:'1',type:'movie',librarySectionID:'1',Media:[{Part:[{key:'/library/parts/1/file.mkv'}]}],Extras:{Metadata:[{ratingKey:'2',extraType:1,Media:[{Part:[{key:'/library/parts/2/file.mp4'}]}]}]}};
 const played=[];s.playbackRequested=(url,item)=>played.push(item);s.play(false);assert.equal(played[0].isExtra,true);s.finishPlayback(false);assert.equal(played.length,1);
 s.play(false);assert.equal(s.finishPlayback(true),true);assert.equal(played.at(-1).ratingKey,'1');assert.equal(s.finishPlayback(true),false);
 s.detail.viewOffset=10000;s.play(true);assert.equal(played.at(-1).ratingKey,'1');assert.equal(s.pendingFeature,null);
});

test('next episode crosses server pages, ends at the series boundary and respects the setting',()=>{
 const s=setup();s.serverUrl='https://server';s.saved.autoNextEpisode=true;
 const item={type:'episode',ratingKey:'1',grandparentRatingKey:'show',librarySectionID:'1'};s.prepareNextEpisode(item);
 s.nextPending.done({MediaContainer:{totalSize:2,Metadata:[item]}});assert.equal(new URL(s.nextPending.url).searchParams.get('X-Plex-Container-Start'),'1');
 s.nextPending.done({MediaContainer:{totalSize:2,Metadata:[{ratingKey:'2',type:'episode'}]}});assert.match(s.nextPending.url,/metadata\/2\?/);
 s.nextPending.done({MediaContainer:{Metadata:[{ratingKey:'2',type:'episode'}]}});assert.equal(s.nextReady.ratingKey,'2');assert.equal(s.nextReady.librarySectionID,'1');
 s.prepareNextEpisode(item);s.nextPending.done({MediaContainer:{totalSize:1,Metadata:[item]}});assert.equal(s.nextReady.ratingKey,undefined);
 s.saved.autoNextEpisode=false;s.nextPending=null;s.prepareNextEpisode(item);assert.equal(s.nextPending,null);
});

test('actor filmography remains in the visible source library and returns to the previous view',()=>{
 const s=setup();s.serverUrl='https://server';s.globalSearch=true;s.page=2;s.detail={librarySectionID:'1',Role:[{id:42,tag:'Actor'}]};s.openActor(0);
 assert.equal(new URL(s.pending.url).pathname,'/library/sections/1/all');assert.equal(new URL(s.pending.url).searchParams.get('actor'),'42');s.back();assert.equal(s.globalSearch,true);assert.equal(s.page,2);
 s.detail.librarySectionID='18';s.pending=null;s.openActor(0);assert.equal(s.pending,null);
});

test('remember-account opt out clears only persistent tokens and explicit sign out clears the session',()=>{
 const s=setup();s.ownerToken='root';s.accountToken='profile';s.saved.authToken='root';s.saved.profileToken='profile';
 s.setRememberAccount(false);assert.equal(s.saved.authToken,'');assert.equal(s.saved.profileToken,'');assert.equal(s.accountToken,'profile');assert.equal(s.ownerToken,'root');
 s.setRememberAccount(true);assert.equal(s.saved.authToken,'root');assert.equal(s.saved.profileToken,'profile');
 s.logout();assert.equal(s.accountToken,'');assert.equal(s.ownerToken,'');
});
test('relative server paths reject encoded traversal, authority changes and control characters',()=>{
 for(const path of ['//foreign/a','/../a','/%2e%2e/a','/a/./b','/\\foreign/a','/%2fforeign/a','/a#fragment','/a%0ab'])assert.equal(plex.safePath(path),false,path);
 assert.equal(plex.safePath('/library/metadata/42?includeExtras=1'),true);
});

test('switching servers discards every old cache even when rating keys overlap',()=>{
 const s=setup();s.serverUrl='https://old';s.serverToken='old-secret';s.profileId='profile';
 s.servers=[{clientIdentifier:'new-server',accessToken:'new-secret',connections:[{uri:'https://new'}]}];
 const old={ratingKey:'42',librarySectionID:'1',title:'Old private title'};
 s.items=[old];s.watchlistItems=[old];s.searchResults=[old];s.detail=old;s.previewDetail=old;
 s.hubs=[{items:[old]}];s.watchlistReady=true;s.total=200;s.page=3;s.browsePath='/old';
 s.progressQueue=[{headers:{'X-Plex-Token':'old-secret'}}];s.progressRetry.running=true;
 s.chooseServer(0);
 assert.equal(s.state,'starting');assert.equal(s.serverToken,'');assert.equal(s.servers.length,1);
 for(const key of ['items','hubs','libraries','watchlistItems','searchResults','progressQueue'])assert.equal(s[key].length,0,key);
 assert.equal(s.detail.title,undefined);assert.equal(s.previewDetail.title,undefined);
 assert.equal(s.total,0);assert.equal(s.browsePath,'');assert.equal(s.profileId,'profile');
 assert.equal(s.pending.headers['X-Plex-Token'],undefined);assert.equal(s.pending.url,'https://new/identity');
 s.pending.done({MediaContainer:{machineIdentifier:'new-server'}});
 assert.equal(s.serverToken,'new-secret');assert.equal(s.pending.url,'https://new/library/sections');
});

test('refreshing or cancelling profiles preserves the originating screen',()=>{
 const s=setup();s.state='library';s.serverUrl='https://server';let cancelled=0;
 s.profileRequest.cancel=()=>cancelled++;
 s.loadProfiles();s.profilePending.done({User:[{id:'1',title:'Test'}]});
 s.loadProfiles();assert.equal(s.profileReturnState,'library');assert.equal(s.profilesLoading,true);
 s.cancelProfiles();assert.equal(cancelled,1);assert.equal(s.profilesLoading,false);
 assert.equal(s.state,'library');assert.equal(s.serverUrl,'https://server');
});

test('watched status propagates to Home, search and Watchlist without losing local fields',()=>{
 const s=setup();s.serverUrl='https://server';const item={ratingKey:'42',librarySectionID:'1',viewCount:0};
 s.detail=item;s.items=[item];s.searchResults=[item];s.hubs=[{title:'Home',key:'home',items:[item]}];
 s.watchlistItems=[{...item,watchlistGuid:'plex://movie/abc'}];s.markWatched();
 assert.equal(s.hubs[0].items[0].viewCount,0);s.pending.done({});
 for(const row of [s.detail,s.items[0],s.searchResults[0],s.watchlistItems[0],s.hubs[0].items[0]])assert.equal(row.viewCount,1);
 assert.equal(s.watchlistItems[0].watchlistGuid,'plex://movie/abc');
});

test('invalid stored settings recover safely without dropping a valid remembered account',()=>{
 for(const value of ['null','[]','false','"value"','broken']){
  const s=setup();s.saved.libraryPreferences=value;s.toggleLibrary(0,'pinned');
  assert.equal(s.pinnedLibraries.length,1);
 }
 const s=setup();Object.assign(s.saved,{uiScale:500,playbackQuality:-5,subtitlePolicy:90,audioLanguage:'unknown',libraryPreferences:'null'});
 s.validatePreferences();assert.equal(s.saved.uiScale,100);assert.equal(s.saved.playbackQuality,0);
 assert.equal(s.saved.subtitlePolicy,3);assert.equal(s.saved.audioLanguage,'');assert.equal(s.saved.libraryPreferences,'{}');
 assert.equal(s.saved.authToken,'saved');s.saved.rememberAccount=false;s.validatePreferences();assert.equal(s.saved.authToken,'');
});

test('transport paths reject hidden control characters and metadata traversal',()=>{
 for(const path of ['/a\tb','/a\u0007b','/a%09b','/a%7fb','/a b'])assert.equal(plex.safePath(path),false);
});
