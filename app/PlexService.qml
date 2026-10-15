import QtQuick 2.4
import fbx.application 1.0
import "Plex.js" as Plex
import "AppInfo.js" as AppInfo

Item {
    id: api
    readonly property string welcomeName: profileName
    property string profileName: ""
    property string profileId: ""
    property var profiles: []
    property string profileError: ""
    property bool profilesLoading: false
    property bool profileSelecting: false
    property string profileReturnState: "library"
    property var progressQueue: []
    property var pendingFeature: null
    property bool globalSearch: false
    property var searchResults: []
    property int searchGeneration: 0
    property string searchNotice: ""
    property string state: "starting"
    property string message: "Connexion à Plex…"
    property string code: ""
    property string pinId: ""
    property double expiresAt: 0
    property string accountToken: ""
    property string ownerToken: ""
    property string serverToken: ""
    property string serverUrl: ""
    property string serverName: ""
    property string connectionLabel: ""
    property var servers: []
    property var libraries: []
    readonly property string libraryScope: profileId+":"+saved.serverId
    readonly property var libraryPrefs: Plex.libraryPreferences(saved.libraryPreferences,libraryScope)
    readonly property var pinnedLibraries: libraries.filter(function(l){return libraryPrefs && libraryPrefs.pinned.indexOf(String(l.key))>=0;})
    readonly property var adultLibraries: libraryPrefs ? libraryPrefs.adult : []
    property bool firstLibrarySetup: false
    property var items: []
    property var hubs: []
    property int view: 1
    property bool home: false
    property bool watchlist: false
    property var watchlistItems: []
    property bool watchlistReady: false
    property string homeNotice: ""
    property string notice: ""
    property var previewDetail: ({})
    property string searchText: ""
    property var genres: []
    property var section: ({})
    property var detail: ({})
    property string browsePath: ""
    property string browseTitle: ""
    property var history: []
    property int filterIndex: 0
    property int sortIndex: 0
    property string genreKey: ""
    property string genreTitle: "Tous les genres"
    property int page: 0
    property int pageSize: 40
    property int total: 0
    property bool busy: network.busy
    property string error: ""
    property string lastAction: "connect"
    property var activeServer: ({})
    property var candidates: []
    property int candidateIndex: 0
    property alias autoSkipIntro: saved.autoSkipIntro
    property alias autoSkipCredits: saved.autoSkipCredits
    property alias rewindSeconds: saved.rewindSeconds
    property alias uiScale: saved.uiScale
    property alias themeMusic: saved.themeMusic
    property alias themeVolume: saved.themeVolume
    property alias playbackQuality: saved.playbackQuality
    property alias playbackMode: saved.playbackMode
    property alias playbackAudio: saved.playbackAudio
    property alias subtitleSize: saved.subtitleSize
    property alias audioLanguage: saved.audioLanguage
    property alias subtitleLanguage: saved.subtitleLanguage
    property alias subtitlePolicy: saved.subtitlePolicy
    property alias cinemaTrailers: saved.cinemaTrailers
    property alias rememberProfile: saved.rememberProfile
    property alias autoNextEpisode: saved.autoNextEpisode
    property alias rememberAccount: saved.rememberAccount
    property alias allowAdultSearch: saved.allowAdultSearch
    signal libraryLoaded()
    signal detailsLoaded()
    signal genresLoaded()
    signal previewLoaded(var media)
    signal playbackRequested(string url, var media, int offset)
    signal nextEpisodeReady(var media)
    Settings {
        id: saved
        property string clientId: ""
        property string authToken: ""
        property string serverId: ""
        property string sectionKey: ""
        property bool autoSkipIntro: true
        property bool autoSkipCredits: true
        property int rewindSeconds: 0
        property int uiScale: 95
        property bool themeMusic: true
        property int themeVolume: 25
        property int playbackQuality: 0
        property int playbackMode: 0
        property int playbackAudio: 0
        property int subtitleSize: 100
        property string audioLanguage: ""
        property string subtitleLanguage: ""
        property int subtitlePolicy: 0
        property bool cinemaTrailers: false
        property bool rememberProfile: true
        property string profileToken: ""
        property bool autoNextEpisode: true
        property bool rememberAccount: true
        property bool allowAdultSearch: false
        property string libraryPreferences: "{}"
        onReady: {
            api.validatePreferences();
            if (!clientId) clientId = "devialet-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2);
            api.ownerToken=authToken;api.accountToken = profileToken || authToken;
            if (authToken) { if(rememberProfile) api.restore();else api.loadProfiles(); } else { api.state = "auth"; api.message = "Retrouvez vos films et séries sur votre télévision."; }
        }
    }
    Request { id: network }
    Request { id: progressRequest }
    Request { id: homeRequest }
    Request { id: previewRequest }
    Request { id: profileRequest }
    Request { id: refreshRequest }
    Request { id: nextRequest }
    Timer { id: progressRetry; interval: 2000; onTriggered: api.flushProgress() }
    Timer { interval: 4500; running: !!api.notice; onTriggered: api.notice = "" }
    property bool homeLoading: homeRequest.busy
    function headers(token) {
        var h = {"Accept":"application/json", "Accept-Language":"fr", "X-Plex-Language":"fr", "X-Plex-Client-Identifier":saved.clientId,
            "X-Plex-Product":AppInfo.name, "X-Plex-Version":AppInfo.version, "X-Plex-Platform":"Freebox"};
        if (token) h["X-Plex-Token"] = token;
        return h;
    }
    function validatePreferences() {
        var ranges = {uiScale:[90,100,95],themeVolume:[5,100,25],playbackQuality:[0,5,0],
            playbackMode:[0,1,0],playbackAudio:[0,1,0],subtitleSize:[75,150,100],subtitlePolicy:[0,3,0]};
        for (var key in ranges) {
            var range = ranges[key], value = Number(saved[key]);
            saved[key] = isFinite(value) ? Math.max(range[0],Math.min(range[1],Math.round(value))) : range[2];
        }
        if ([0,5,10,15,30].indexOf(saved.rewindSeconds) < 0) saved.rewindSeconds = 0;
        var languages = Plex.languages.map(function(l) { return l.value; });
        if (languages.indexOf(saved.audioLanguage) < 0) saved.audioLanguage = "";
        if (languages.indexOf(saved.subtitleLanguage) < 0) saved.subtitleLanguage = "";
        saved.libraryPreferences = JSON.stringify(Plex.preferenceMap(saved.libraryPreferences));
        if (!saved.rememberAccount) { saved.authToken = ""; saved.profileToken = ""; }
    }
    function previewMedia(item) {
        previewRequest.cancel();
        if (!item || !item.ratingKey || item.cloudOnly || !Plex.allowedMedia(item,libraries)) return;
        if (previewDetail.ratingKey === item.ratingKey) { previewLoaded(previewDetail); return; }
        previewRequest.send("GET",serverUrl+"/library/metadata/"+encodeURIComponent(item.ratingKey),headers(serverToken),function(body) {
            var media = ((body.MediaContainer || {}).Metadata || [item])[0];
            if (!media.librarySectionID) media.librarySectionID = item.librarySectionID;
            if (!Plex.allowedMedia(media,libraries)) return;
            previewDetail = media; previewLoaded(media);
        },function(){});
    }
    function toggleWatchlist(item) {
        if (busy || !item || item.cloudOnly || !Plex.allowedMedia(item,libraries)) return;
        if (item.type === "episode" || item.type === "season") {
            var parent = item.type === "episode" ? item.grandparentRatingKey : item.parentRatingKey;
            if (!parent) { notice = "Ouvrez la fiche de la série pour modifier Ma liste."; return; }
            get("/library/metadata/"+encodeURIComponent(parent),function(body) {
                var show = ((body.MediaContainer || {}).Metadata || [])[0];
                if (!show) return;
                if (!show.librarySectionID) show.librarySectionID = item.librarySectionID;
                if (Plex.allowedMedia(show,libraries)) toggleWatchlist(show);
            });
            return;
        }
        if (!/^plex:\/\/(movie|show)\//.test(item.guid || "")) { notice = "Ce titre ne possède pas d’identifiant Watchlist Plex."; return; }
        var key = encodeURIComponent(item.guid.split("/").pop());
        network.send("GET","https://metadata.provider.plex.tv/library/metadata/"+key+"/userState",headers(accountToken),function(body) {
            var states = (body.MediaContainer || {}).UserState || {};
            var state = states instanceof Array ? states[0] || {} : states;
            var removing = !!state.watchlistedAt;
            network.send("PUT","https://discover.provider.plex.tv/actions/"+(removing ? "removeFromWatchlist" : "addToWatchlist")+"?ratingKey="+key,headers(accountToken),function() {
                watchlistReady = false; notice = removing ? "Retiré de Ma liste" : "Ajouté à Ma liste";
            },failure);
        },failure);
    }
    function changePreference(index, direction) {
        if (index === 0) saved.autoSkipIntro = !saved.autoSkipIntro;
        else if (index === 1) saved.autoSkipCredits = !saved.autoSkipCredits;
        else if (index === 2) {
            var options = [0,5,10,15,30];
            var selected = Math.max(0,options.indexOf(saved.rewindSeconds));
            saved.rewindSeconds = options[(selected + (direction < 0 ? -1 : 1) + options.length) % options.length];
        } else if (index === 3) saved.uiScale = Math.max(90,Math.min(100,saved.uiScale + (direction < 0 ? -1 : 1)));
        else if (index === 4) saved.themeMusic = !saved.themeMusic;
        else if (index === 5) saved.themeVolume = Math.max(5,Math.min(100,saved.themeVolume + (direction < 0 ? -5 : 5)));
        else if(index===6 || index===7) {
            var key=index===6 ? "audioLanguage" : "subtitleLanguage",values=Plex.languages.map(function(l){return l.value;}),at=Math.max(0,values.indexOf(saved[key]));
            saved[key]=values[(at+(direction<0 ? -1 : 1)+values.length)%values.length];
        } else if(index===8) saved.subtitlePolicy=((saved.subtitlePolicy || 0)+(direction<0 ? -1 : 1)+4)%4;
        else if(index===9) saved.cinemaTrailers=!saved.cinemaTrailers;
        else if(index===10) saved.rememberProfile=!saved.rememberProfile;
        else if(index===11) saved.autoNextEpisode=!saved.autoNextEpisode;
        else if(index===12) setRememberAccount(!saved.rememberAccount);
        else if(index===13) { saved.allowAdultSearch=!saved.allowAdultSearch;clearSearch(); }
    }
    function setRememberAccount(enabled) {
        saved.rememberAccount=!!enabled;
        if(enabled){saved.authToken=ownerToken;saved.profileToken=accountToken && accountToken!==ownerToken ? accountToken : "";}
        else {saved.authToken="";saved.profileToken="";}
    }
    function failure(status) {
        if (status === 401 && !serverUrl) {
            resetUserData();
            saved.authToken = "";saved.profileToken="";ownerToken="";accountToken = "";profileName="";profileId="";state = "auth";
            message = "Plex demande une nouvelle connexion."; return;
        }
        error = status === 401 || status === 403 ? "Ce compte n’a pas accès à cette bibliothèque." : status === 429 ? "Plex reçoit trop de demandes. Réessayez dans un instant." : status === -2 ? "Le serveur a renvoyé une réponse illisible. Réessayez." : "Connexion indisponible. Votre connexion n’a pas été effacée. Réessayez.";
        console.log("DEVIALET_REQUEST_FAILED " + status);
    }
    function cloud(method, path, token, done, failed) {
        network.send(method, "https://plex.tv/api/v2/" + path, headers(token), done, failed || failure);
    }
    function get(path, done) {
        if (!Plex.safePath(path)) { error = "Adresse de bibliothèque invalide."; return; }
        network.send("GET", serverUrl + path, headers(serverToken), done, failure);
    }
    function restore() {
        error = ""; state = "starting"; lastAction = "connect"; serverUrl = "";
        cloud("GET", "user", accountToken, function(user) { profileName=user.title || user.friendlyName || user.username || "";profileId=String(user.id || "");console.log("DEVIALET_SESSION_RESTORED");discover(); },function(status){
            if(status===401 && ownerToken && accountToken!==ownerToken){resetServerData();saved.profileToken="";accountToken="";loadProfiles();profileError="Choisissez à nouveau votre profil.";}else failure(status);
        });
    }
    function connectAccount() {
        poll.stop(); network.cancel(); code = ""; error = ""; state = "auth";
        message = "Création de votre code…";
        cloud("POST", "pins", "", function(body) {
            if (!body.id || !body.code) { message = "Code indisponible. Réessayez."; return; }
            pinId = String(body.id); code = body.code;
            expiresAt = Date.now() + (Number(body.expiresIn) > 0 ? Number(body.expiresIn) : 180) * 1000;
            message = "Ouvrez plex.tv/link sur votre téléphone et saisissez ce code.";
            poll.start(); console.log("DEVIALET_AUTH_READY");
        }, function(status) { code = ""; message = "Impossible de contacter Plex. Réessayez."; });
    }
    Timer {
        id: poll; interval: 3000; repeat: true
        onTriggered: api.pollPin()
    }
    function pollPin() {
        if (Date.now() >= expiresAt) { poll.stop(); network.cancel(); code = ""; message = "Code expiré. Demandez un nouveau code."; return; }
        if (network.busy) return;
        cloud("GET", "pins/" + encodeURIComponent(pinId), "", function(body) {
            if (body.authToken) {
                poll.stop(); code = "";
                ownerToken=body.authToken;accountToken = body.authToken; saved.authToken = saved.rememberAccount ? body.authToken : "";saved.profileToken="";
                console.log("DEVIALET_AUTH_OK"); restore();
            }
        }, function(status) { poll.stop(); code = ""; message = "Connexion interrompue. Demandez un nouveau code."; });
    }
    function discover() {
        state = "starting"; message = "Recherche de votre serveur…"; error = ""; lastAction = "connect";
        cloud("GET", "resources?includeHttps=1&includeRelay=1", accountToken, function(body) {
            servers = (body instanceof Array ? body : []).filter(function(s) { return String(s.provides).indexOf("server") >= 0 && s.accessToken; });
            if (!servers.length) { error = "Aucun serveur partagé avec ce compte. Vérifiez le partage dans Plex."; return; }
            for (var i = 0; i < servers.length; i++) if (servers[i].clientIdentifier === saved.serverId) { chooseServer(i); return; }
            if (servers.length === 1) chooseServer(0); else state = "servers";
        });
    }
    function showServers() {
        cancelBrowse();network.cancel();previewRequest.cancel();error = ""; state = "servers"; }
    function chooseServer(index) {
        var selected = servers[index];
        if (!selected) return;
        // Library/rating keys are only unique inside a server. Clear every
        // scoped cache and pending callback before changing that boundary.
        resetServerData();
        activeServer = selected;
        state = "starting"; error = ""; lastAction = "server"; message = "Connexion au serveur…";
        serverUrl = ""; serverToken = ""; candidates = Plex.connections(activeServer); candidateIndex = 0; tryConnection();
    }
    function tryConnection() {
        if (candidateIndex >= candidates.length) { error = "Serveur introuvable. Vérifiez qu’il est allumé et accessible."; return; }
        var candidate = candidates[candidateIndex++];
        var base = candidate.uri.replace(/\/$/, "");
        network.send("GET", base + "/identity", headers(""), function(body) {
            if (!body.MediaContainer || body.MediaContainer.machineIdentifier !== activeServer.clientIdentifier) { tryConnection(); return; }
            serverUrl = base; serverToken = activeServer.accessToken; serverName = activeServer.name;
            connectionLabel = candidate.relay ? "Via relais Plex" : candidate.local ? "Réseau local" : "À distance";
            saved.serverId = activeServer.clientIdentifier; loadLibraries();
        }, function() { tryConnection(); }, candidate.local ? 4500 : 8000);
    }
    function loadLibraries() {
        lastAction = "libraries";
        get("/library/sections", function(body) {
            libraries = Plex.visibleLibraries((body.MediaContainer || {}).Directory || []);
            state = "library";
            if (!libraries.length) { items = []; total = 0; error = "Aucune bibliothèque de films ou séries disponible."; return; }
            console.log("DEVIALET_LIBRARIES_OK " + libraries.length);
            var preferred = 0;
            for (var i = 0; i < libraries.length; i++) {
                if (/^films( vf)?$/i.test(libraries[i].title)) preferred = i;
            }
            for (var j = 0; j < libraries.length; j++) if (libraries[j].key === saved.sectionKey) preferred = j;
            section = libraries[preferred];if(!libraryPrefs){firstLibrarySetup=true;openLibraries();}else showHome();
        });
    }
    function clearSearch() {cancelBrowse();searchResults=[];searchText="";if(globalSearch){items=[];total=0;}}
    function openLibraries() {cancelBrowse();network.cancel();previewRequest.cancel();error="";state="libraries";}
    function libraryFlag(key,flag) {return !!libraryPrefs && libraryPrefs[flag].indexOf(String(key))>=0;}
    function toggleLibrary(index,flag) {
        var library=libraries[index];if(!library || ["pinned","adult"].indexOf(flag)<0)return;
        var all = Plex.preferenceMap(saved.libraryPreferences);
        var prefs=libraryPrefs || {pinned:[],adult:[]},key=String(library.key);
        var next={pinned:prefs.pinned.slice(),adult:prefs.adult.slice()},position=next[flag].indexOf(key);
        if(position<0)next[flag].push(key);else next[flag].splice(position,1);
        all[libraryScope]=next;saved.libraryPreferences=JSON.stringify(all);clearSearch();
    }
    function closeLibraries() {
        if(!libraryPrefs){var all=Plex.preferenceMap(saved.libraryPreferences);all[libraryScope]={pinned:[],adult:[]};saved.libraryPreferences=JSON.stringify(all);}
        firstLibrarySetup=false;showHome();
    }
    function selectLibrary(index) {
        cancelBrowse();globalSearch=false;
        homeRequest.cancel();
        section = libraries[index]; if (!section) return;
        home = false; watchlist = false; view = 1; searchText = ""; hubs = [];
        saved.sectionKey = section.key;
        history = []; browsePath = ""; browseTitle = section.title; page = 0; filterIndex = 0; sortIndex = 0; genreKey = ""; genreTitle = "Tous les genres"; genres = []; error = "";
        state = "library"; lastAction = "items";
        get("/library/sections/" + encodeURIComponent(section.key) + "?includeDetails=1", function(body) {
            var types = (body.MediaContainer || {}).Type || [];
            var next = section;
            for (var i = 0; i < types.length; i++) {
                if (types[i].type === section.type && Plex.safePath(types[i].key)) { next.browseKey = types[i].key; break; }
            }
            section = next; loadItems();
        });
    }
    function loadItems() {
        error = ""; lastAction = "items"; state = "library";
        if(!browsePath && globalSearch) { showSearchPage();return; }
        if (!browsePath && watchlist) { if (watchlistReady) showWatchlistPage(); else loadWatchlist(); return; }
        if (!browsePath && view === 0) { loadHubs(); return; }
        var path = browsePath ? Plex.pathWithQuery(browsePath, {"X-Plex-Container-Start":page * pageSize, "X-Plex-Container-Size":pageSize}) : Plex.libraryPath(section, filterIndex, sortIndex, genreKey, page * pageSize, pageSize);
        if (!browsePath && view === 2) path = Plex.pathWithQuery("/library/sections/" + encodeURIComponent(section.key) + "/collections", {"X-Plex-Container-Start":page * pageSize,"X-Plex-Container-Size":pageSize});
        if (!browsePath && view === 3) path = Plex.pathWithQuery("/playlists", {playlistType:"video",sectionID:section.key,"X-Plex-Container-Start":page * pageSize,"X-Plex-Container-Size":pageSize});
        if (!browsePath && view === 4) path = "/library/sections/" + encodeURIComponent(section.key) + "/genre";
        // PMS folder responses can ignore container paging; paginate them locally.
        if (view === 5) path = browsePath || "/library/sections/" + encodeURIComponent(section.key) + "/folder";
        if (!browsePath && view === 1 && searchText) path = Plex.pathWithQuery(path,{title:searchText});
        get(path, function(body) {
            var container = body.MediaContainer || {};
            items = view === 4 && !browsePath ? (container.Directory || []).map(function(g) { return {title:g.title, key:g.key, type:"category"}; }) : container.Metadata || (view === 5 ? container.Directory || [] : []);
            items = items.map(function(m) { var copy = JSON.parse(JSON.stringify(m)); if (!copy.librarySectionID) copy.librarySectionID = browsePath && detail.librarySectionID ? detail.librarySectionID : section.key; return copy; }).filter(function(m) { return Plex.allowedMedia(m,libraries); });
            if (view === 5) {
                items = items.filter(function(m) { return !!m.type || Plex.folderPath(m.key,section.key); }).map(function(m) { if (!m.type) m.type="folder"; return m; });
                total = items.length; items = items.slice(page*pageSize,(page+1)*pageSize);
                libraryLoaded(); return;
            }
            total = Number(container.totalSize !== undefined ? container.totalSize : container.size || items.length);
            console.log("DEVIALET_ITEMS_OK " + items.length); libraryLoaded();
        });
    }
    function selectView(index) {
        cancelBrowse();globalSearch=false;
        homeRequest.cancel();
        view = index; home = false; watchlist = false; searchText = ""; history = []; browsePath = ""; browseTitle = section.title; page = 0; hubs = []; items = []; total = 0; loadItems();
    }
    function showHome() {
        cancelBrowse();globalSearch=false;
        homeRequest.cancel(); home = true; watchlist = false; hubs = []; items = []; view = 0; history = []; browsePath = ""; browseTitle = "Accueil"; page = 0; searchText = ""; loadItems(); }
    function loadHubs() {
        if (home) { loadHome(); return; }
        get((home ? "/hubs" : "/hubs/sections/" + encodeURIComponent(section.key)) + "?count=20",function(body) {
            hubs = ((body.MediaContainer || {}).Hub || []).map(function(h) {
                return {title:h.title, key:h.key, items:(h.Metadata || []).filter(function(m) { return ["movie","show","season","episode"].indexOf(m.type) >= 0 && Plex.allowedMedia(m,libraries); })};
            }).filter(function(h) { return h.items.length > 0; });
            items = hubs.length ? hubs[0].items : []; total = items.length; libraryLoaded();
        });
    }
    function loadHome() {
        homeNotice = "";
        if(!pinnedLibraries.length){hubs=[];items=[];total=0;homeNotice="Épinglez vos bibliothèques depuis Mes bibliothèques pour personnaliser l’accueil.";libraryLoaded();return;}
        get("/hubs/continueWatching?count=50",function(body) {
            var container = body.MediaContainer || {};
            var rows = container.Metadata || ((container.Hub || [])[0] || {}).Metadata || [];
            rows = rows.filter(function(m) { return Plex.allowedMedia(m,pinnedLibraries); });
            hubs = [{title:"Continuer à regarder", key:"continue", items:rows}];
            items = rows; total = rows.length; libraryLoaded();
            loadHomeRecent(0);
        });
    }
    function loadHomeRecent(index) {
        if (!home || index >= pinnedLibraries.length) return;
        var library = pinnedLibraries[index];
        var path = "/hubs/sections/" + encodeURIComponent(library.key) + "?count=20";
        homeRequest.send("GET",serverUrl + path,headers(serverToken),function(body) {
            if (!home) return;
            var rows = []; var source = (body.MediaContainer || {}).Hub || [];
            for (var i=0;i<source.length;i++) if (/\.recentlyadded\./.test(source[i].hubIdentifier || "")) { rows = source[i].Metadata || []; break; }
            rows = rows.filter(function(m) { return ["movie","show","season","episode"].indexOf(m.type) >= 0; }).map(function(m) {
                var copy = JSON.parse(JSON.stringify(m)); if (!copy.librarySectionID) copy.librarySectionID = library.key; return copy;
            }).filter(function(m) { return Plex.allowedMedia(m,pinnedLibraries); });
            if (rows.length) hubs = hubs.concat([{title:"Nouveaux ajouts · " + library.title,key:String(library.key),items:rows}]);
            loadHomeRecent(index+1);
        },function() { if (!home) return; homeNotice = "Certains nouveaux ajouts sont momentanément indisponibles."; loadHomeRecent(index+1); });
    }
    function showWatchlist() {
        cancelBrowse();globalSearch=false;
        homeRequest.cancel();
        home = false; watchlist = true; view = 1; history = []; browsePath = ""; browseTitle = "Liste de suivis"; page = 0; searchText = ""; items = []; total = 0; watchlistReady = false; watchlistItems = []; loadItems();
    }
    function loadWatchlist() { loadWatchlistChunk(0,[]); }
    function loadWatchlistChunk(offset, collected) {
        var path = Plex.pathWithQuery("/library/sections/watchlist/all",{sort:"watchlistedAt:desc","X-Plex-Container-Start":offset,"X-Plex-Container-Size":40});
        network.send("GET","https://discover.provider.plex.tv" + path,headers(accountToken),function(body) {
            var container = body.MediaContainer || {}; var rows = container.Metadata || [];
            var guids = rows.map(function(m) { return m.guid; }).filter(function(g) { return /^plex:\/\/(movie|show)\/[a-zA-Z0-9]+$/.test(g || ""); });
            function complete(matches) {
                var result = collected.concat(Plex.resolveWatchlist(rows,matches,libraries));
                if (rows.length && offset+rows.length < Number(container.totalSize || 0)) { loadWatchlistChunk(offset+rows.length,result); return; }
                watchlistItems = result; watchlistReady = true; showWatchlistPage();
            }
            if (!guids.length) { complete([]); return; }
            get(Plex.pathWithQuery("/library/all",{guid:guids.join(","),includeGuids:1,"X-Plex-Container-Size":10000}),function(local) { complete((local.MediaContainer || {}).Metadata || []); });
        },failure);
    }
    function showWatchlistPage() { total = watchlistItems.length; items = watchlistItems.slice(page*pageSize,(page+1)*pageSize); libraryLoaded(); }
    function search(text) {
        cancelBrowse();network.cancel();globalSearch=true;view=1;home=false;watchlist=false;history=[];browsePath="";page=0;searchText=text.trim();browseTitle="Recherche";searchNotice="";searchResults=[];items=[];total=0;error="";state="library";lastAction="search";
        if(!searchText){libraryLoaded();return;}searchLibrary(0,0,searchGeneration);
    }
    function cancelBrowse() { searchGeneration++;homeRequest.cancel(); }
    function searchLibrary(index,offset,generation) {
        if(generation!==searchGeneration || !globalSearch)return;
        if(index>=libraries.length){showSearchPage();return;}
        var library=libraries[index];
        if(!saved.allowAdultSearch && adultLibraries.indexOf(String(library.key))>=0){searchLibrary(index+1,0,generation);return;}
        var path=Plex.pathWithQuery("/library/sections/"+encodeURIComponent(library.key)+"/all",{title:searchText,sort:"titleSort:asc","X-Plex-Container-Start":offset,"X-Plex-Container-Size":100});
        homeRequest.send("GET",serverUrl+path,headers(serverToken),function(body){
            if(generation!==searchGeneration || !globalSearch)return;
            var container=body.MediaContainer || {},rows=container.Metadata || [];
            var visible=rows.filter(function(m){return saved.allowAdultSearch || !Plex.adultSearchResult(m,library,adultLibraries);});
            searchResults=Plex.mergeSearch(searchResults,visible,library,libraries);total=searchResults.length;items=searchResults.slice(page*pageSize,(page+1)*pageSize);
            if(rows.length && offset+rows.length<Number(container.totalSize || 0))searchLibrary(index,offset+rows.length,generation);else searchLibrary(index+1,0,generation);
        },function(){if(generation!==searchGeneration || !globalSearch)return;searchNotice="Recherche partielle : une bibliothèque n’a pas répondu. Relancez la recherche pour réessayer.";searchLibrary(index+1,0,generation);});
    }
    function showSearchPage() { total=searchResults.length;items=searchResults.slice(page*pageSize,(page+1)*pageSize);libraryLoaded(); }
    function changeFilter(index) { filterIndex = index; page = 0; loadItems(); }
    function changeSort(index) { sortIndex = index; page = 0; loadItems(); }
    function changePage(delta) { var p = page + delta; if (p >= 0 && p * pageSize < total) { page = p; loadItems(); } }
    function loadGenres() {
        error = ""; lastAction = "genres";
        get("/library/sections/" + encodeURIComponent(section.key) + "/genre", function(body) {
            genres = [{key:"", title:"Tous les genres"}].concat((body.MediaContainer || {}).Directory || []); genresLoaded();
        });
    }
    function chooseGenre(index) { genreKey = String(genres[index].key); genreTitle = genres[index].title; page = 0; loadItems(); }
    function openItem(index) {
        if (busy || !items[index]) return;
        openMedia(items[index]);
    }
    function openMedia(item) {
        if (busy || !item) return;
        error = ""; lastAction = "detail"; detail = item;
        if (item.cloudOnly) { detailsLoaded(); return; }
        if (!Plex.allowedMedia(item,libraries)) { error = "Ce titre n’est pas disponible dans les bibliothèques de cette application."; return; }
        if (item.type === "category" || item.type === "collection" || item.type === "playlist" || item.type === "folder") { openChildren(); return; }
        get("/library/metadata/" + encodeURIComponent(item.ratingKey) + "?includeMarkers=1&includeExtras=1&includeChapters=1", function(body) {
            var next = ((body.MediaContainer || {}).Metadata || [item])[0];
            if (!next.librarySectionID) next.librarySectionID = item.librarySectionID;
            if (!Plex.allowedMedia(next,libraries)) { error = "Ce titre n’est pas disponible."; return; }
            detail = next; detailsLoaded();
        });
    }
    function openChildren() {
        if (detail.type === "folder" && !Plex.folderPath(detail.key,section.key)) { error="Ce dossier n’est pas accessible depuis cette bibliothèque."; return; }
        var stack = history.slice(); stack.push({path:browsePath, title:browseTitle, page:page, view:view, home:home, watchlist:watchlist,globalSearch:globalSearch}); history = stack;
        browsePath = detail.type === "folder" ? detail.key : detail.type === "playlist" ? "/playlists/" + encodeURIComponent(detail.ratingKey) + "/items" : detail.type === "category" ? Plex.pathWithQuery(section.browseKey || "/library/sections/" + encodeURIComponent(section.key) + "/all",{genre:String(detail.key),sort:"titleSort:asc"}) : "/library/metadata/" + encodeURIComponent(detail.ratingKey) + "/children";
        browseTitle = Plex.label(detail); page = 0; loadItems();
    }
    function back() {
        if (!history.length) return;
        var stack = history.slice(); var previous = stack.pop(); history = stack;
        browsePath = previous.path; browseTitle = previous.title; page = previous.page; view = previous.view === undefined ? 1 : previous.view; home = !!previous.home; watchlist = !!previous.watchlist;globalSearch=!!previous.globalSearch;loadItems();
    }
    function markWatched() {
        if (busy || !detail.ratingKey || detail.cloudOnly || !Plex.allowedMedia(detail,libraries)) return;
        error = "";
        get(Plex.pathWithQuery(detail.viewCount ? "/:/unscrobble" : "/:/scrobble", {key:detail.ratingKey,identifier:"com.plexapp.plugins.library"}),function() {
            var next = JSON.parse(JSON.stringify(detail)); next.viewCount = next.viewCount ? 0 : 1; next.viewOffset = 0;
            replaceMedia(next);
        });
    }
    function imageUrl(path, width, height) {
        if (Plex.publicImage(path)) return path.replace("/t/p/original/", "/t/p/" + (width > 600 ? "w1280" : "w342") + "/");
        if (!Plex.safePath(path)) return "";
        return Plex.mediaUrl(serverUrl, Plex.pathWithQuery("/photo/:/transcode", {url:path, width:width, height:height, minSize:1, upscale:1}), serverToken);
    }
    function play(resume) {
        pendingFeature=null;
        if (detail.cloudOnly || !Plex.allowedMedia(detail,libraries)) { error = "Ce titre n’est pas disponible sur ce serveur."; return; }
        var media = (detail.Media || [])[0]; var part = media && (media.Part || [])[0];
        if (!part || !Plex.safePath(part.key)) { error = "Aucun fichier lisible disponible pour ce titre."; return; }
        var offset = resume ? Math.max(0,Number(detail.viewOffset || 0) - saved.rewindSeconds * 1000) : 0;
        var trailers=Plex.trailers(detail);
        if(saved.cinemaTrailers && detail.type==="movie" && !offset && trailers.length){pendingFeature={media:detail,url:Plex.mediaUrl(serverUrl,part.key,serverToken)};playExtraMedia(trailers[0]);return;}
        playbackRequested(Plex.mediaUrl(serverUrl, part.key, serverToken), detail, offset);
    }
    function themeUrl(item) {
        if (!saved.themeMusic || !item || item.cloudOnly || !Plex.allowedMedia(item,libraries)) return "";
        var path = item.theme || item.parentTheme || item.grandparentTheme || "";
        return /^\/library\/metadata\/[^/]+\/theme\//.test(path) ? Plex.mediaUrl(serverUrl,path,serverToken) : "";
    }
    function playTrailer(index) {
        if (busy || detail.cloudOnly || !Plex.allowedMedia(detail,libraries)) return;
        pendingFeature=null;
        var extra = Plex.trailers(detail)[index]; if (!extra) return;
        playExtraMedia(extra);
    }
    function playExtra(index) { if(busy || detail.cloudOnly || !Plex.allowedMedia(detail,libraries))return;pendingFeature=null;var extra=Plex.extras(detail)[index];if(extra)playExtraMedia(extra); }
    function playExtraMedia(extra) {
        var part = Plex.trailerPart(extra); if (!part) return;
        var media = JSON.parse(JSON.stringify(extra));
        media.isExtra = true; media.Marker = []; media.librarySectionID = detail.librarySectionID;
        playbackRequested(Plex.mediaUrl(serverUrl,part.key,serverToken),media,0);
    }
    function timeline(item, position, duration, state) {
        if (!serverUrl || !item.ratingKey || item.isExtra || !Plex.allowedMedia(item,libraries)) return;
        var path = Plex.pathWithQuery("/:/timeline", {ratingKey:item.ratingKey, key:"/library/metadata/" + item.ratingKey,
            state:state, time:Math.max(0, Math.floor(position)), duration:Math.floor(duration || item.duration || 0)});
        var queue=progressQueue.slice();
        if(queue.length && queue[queue.length-1].item.ratingKey===item.ratingKey && queue[queue.length-1].state!=="stopped")queue.pop();
        queue.push({url:serverUrl+path,headers:headers(serverToken),item:item,position:position,duration:duration,state:state,attempts:0});progressQueue=queue;
        if(state==="stopped")updateProgress(item,position);
        flushProgress();
    }
    function flushProgress() {
        if(progressRequest.busy || !progressQueue.length || progressRetry.running)return;
        var queue=progressQueue.slice(),entry=queue.shift();progressQueue=queue;
        progressRequest.send("GET",entry.url,entry.headers,function(){if(entry.state==="stopped")refreshAfterPlayback(entry.item);flushProgress();},function(){
            if(entry.state==="stopped" && entry.attempts<2){entry.attempts++;progressQueue=[entry].concat(progressQueue);progressRetry.restart();}
            else {if(entry.state==="stopped")notice="Progression non enregistrée : le serveur n’a pas répondu.";flushProgress();}
        },5000);
    }
    function updateProgress(item,position) {
        function updated(m){if(String(m.ratingKey)!==String(item.ratingKey))return m;var copy=JSON.parse(JSON.stringify(m));copy.viewOffset=Math.max(0,position);return copy;}
        items=items.map(updated);watchlistItems=watchlistItems.map(updated);searchResults=searchResults.map(updated);detail=updated(detail);previewDetail=({});
        hubs=hubs.map(function(h){return {title:h.title,key:h.key,items:h.items.map(updated)};});
    }
    function replaceMedia(current) {
        function updated(item) {
            if (String(item.ratingKey) !== String(current.ratingKey)) return item;
            // Preserve view-specific fields (Watchlist GUID, library caption).
            var copy = JSON.parse(JSON.stringify(item));
            for (var key in current) copy[key] = current[key];
            return copy;
        }
        items = items.map(updated);
        watchlistItems = watchlistItems.map(updated);
        searchResults = searchResults.map(updated);
        detail = updated(detail);
        previewDetail = ({});
        hubs = hubs.map(function(h) { return {title:h.title,key:h.key,items:h.items.map(updated)}; });
    }
    function refreshAfterPlayback(item) {
        if(!Plex.allowedMedia(item,libraries))return;
        refreshRequest.send("GET",serverUrl+"/library/metadata/"+encodeURIComponent(item.ratingKey)+"?includeMarkers=1&includeExtras=1&includeChapters=1",headers(serverToken),function(body){
            var current=((body.MediaContainer || {}).Metadata || [])[0];
            if(current){if(!current.librarySectionID)current.librarySectionID=item.librarySectionID;if(Plex.allowedMedia(current,libraries))replaceMedia(current);}
            if(!home)return;
            refreshRequest.send("GET",serverUrl+"/hubs/continueWatching?count=50",headers(serverToken),function(body){if(!home)return;var c=body.MediaContainer || {},rows=c.Metadata || ((c.Hub || [])[0] || {}).Metadata || [];var next=hubs.slice();next[0]={title:"Continuer à regarder",key:"continue",items:rows.filter(function(m){return Plex.allowedMedia(m,pinnedLibraries);})};hubs=next;items=next[0].items;},function(){});
        },function(){});
    }
    function finishPlayback(completed) {
        var next=pendingFeature;pendingFeature=null;
        if(completed && next && Plex.allowedMedia(next.media,libraries)){playbackRequested(next.url,next.media,0);return true;}return false;
    }
    function cancelNextEpisode() { nextRequest.cancel(); }
    function prepareNextEpisode(item) {
        cancelNextEpisode();
        if(!saved.autoNextEpisode || item.isExtra || item.type!=="episode" || !item.grandparentRatingKey || !Plex.allowedMedia(item,libraries)){nextEpisodeReady({});return;}
        fetchNextEpisode(item,0,false);
    }
    function fetchNextEpisode(item,offset,found) {
        var path=Plex.pathWithQuery("/library/metadata/"+encodeURIComponent(item.grandparentRatingKey)+"/allLeaves",{"X-Plex-Container-Start":offset,"X-Plex-Container-Size":100});
        nextRequest.send("GET",serverUrl+path,headers(serverToken),function(body){
            var c=body.MediaContainer || {},rows=c.Metadata || [],next=null;
            for(var i=0;i<rows.length;i++){
                if(found && rows[i].type==="episode"){next=rows[i];break;}
                if(String(rows[i].ratingKey)===String(item.ratingKey))found=true;
            }
            if(next){
                nextRequest.send("GET",serverUrl+"/library/metadata/"+encodeURIComponent(next.ratingKey)+"?includeMarkers=1&includeExtras=1&includeChapters=1",headers(serverToken),function(body){
                    var episode=((body.MediaContainer || {}).Metadata || [])[0];
                    if(episode && !episode.librarySectionID)episode.librarySectionID=item.librarySectionID;
                    nextEpisodeReady(episode && Plex.allowedMedia(episode,libraries) ? episode : {});
                },function(){notice="L’épisode suivant est indisponible.";nextEpisodeReady({});});return;
            }
            if(rows.length && offset+rows.length<Number(c.totalSize || 0))fetchNextEpisode(item,offset+rows.length,found);else nextEpisodeReady({});
        },function(){notice="Impossible de charger l’épisode suivant.";nextEpisodeReady({});});
    }
    function startNextEpisode(item) {
        if(!Plex.allowedMedia(item,libraries))return;
        var part=(((item.Media || [])[0] || {}).Part || [])[0];
        if(!part || !Plex.safePath(part.key)){notice="Aucun fichier disponible pour l’épisode suivant.";return;}
        detail=item;pendingFeature=null;playbackRequested(Plex.mediaUrl(serverUrl,part.key,serverToken),item,0);
    }
    function openActor(index) {
        var actor=(detail.Role || [])[index];if(!actor || !actor.id || !Plex.allowedMedia(detail,libraries))return;
        var library=libraries.filter(function(l){return String(l.key)===String(detail.librarySectionID);})[0];if(!library)return;
        var stack=history.slice();stack.push({path:browsePath,title:browseTitle,page:page,view:view,home:home,watchlist:watchlist,globalSearch:globalSearch});history=stack;
        browsePath=Plex.pathWithQuery("/library/sections/"+encodeURIComponent(library.key)+"/all",{actor:actor.id,sort:"titleSort:asc"});browseTitle="Avec "+(actor.tag || "cet interprète");page=0;loadItems();
    }
    function loadProfiles() {
        if (state !== "profiles") profileReturnState = state === "library" ? "library" : "starting";
        cancelBrowse();network.cancel();previewRequest.cancel();
        state="profiles";profileError="";profilesLoading=true;profileSelecting=false;profiles=[];
        var h=headers(ownerToken || saved.authToken);h.Accept="application/xml";
        profileRequest.send("GET","https://plex.tv/api/home/users",h,function(body){profilesLoading=false;profiles=body.User || [];if(!profiles.length)profileError="Aucun profil disponible pour ce compte.";},function(){profilesLoading=false;profileError="Les profils Plex sont indisponibles. Réessayez.";},12000,"xml");
    }
    function chooseProfile(index,pin) {
        var profile=profiles[index];if(!profile || profilesLoading || !/^\d+$/.test(String(profile.id)))return;
        profileError="";profilesLoading=true;profileSelecting=true;
        var path="https://plex.tv/api/home/users/"+encodeURIComponent(profile.id)+"/switch",h=headers(ownerToken || saved.authToken);h.Accept="application/xml";
        if(pin)path=Plex.pathWithQuery(path,{pin:pin});
        profileRequest.send("POST",path,h,function(body){
            profilesLoading=false;profileSelecting=false;
            var token=body.authenticationToken || body.authToken;if(!token){profileError="Plex n’a pas confirmé ce profil.";return;}
            resetUserData();saved.profileToken=saved.rememberAccount ? token : "";accountToken=token;profileName=profile.title || profile.username || "";profileId=String(profile.id);discover();
        },function(status){profilesLoading=false;profileSelecting=false;profileError=status===401 || status===403 ? "Code PIN incorrect ou accès refusé." : "Changement de profil impossible. Réessayez.";},12000,"xml");
    }
    function cancelProfiles() {
        profileRequest.cancel();
        profilesLoading = false;
        profileSelecting = false;
        profileError = "";
        if (serverUrl && profileReturnState === "library") {
            state = "library";
            if (home) loadItems();
        } else {
            state = "auth";
            message = "Connectez votre compte ou choisissez un profil.";
        }
    }
    function resetUserData() {
        resetServerData();
        servers = [];
    }
    function resetServerData() {
        cancelBrowse();network.cancel();previewRequest.cancel();refreshRequest.cancel();nextRequest.cancel();progressRequest.cancel();progressRetry.stop();progressQueue=[];pendingFeature=null;
        serverUrl="";serverToken="";serverName="";connectionLabel="";activeServer=({});candidates=[];candidateIndex=0;
        section=({});genres=[];libraries=[];items=[];hubs=[];history=[];
        watchlistItems=[];watchlistReady=false;watchlist=false;home=false;globalSearch=false;
        searchResults=[];searchText="";detail=({});previewDetail=({});
        page=0;total=0;browsePath="";browseTitle="";filterIndex=0;sortIndex=0;genreKey="";genreTitle="Tous les genres";
        notice="";searchNotice="";homeNotice="";firstLibrarySetup=false;
    }
    function retry() {
        error = "";
        if (lastAction === "connect") { if (accountToken) restore(); else connectAccount(); }
        else if (lastAction === "server") { candidateIndex = 0; tryConnection(); }
        else if (lastAction === "libraries") loadLibraries();
        else if (lastAction === "genres") loadGenres();
        else if (lastAction === "detail") openMedia(detail);
        else if (lastAction === "search") search(searchText);
        else loadItems();
    }
    function logout() {
        resetUserData();profileRequest.cancel();profiles=[];profileName="";profileId="";saved.profileToken="";ownerToken="";
        previewRequest.cancel(); previewDetail = ({}); notice = "";
        homeRequest.cancel();
        poll.stop(); network.cancel(); progressRequest.cancel(); saved.authToken = ""; saved.serverId = "";
        accountToken = ""; serverToken = ""; serverUrl = ""; servers = []; libraries = []; items = []; hubs = []; history = []; watchlistItems = []; watchlistReady = false; watchlist = false; detail = ({}); searchText = "";
        state = "auth"; code = ""; error = ""; message = "Connectez votre compte Plex.";
    }
}
