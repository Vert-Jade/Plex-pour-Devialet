import QtQuick 2.4
import "../../app"
import "../../app/Plex.js" as Plex

Item {
    width: 1280; height: 720
    Rectangle { anchors.fill: parent; color: "#000000" }
    Image { anchors.fill: parent; source: "../../app/assets/login-lounge.png"; fillMode: Image.PreserveAspectCrop; visible: fixture.state === "auth" || fixture.state === "starting" }
    Rectangle { anchors.fill: parent; color: "#33000000"; visible: fixture.state === "auth" || fixture.state === "starting" }
    QtObject {
        id: fixture
        property string welcomeName: ""
        property string profileName: "Profil de démonstration"
        property string profileId: "1"
        property var profiles: [{id:"1",title:"Famille",protected:"0"},{id:"2",title:"Enfants",protected:"1"}]
        property bool profilesLoading: false
        property bool profileSelecting: false
        property string profileError: ""
        property string audioLanguage: ""
        property string subtitleLanguage: ""
        property int subtitlePolicy: 0
        property bool cinemaTrailers: false
        property bool rememberProfile: true
        property bool autoNextEpisode: true
        property bool rememberAccount: true
        property bool allowAdultSearch: false
        property bool firstLibrarySetup: false
        property var libraryPrefs: ({pinned:["1","2","3"],adult:[]})
        readonly property var pinnedLibraries: libraries.filter(function(l){return libraryPrefs.pinned.indexOf(String(l.key))>=0;})
        function libraryFlag(key,flag){return libraryPrefs[flag].indexOf(String(key))>=0;}
        function toggleLibrary(index,flag){var prefs=JSON.parse(JSON.stringify(libraryPrefs)),key=String(libraries[index].key),p=prefs[flag].indexOf(key);if(p>=0)prefs[flag].splice(p,1);else prefs[flag].push(key);libraryPrefs=prefs;}
        function openLibraries(){state="libraries";}
        function closeLibraries(){showHome();state="library";}
        function setRememberAccount(enabled){rememberAccount=enabled;}
        property bool globalSearch: false
        property string searchNotice: ""
        function loadProfiles(){state="profiles";}
        function cancelProfiles(){state="library";}
        function chooseProfile(index,pin){if(index===1 && pin!=="1234"){profileError="Code PIN incorrect ou accès refusé.";return;}profileId=profiles[index].id;profileName=profiles[index].title;profileError="";state="library";}
        function playExtra(index){trailerCount++;}
        function openActor(index){browseTitle="Avec "+detail.Role[index].tag;items=allItems;libraryLoaded();}
        property string state: "library"
        property string serverName: "Maison"
        property string connectionLabel: "Réseau local"
        property string message: "Ouvrez plex.tv/link sur votre téléphone et saisissez ce code."
        property string code: "ABCD"
        property string error: ""
        property bool busy: false
        property bool autoSkipIntro: true
        property bool autoSkipCredits: true
        property int rewindSeconds: 0
        property int uiScale: 95
        property bool themeMusic: true
        property int themeVolume: 25
        property int trailerCount: 0
        function themeUrl(item) { return themeMusic ? item.theme || "" : ""; }
        function playTrailer(index) { trailerCount++; }
        function changePreference(index,direction) {
            if (index === 0) autoSkipIntro = !autoSkipIntro;
            else if (index === 1) autoSkipCredits = !autoSkipCredits;
            else if (index === 2) { var values=[0,5,10,15,30]; rewindSeconds=values[(values.indexOf(rewindSeconds)+(direction<0?-1:1)+5)%5]; }
            else if (index === 3) uiScale = Math.max(90,Math.min(100,uiScale+(direction<0?-1:1)));
            else if (index === 4) themeMusic = !themeMusic;
            else if (index === 5) themeVolume = Math.max(5,Math.min(100,themeVolume+(direction<0?-5:5)));
            else if(index===6) audioLanguage=audioLanguage ? "" : "fra";
            else if(index===7) subtitleLanguage=subtitleLanguage ? "" : "fra";
            else if(index===8) subtitlePolicy=(subtitlePolicy+(direction<0 ? 3 : 1))%4;
            else if(index===9) cinemaTrailers=!cinemaTrailers;
            else if(index===10) rememberProfile=!rememberProfile;
            else if(index===11) autoNextEpisode=!autoNextEpisode;
            else if(index===12) rememberAccount=!rememberAccount;
            else if(index===13) allowAdultSearch=!allowAdultSearch;
        }
        readonly property var libraries: Plex.visibleLibraries(rawLibraries)
        property var section: libraries[0]
        property var items: []
        property var allItems: []
        property var hubs: []
        property int view: 1
        property bool home: false
        property bool watchlist: false
        property bool homeLoading: false
        property string homeNotice: ""
        property string notice: ""
        signal previewLoaded(var media)
        function previewMedia(item) { }
        function toggleWatchlist(item) { notice = "Ajouté à Ma liste"; }
        property var rawLibraries: [{key:"1",title:"Films",type:"movie"},{key:"2",title:"Séries",type:"show"},{key:"3",title:"Documentaires",type:"movie"}]
        property string searchText: ""
        property string serverUrl: "http://fixture.invalid"
        property bool deferGenres: false
        property int playCount: 0
        property var detail: ({})
        property var servers: [{name:"Maison"},{name:"Bibliothèque familiale"}]
        property var genres: [{key:"",title:"Tous les genres"},{key:"1",title:"Aventure"},{key:"2",title:"Animation"},{key:"3",title:"Comédie"},{key:"4",title:"Documentaire"}]
        property var history: []
        property int filterIndex: 0
        property int sortIndex: 0
        property string genreTitle: "Tous les genres"
        property string browsePath: ""
        property string browseTitle: "Films"
        property int page: 0
        property int pageSize: 40
        property int total: 186
        signal libraryLoaded()
        signal detailsLoaded()
        signal genresLoaded()
        signal playbackRequested(string url, var media, int offset)
        function imageUrl(path,w,h) { return path; }
        function selectLibrary(index) { globalSearch=false;section = libraries[index]; browseTitle = section.title; home = false; watchlist = false; view = 1; browsePath = ""; history = []; items = allItems; libraryLoaded(); }
        function selectView(index) { globalSearch=false;view = index; home = false; watchlist = false; browsePath = ""; history = []; items = index === 2 || index === 3 ? [] : index === 4 ? [{title:"Comédie",key:"3",type:"category"}] : allItems; libraryLoaded(); }
        function showHome() { globalSearch=false;home = true; watchlist = false; view = 0; browseTitle = "Accueil"; items = allItems; libraryLoaded(); }
        function showWatchlist() { globalSearch=false;home = false; watchlist = true; view = 1; browseTitle = "Liste de suivis"; items = allItems; libraryLoaded(); }
        function search(text) { globalSearch=true;searchText = text; home = false; watchlist = false; view = 1; items = allItems; libraryLoaded(); }
        function changeFilter(index) { filterIndex = index; page = 0; libraryLoaded(); }
        function changeSort(index) { sortIndex = index; page = 0; libraryLoaded(); }
        function loadGenres() { if (!deferGenres) genresLoaded(); }
        function chooseGenre(index) { genreTitle = genres[index].title; page = 0; libraryLoaded(); }
        function openItem(index) { openMedia(items[index]); }
        function openMedia(item) { detail = item; if (["category","collection","playlist"].indexOf(item.type) >= 0) openChildren(); else detailsLoaded(); }
        function changePage(delta) { page += delta; libraryLoaded(); }
        function openChildren() { history = history.concat([{path:browsePath,title:browseTitle,page:page,items:items,view:view,home:home}]); browsePath = "/children"; browseTitle = detail.title; items = allItems; page = 0; libraryLoaded(); }
        function play(resume) { playCount++; }
        function markWatched() { var d=JSON.parse(JSON.stringify(detail)); d.viewCount = d.viewCount ? 0 : 1; detail = d; }
        function back() { var stack=history.slice(); var p=stack.pop();history=stack;browsePath=p.path;browseTitle=p.title;page=p.page;items=p.items;view=p.view;home=p.home;libraryLoaded(); }
        function showServers() { state = "servers"; }
        function chooseServer(index) { state = "library"; }
        function logout() { state = "auth"; }
        function connectAccount() { }
        function retry() { error = ""; }
    }
    Item {
        objectName: "safeCanvas"; width: 1280; height: 720; anchors.centerIn: parent
        scale: Math.min(parent.width / width, parent.height / height) * Math.max(90,Math.min(100,fixture.uiScale)) / 100
        Shell { id: shell; objectName: "shell"; api: fixture; anchors.fill: parent }
    }
    property alias service: fixture
}
