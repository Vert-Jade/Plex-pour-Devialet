import QtQuick 2.4
import "Plex.js" as Plex
import "AppInfo.js" as AppInfo

FocusScope {
    id: shell
    width: 1280; height: 720; focus: true; clip: true
    FontLoader { id: typeface; source: "fonts/NotoSans-Regular.ttf" }
    FontLoader { source: "fonts/NotoSans-SemiBold.ttf" }
    property var api
    // Remote zones: 0 sidebar, 1 filters, 2 media, 3 pages, 4 tabs.
    property int zone: 2
    property int returnZone: 2
    property int navIndex: 3
    property int filterButton: 0
    property int itemIndex: 0
    property int preferredColumn: 0
    property int pageButton: 1
    property int serverIndex: 0
    property int authChoice: 0
    property bool detailOpen: false
    property int detailButton: 0
    property int detailZone: 0
    property int detailSecondary: 0
    property string sheet: ""
    property int sheetIndex: 0
    property bool confirmLogout: false
    property url settingsImage: ""
    property int settingsCapture: 0
    property int errorChoice: 0
    property var focusHistory: []
    property int restoreIndex: -1
    property int restoreHub: 0
    property var restoreDetail: null
    property int hubIndex: 0
    property int heroButton: 0
    property bool homePlayPending: false
    property int tabIndex: 0
    property string searchDraft: ""
    property int keyboardIndex: 0
    property string timeText: Qt.formatTime(new Date(), "hh:mm")
    readonly property var tabs: ["Bibliothèque"]
    readonly property var keyboardKeys: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".split("").concat(["Espace","Effacer","Vider","Rechercher"])
    readonly property bool recommended: api.view === 0 && !api.browsePath
    readonly property var displayedItems: recommended ? (api.hubs[hubIndex] ? api.hubs[hubIndex].items : []) : api.items
    readonly property var navigation: [{title:"Ma liste",icon:"bookmark"},{title:"Accueil",icon:"home"},{title:"Rechercher",icon:"search"}].concat(api.pinnedLibraries.map(function(l){return {title:l.title,icon:l.type === "show" ? "series" : "film"};})).concat([{title:"Mes bibliothèques",icon:"folder"},{title:"Compte",icon:"user"},{title:"Paramètres",icon:"settings"}])
    property string dropdown: ""
    property int dropdownIndex: 0
    property bool genrePending: false
    property var hero: ({})
    readonly property int columns: 6
    readonly property var current: displayedItems.length > itemIndex ? displayedItems[itemIndex] : ({})
    readonly property var availableTrailers: Plex.trailers(api.detail)
    readonly property var accountActions: [{title:"Changer de profil",kind:"profiles"}].concat(api.servers.length>1 ? [{title:"Changer de serveur",kind:"servers"}] : []).concat([{title:"À propos et confidentialité",kind:"about"},{title:confirmLogout ? "Confirmer la déconnexion" : "Déconnecter ce Devialet",kind:"logout"},{title:"Fermer",kind:"close"}])
    readonly property var sheetOptions: availableTrailers
    readonly property string themeSource: visible && isLibrary && !sheet && !api.error && !api.busy ? api.themeUrl(detailOpen ? api.detail : zone === 2 || zone === 5 ? hero : ({})) : ""
    readonly property bool isLibrary: api.state === "library"
    readonly property bool navOpen: isLibrary && zone === 0 && !detailOpen && !sheet && !api.error
    readonly property real sidebarWidth: sidebar.width
    readonly property bool contentFocused: isLibrary && !detailOpen && !sheet && !dropdown && !api.error
    readonly property bool detailFocused: isLibrary && detailOpen && !sheet && !dropdown && !api.error
    readonly property var pageActions: (api.page>0 ? [2,0] : []).concat((api.page+1)*api.pageSize<api.total ? [1] : [])
    readonly property var filterOptions: [{title:"Tous"},{title:"Non vus"},{title:"En cours"},{title:"Vus"}]
    readonly property var sortOptions: Plex.librarySorts()
    readonly property var viewOptions: [{title:"Bibliothèque",value:1},{title:"Collections",value:2},{title:"Listes de lecture",value:3},{title:"Dossiers",value:5}]
    readonly property int viewOption: Math.max(0,viewOptions.map(function(v){return v.value;}).indexOf(api.view))
    readonly property string countLabel: api.total + (api.view===5 ? " élément" : " titre") + (api.total>1 ? "s" : "")
    readonly property var dropdownOptions: dropdown === "view" ? viewOptions : dropdown === "status" ? filterOptions : dropdown === "sort" ? sortOptions : genrePending ? [] : api.genres
    readonly property int dropdownSelected: dropdown === "view" ? viewOption : dropdown === "status" ? api.filterIndex : dropdown === "sort" ? api.sortIndex : selectedGenre()
    signal startPlayback(string url, var media, int offset)
    signal themeRequested(string url)
    onThemeSourceChanged: { themeRequested(""); themeDelay.restart(); }
    Timer { id: themeDelay; interval: 700; onTriggered: shell.themeRequested(shell.themeSource) }

    function takeFocus() { forceActiveFocus(); }
    Timer {id:stateFocus;interval:1;onTriggered:{if(api.state==="profiles")profilePanel.forceActiveFocus();else if(api.state==="libraries")libraryPanel.forceActiveFocus();else shell.takeFocus();}}
    onNavIndexChanged: if (navIndex <= 1) navReset.restart()
    Timer { id: navReset; interval: 10; onTriggered: if (shell.navIndex <= 1) nav.positionViewAtBeginning() }
    function selectedGenre() { for (var i=0; i<api.genres.length; i++) if (api.genres[i].title === api.genreTitle) return i; return 0; }
    function openNav() { if (zone !== 0) returnZone = zone; closeDropdown(); zone = 0; }
    function closeNav() {
        zone = returnZone;
        if (zone === 2 && !displayedItems.length && !(recommended && api.hubs.length)) zone = api.home || api.watchlist || api.globalSearch || api.view !== 1 || api.browsePath ? 4 : 1;
    }
    function closeDropdown() { dropdown = ""; genrePending = false; }
    function openFilter(index) {
        if (api.browsePath) { goParent(); return; }
        filterButton = index; zone = 1;
        dropdown = ["status", "genre", "sort"][index]; genrePending = false;
        if (dropdown === "genre") {
            dropdownIndex = selectedGenre();
            if (!api.genres.length) { genrePending = true; api.loadGenres(); }
        } else dropdownIndex = dropdownSelected;
    }
    function applyFilter(index) {
        if (genrePending || index < 0 || index >= dropdownOptions.length) return;
        var kind = dropdown; var selected = dropdownSelected;
        closeDropdown();
        if (index === selected) return;
        if(kind==="view"){zone=4;focusHistory=[];api.selectView(viewOptions[index].value);}
        else if (kind === "status") api.changeFilter(index);
        else if (kind === "sort") api.changeSort(index);
        else api.chooseGenre(index);
    }
    function goParent() {
        if (!api.history.length) return;
        var stack = focusHistory.slice(); var previous = stack.length ? stack.pop() : {item:0,hub:0}; restoreIndex = previous.item; restoreHub = previous.hub; restoreDetail = previous.detail ? previous : null; focusHistory = stack;
        zone = 2; api.back();
    }
    function back() {
        settingsCapture++;
        if (api.error) {
            if (isLibrary) { api.error = ""; takeFocus(); }
            else if (api.servers.length) { api.error = ""; api.showServers(); }
            else {api.error="";api.state="auth";}
            return;
        }
        if (!sheet && !dropdown && api.cancelDetails()) { homePlayPending=false;takeFocus();return; }
        if (dropdown) closeDropdown();
        else if (sheet) { sheet = ""; confirmLogout = false; }
        else if (detailOpen) { detailOpen = false; detailZone = 0; }
        else if (api.state === "servers" && api.serverUrl) api.state = "library";
        else if (navOpen) closeNav();
        else if (isLibrary && api.history.length) goParent();
        else if (isLibrary) openNav();
        takeFocus();
    }
    function selectTab(index) {
        tabIndex = index; zone = 4;dropdown="view";dropdownIndex=viewOption;
    }
    function selectNav() {
        restoreIndex=-1;restoreDetail=null;
        if (navIndex === navigation.length - 1) openSettings();
        else if (navIndex === 2) { sheet = "search"; searchDraft = api.searchText; keyboardIndex = 0; }
        else if (navIndex === 0) { zone = 2; itemIndex = 0; hubIndex = 0; focusHistory = []; api.showWatchlist(); }
        else if (navIndex === 1) { zone = 2; itemIndex = 0; hubIndex = 0; focusHistory = []; api.showHome(); }
        else if (navIndex === navigation.length - 2) { sheet = "account"; sheetIndex = 0; confirmLogout = false; }
        else if(navIndex===navigation.length-3) api.openLibraries();
        else {
            var library=api.pinnedLibraries[navIndex-3];if(!library)return;
            var index=api.libraries.map(function(l){return String(l.key);}).indexOf(String(library.key));
            if (!api.home && !api.watchlist && !api.globalSearch && library.key === api.section.key && !api.browsePath) { closeNav(); return; }
            detailOpen = false; zone = 2; itemIndex = 0; hubIndex = 0; preferredColumn = 0; focusHistory = []; api.selectLibrary(index);
        }
    }
    function rememberFocus(preserveDetail) {
        var stack=focusHistory.slice(),entry={item:itemIndex,hub:hubIndex};
        if(preserveDetail){entry.detail=api.detail;entry.detailButton=detailButton;entry.detailZone=detailZone;entry.detailSecondary=detailSecondary;}
        stack.push(entry);focusHistory=stack;
    }
    function openCurrent() {
        if (!current || !current.type) return;
        if (["collection","playlist","category","folder"].indexOf(current.type) >= 0) rememberFocus();
        api.openMedia(current);
    }
    function homeAction(index) {
        if (!current || !current.type || api.busy) return;
        heroButton = index; zone = 5;
        if (index === 1) { api.toggleWatchlist(hero); return; }
        homePlayPending = index === 0;
        api.openMedia(current);
        takeFocus();
    }
    function openSettings() {
        if (sheet === "settings") return;
        closeDropdown();
        var generation = ++settingsCapture;
        var captured = shell.grabToImage(function(result) {
            if (generation !== shell.settingsCapture || !shell.isLibrary || !shell.visible) return;
            shell.settingsImage = result.url; shell.sheetIndex = 0; shell.sheet = "settings";
        });
        if (!captured) { settingsImage = ""; sheetIndex = 0; sheet = "settings"; }
    }
    onSheetChanged: if (sheet !== "settings") settingsImage = ""
    function searchKey() {
        if (keyboardIndex < 36) searchDraft += keyboardKeys[keyboardIndex];
        else if (keyboardIndex === 36) searchDraft += " ";
        else if (keyboardIndex === 37) searchDraft = searchDraft.slice(0,-1);
        else if (keyboardIndex === 38) searchDraft = "";
        else if (searchDraft.trim()) { sheet = ""; zone = 2; hubIndex = 0; focusHistory = []; api.search(searchDraft); }
    }
    function detailAction() { detailView.activate(); }
    function sheetAction() {
        if (sheet === "info" || sheet==="about") { sheet = ""; return; }
        if (sheet === "search") { searchKey(); return; }
        if (sheet === "settings") { if (sheetIndex === Plex.settingsRows(api).length) sheet = "";else if(sheetIndex===14){sheet="";api.openLibraries();} else api.changePreference(sheetIndex,1); return; }
        if (sheet === "trailers") { sheet = ""; api.playTrailer(sheetIndex); return; }
        var choice=accountActions[sheetIndex];if(!choice)return;
        if(choice.kind==="profiles"){sheet="";detailOpen=false;api.loadProfiles();return;}
        if(choice.kind==="servers"){sheet="";detailOpen=false;api.showServers();return;}
        if(choice.kind==="about"){sheet="about";return;}
        if (choice.kind === "logout") {
            if (!confirmLogout) confirmLogout = true;
            else { sheet = ""; detailOpen = false; confirmLogout = false; api.logout(); }
        } else { sheet = ""; confirmLogout = false; }
    }
    function changePage(delta) {
        if (api.busy) return;
        if (api.page + delta < 0 || (api.page + delta) * api.pageSize >= api.total) return;
        zone = 2; api.changePage(delta);
    }
    function activate() {
        if (api.error) { if (errorChoice === 0) api.retry(); else back(); return; }
        if (dropdown) { applyFilter(dropdownIndex); return; }
        if (sheet) { sheetAction(); return; }
        if (api.busy && !(isLibrary && zone===0 && !detailOpen)) return;
        if (api.state === "auth") {if(authChoice===1)api.setRememberAccount(!api.rememberAccount);else api.connectAccount();}
        else if (api.state === "servers") api.chooseServer(serverIndex);
        else if (detailOpen) detailAction();
        else if (isLibrary) {
            if (zone === 0) selectNav();
            else if (zone === 1) openFilter(filterButton);
            else if (zone === 2) openCurrent();
            else if (zone === 5) homeAction(heroButton);
            else if (zone === 4) { if (api.browsePath) goParent(); else if (api.home) api.openLibraries(); else if (api.watchlist || api.globalSearch) openNav(); else selectTab(tabIndex); }
            else changePage(pageButton === 2 ? -api.page : pageButton === 0 ? -1 : 1);
        }
    }
    function move(dx, dy) {
        if (api.error) { errorChoice = Math.max(0, Math.min(1, errorChoice + dx + dy)); return; }
        if(api.state==="auth"){authChoice=Math.max(0,Math.min(1,authChoice+dy));return;}
        if (dropdown) {
            if (dx && dropdown!=="view") { var next = filterButton + dx; if (next >= 0 && next < 3) openFilter(next); }
            if (dy && !genrePending) dropdownIndex = Math.max(0, Math.min(dropdownOptions.length - 1, dropdownIndex + dy));
            return;
        }
        if (sheet === "info" || sheet==="about") return;
        if (sheet === "search") { if (dx) keyboardIndex = Math.max(0,Math.min(39,keyboardIndex+dx)); if (dy) keyboardIndex = Math.max(0,Math.min(39,keyboardIndex+dy*10)); return; }
        if (sheet === "settings") { var count=Plex.settingsRows(api).length;sheetIndex = Math.max(0,Math.min(count,sheetIndex + dy)); if (dx && sheetIndex < count) api.changePreference(sheetIndex,dx); return; }
        if (sheet === "trailers") { sheetIndex = Math.max(0,Math.min(sheetOptions.length-1,sheetIndex + dy)); return; }
        if (sheet) { sheetIndex = Math.max(0, Math.min(accountActions.length-1, sheetIndex + dy)); confirmLogout = false; return; }
        if (api.state === "servers") { serverIndex = Math.max(0, Math.min(api.servers.length - 1, serverIndex + dy)); return; }
        if (detailOpen) { detailView.move(dx,dy); return; }
        if (!isLibrary) return;
        if (zone === 5) {
            if (dx < 0 && heroButton === 0) openNav();
            else if (dx) heroButton = Math.max(0,Math.min(2,heroButton+dx));
            if (dy > 0) zone = 2;
            if (dy < 0) openNav();
        } else if (zone === 0) {
            navIndex = Math.max(0, Math.min(navigation.length - 1, navIndex + dy));
            if (dx > 0) closeNav();
        } else if (zone === 4) {
            if (api.browsePath || api.home || api.watchlist || api.globalSearch) { if (dx < 0) openNav(); if (dy > 0 && (displayedItems.length || (recommended && api.hubs.length))) zone = 2; return; }
            if (dx < 0 && tabIndex === 0) openNav();
            else tabIndex = Math.max(0, Math.min(tabs.length-1,tabIndex+dx));
            if (dy > 0) zone = api.view === 1 && !api.browsePath && !api.home ? 1 : displayedItems.length ? 2 : 4;
        } else if (zone === 1) {
            if (dx < 0 && filterButton === 0) openNav();
            else filterButton = Math.max(0, Math.min(api.browsePath ? 0 : 2, filterButton + dx));
            if (dy > 0) zone = displayedItems.length ? 2 : 1;
            if (dy < 0) zone = 4;
        } else if (zone === 2) {
            if (recommended) {
                if (dx < 0 && itemIndex === 0) { openNav(); return; }
                if (dx && displayedItems.length) itemIndex = Math.max(0, Math.min(displayedItems.length-1,itemIndex+dx));
                if (dy < 0 && hubIndex === 0) { if (displayedItems.length) { zone = 5; heroButton = 0; } else openNav(); return; }
                if (dy && hubIndex+dy >= 0 && hubIndex+dy < api.hubs.length) { hubIndex += dy; itemIndex = Math.max(0, Math.min(itemIndex,displayedItems.length-1)); }
                return;
            }
            var column = itemIndex % columns;
            var row = Math.floor(itemIndex / columns);
            if (dx < 0 && column === 0) { openNav(); return; }
            if (dx && column + dx >= 0 && column + dx < columns && itemIndex + dx < api.items.length) { itemIndex += dx; preferredColumn = itemIndex % columns; }
            if (dy < 0) { if (row === 0) { if ((api.watchlist || api.globalSearch) && !api.browsePath) openNav(); else zone = api.view === 1 && !api.browsePath ? 1 : 4; } else itemIndex = (row - 1) * columns + preferredColumn; }
            if (dy > 0) {
                if ((row + 1) * columns < api.items.length) itemIndex = Math.min(api.items.length - 1, (row + 1) * columns + preferredColumn);
                else if (api.page > 0 || api.total > api.pageSize) { zone = 3; pageButton = (api.page + 1) * api.pageSize < api.total ? 1 : 0; }
            }
        } else {
            var pageIndex=pageActions.indexOf(pageButton);
            if (dx < 0 && pageIndex <= 0) openNav();
            else if (dx && pageActions.length) pageButton=pageActions[Math.max(0,Math.min(pageActions.length-1,pageIndex+dx))];
            if (dy < 0) zone = api.items.length ? 2 : 1;
        }
    }
    Keys.onPressed: {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) { back(); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select || event.key === Qt.Key_Space) { activate(); event.accepted = true; }
        else if (event.key === Qt.Key_Left) { move(-1,0); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { move(1,0); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { move(0,-1); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { move(0,1); event.accepted = true; }
        else if (event.key === Qt.Key_Menu && isLibrary && !api.error) { openSettings(); event.accepted = true; }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: shell.timeText = Qt.formatTime(new Date(), "hh:mm") }
    onCurrentChanged: heroTimer.restart()
    Timer { id: heroTimer; interval: 140; onTriggered: { if (shell.hero.ratingKey !== shell.current.ratingKey) shell.hero = shell.current; previewDelay.restart(); } }
    Timer { id: previewDelay; interval: 450; onTriggered: if (shell.isLibrary && shell.visible && !shell.detailOpen) api.previewMedia(shell.current) }
    Connections {
        target: api
        onProfileIdChanged: { shell.focusHistory=[];shell.restoreIndex=-1;shell.restoreDetail=null; }
        onServerUrlChanged: { shell.focusHistory=[];shell.restoreIndex=-1;shell.restoreDetail=null; }
        onLibraryLoaded: {
            shell.hubIndex = shell.restoreIndex >= 0 ? shell.restoreHub : 0;
            shell.tabIndex = 0;
            shell.itemIndex = shell.restoreIndex >= 0 ? Math.min(shell.restoreIndex, Math.max(0,shell.displayedItems.length - 1)) : 0;
            shell.restoreIndex = -1; shell.preferredColumn = shell.itemIndex % shell.columns;
            grid.positionViewAtIndex(shell.itemIndex, GridView.Beginning);
            if (!shell.displayedItems.length && shell.zone === 2 && !(api.home && api.hubs.length)) shell.zone = api.watchlist || api.globalSearch ? 0 : api.home ? 4 : api.view === 1 && !api.browsePath ? 1 : 4;
            // A late catalogue reply must not move the user's sidebar selection or steal a modal's focus.
            if (shell.zone !== 0) {
                shell.navIndex=api.globalSearch ? 2 : api.watchlist ? 0 : 1;
                for (var i=0; i<api.pinnedLibraries.length; i++) if (api.pinnedLibraries[i].key === api.section.key && !api.globalSearch && !api.watchlist && !api.home) shell.navIndex=i+3;
            }
            shell.hero = shell.current;
            if(shell.restoreDetail){
                var previous=shell.restoreDetail;shell.restoreDetail=null;api.detail=previous.detail;
                shell.detailButton=previous.detailButton;shell.detailZone=previous.detailZone;shell.detailSecondary=previous.detailSecondary;shell.detailOpen=true;
                detailView.ensureVisible();
            }
            if (api.state === "library") shell.takeFocus();
        }
        onDetailsLoaded: {
            if (shell.homePlayPending) {
                shell.homePlayPending = false;
                if (api.detail.type === "show" || api.detail.type === "season") { shell.rememberFocus(); api.openChildren(); }
                else api.play(true);
            } else { shell.detailOpen = true; shell.detailButton = api.detail.cloudOnly ? 3 : 0; shell.detailZone = 0; shell.detailSecondary = 0; }
            shell.takeFocus();
        }
        onGenresLoaded: { if (shell.dropdown === "genre" && shell.genrePending) { shell.genrePending = false; shell.dropdownIndex = shell.selectedGenre(); } }
        onPreviewLoaded: if (media.ratingKey === shell.current.ratingKey) shell.hero = media
        onPlaybackRequested: shell.startPlayback(url, media, offset)
        onErrorChanged: { if (api.error) { shell.homePlayPending = false; shell.errorChoice = 0; shell.closeDropdown(); } }
        onStateChanged: {if(api.state!=="library"){shell.detailOpen=false;shell.sheet="";shell.hero=({});shell.restoreIndex=-1;shell.restoreDetail=null;shell.settingsCapture++;shell.closeDropdown();}stateFocus.restart();}
    }

    Rectangle { anchors.fill: parent; color: "#080808"; visible: isLibrary || api.state === "servers" }
    HomeView { id: homeView; anchors.fill: parent; api: shell.api; controller: shell; visible: isLibrary && shell.recommended && !shell.detailOpen
    }
    Item {
        id: content; objectName: "libraryContent"; x: shell.sidebarWidth - 64; width: shell.width - x; height: 720; visible: isLibrary && !shell.detailOpen && !shell.recommended
        Row { x: 88; y: 22; spacing: 8; visible: !api.home && !api.watchlist && !api.globalSearch && !api.browsePath
            Repeater { model: shell.tabs
                Item { width: tabText.implicitWidth + 64; height: 48
                    Rectangle { anchors.fill: parent; radius: 4; color: shell.contentFocused && shell.zone === 4 && shell.tabIndex === index ? "white" : "transparent" }
                    Text { textFormat: Text.PlainText; id: tabText; x:15; anchors.verticalCenter:parent.verticalCenter; text: shell.viewOptions[shell.viewOption].title; font.family: typeface.name; font.pixelSize: 19; color: shell.contentFocused && shell.zone === 4 && shell.tabIndex === index ? "#202020" : "white" }
                    TvIcon { anchors.right:parent.right; anchors.rightMargin:16; anchors.verticalCenter:parent.verticalCenter; width:16;height:16;kind:"down";ink:tabText.color }
                    Rectangle { x: 7; y: 52; height: 2; width: parent.width-14; color: "#59d6a6"; visible: api.view === 1 }
                    MouseArea { anchors.fill: parent; onClicked: { shell.selectTab(index); shell.takeFocus(); } }
                }
            }
        }
        IconButton { x: 88; y: 22; width: 46; height: 46; visible: !!api.browsePath; label:"Revenir à la liste précédente";icon:"back";highlighted: shell.contentFocused && (shell.zone === 4 || shell.zone === 1); onClicked: { shell.goParent(); shell.takeFocus(); } }
        Text {textFormat:Text.PlainText;x:152;y:32;width:content.width-370;visible:!!api.browsePath;text:api.browseTitle;font.family:typeface.name;font.pixelSize:22;color:"white";elide:Text.ElideRight}
        Text { textFormat: Text.PlainText; x: 96; y: 32; width: content.width-316; elide: Text.ElideRight; text: api.globalSearch ? "Recherche dans toutes les bibliothèques" : api.watchlist ? "Liste de suivis" : "Accueil"; visible: (api.home || api.watchlist || api.globalSearch) && !api.browsePath; font.family: typeface.name; font.pixelSize: 23; color: "white" }
        Text { textFormat: Text.PlainText; x: content.width-180; y: 32; width: 112; text: shell.timeText; horizontalAlignment: Text.AlignRight; color: "#aaa"; font.family: typeface.name; font.pixelSize: 20 }
        Row { x: 96; y: 94; spacing: 12; visible: api.view === 1 && !api.watchlist && !api.globalSearch && !api.browsePath
            FilterButton { width: 154; text: shell.filterOptions[api.filterIndex].title; highlighted: shell.contentFocused && shell.zone === 1 && shell.filterButton === 0 && !shell.dropdown; expanded: shell.dropdown === "status"; filtered: api.filterIndex > 0; onClicked: { shell.openFilter(0); shell.takeFocus(); } }
            FilterButton { width: 236; text: api.genreTitle; highlighted: shell.contentFocused && shell.zone === 1 && shell.filterButton === 1 && !shell.dropdown; expanded: shell.dropdown === "genre"; filtered: api.genreTitle !== "Tous les genres"; onClicked: { shell.openFilter(1); shell.takeFocus(); } }
            Text { textFormat: Text.PlainText; width: 30; height: 46; text: "par"; color: "#aaa"; font.family: typeface.name; font.pixelSize: 18; verticalAlignment: Text.AlignVCenter }
            FilterButton { width: 286; text: (shell.sortOptions[api.sortIndex] || shell.sortOptions[0]).title; highlighted: shell.contentFocused && shell.zone === 1 && shell.filterButton === 2 && !shell.dropdown; expanded: shell.dropdown === "sort"; onClicked: { shell.openFilter(2); shell.takeFocus(); } }
            Text { textFormat: Text.PlainText; width: Math.max(80,content.width-878); height: 46; elide: Text.ElideRight; text: api.busy ? "Chargement…" : api.total + ((api.section || {}).type === "show" ? " séries" : " films"); color: "#aaa"; font.family: typeface.name; font.pixelSize: 19; verticalAlignment: Text.AlignVCenter }
        }
        Text { textFormat: Text.PlainText; x: 96; y: 104; visible: !shell.recommended && (api.watchlist || api.globalSearch || api.view !== 1 || !!api.browsePath); text: ((api.busy || (api.globalSearch && api.homeLoading)) ? "Chargement… · " : "") + shell.countLabel; font.family: typeface.name; font.pixelSize: 20; color: "#aaa" }
        Text { textFormat: Text.PlainText; x: 96; y: 148; width: content.width-164; elide: Text.ElideRight; visible: !!api.searchText; text: "Résultats pour « " + api.searchText + " »"; font.family: typeface.name; font.pixelSize: 16; color: "#59d6a6" }
        GridView {
            id: grid; objectName: "posterGrid"; x: 84; y: 176; width: Math.floor((content.width-132)/184)*184; height: 484; visible: !shell.recommended
            cellWidth: 184; cellHeight: 330; model: api.items; currentIndex: shell.itemIndex; interactive: false; clip: true
            highlightRangeMode: GridView.ApplyRange; preferredHighlightBegin: 0; preferredHighlightEnd: 330; highlightMoveDuration: 130
            delegate: PosterCard { api: shell.api; media: modelData; highlighted: shell.contentFocused && shell.zone === 2 && shell.itemIndex === index && !shell.sheet && !shell.dropdown && !api.error
                onClicked: { shell.zone = 2; shell.itemIndex = index; shell.preferredColumn = index % shell.columns; shell.openCurrent(); shell.takeFocus(); }
            }
        }
        Rectangle { x: content.width-65; y: 186; width: 3; height: 458; color: "#353535"; visible: !shell.recommended && grid.contentHeight > grid.height
            Rectangle { width: 3; height: Math.max(24,parent.height * grid.height / Math.max(1,grid.contentHeight)); y: Math.max(0,Math.min(parent.height-height,grid.contentY/Math.max(1,grid.contentHeight-grid.height)*(parent.height-height))); color: "#888" }
        }
        Column { x: 96; y: 248; width: content.width-160; spacing: 20; visible: !shell.displayedItems.length && !api.busy && !shell.recommended
            Text { textFormat: Text.PlainText; text: api.watchlist ? "Votre liste de suivis est vide" : api.view === 2 ? "Aucune collection" : api.view === 3 ? "Aucune liste de lecture" : "Aucun titre"; font.family: typeface.name; font.pixelSize: 32; color: "white" }
            Text { textFormat: Text.PlainText; width: parent.width; text: api.watchlist ? "Ajoutez des films et séries à votre Watchlist dans Plex." : api.view === 2 || api.view === 3 ? "Les éléments créés dans Plex apparaîtront ici." : "Essayez une autre bibliothèque ou modifiez les filtres."; font.family: typeface.name; font.pixelSize: 21; color: "#bbb"; wrapMode: Text.Wrap }
        }
        Rectangle { x: 64; y: 667; width: content.width-64; height: 53; color: "#ed080808" }
        Text { textFormat: Text.PlainText; x: 96; y: 682; text: api.globalSearch && api.searchNotice ? api.searchNotice : api.homeNotice && api.home ? api.homeNotice : api.browseTitle; font.family: typeface.name; font.pixelSize: 16; color: "#aaa"; width: content.width-720; elide: Text.ElideRight }
        Text { textFormat: Text.PlainText; x: content.width-595; y: 682; width: 180; horizontalAlignment: Text.AlignRight; text: shell.displayedItems.length ? (shell.recommended ? (shell.hubIndex+1) + " / " + api.hubs.length : (api.page * api.pageSize + shell.itemIndex+1) + " / " + api.total) : ""; font.family: typeface.name; font.pixelSize: 16; color: "#aaa" }
        Row {objectName:"pageControls";x:content.width-380;y:674;spacing:12
            IconButton {width:36;height:36;icon:"first";label:"Première page";available:api.page>0;highlighted:shell.contentFocused && shell.zone===3 && shell.pageButton===2;onClicked:{shell.pageButton=2;shell.changePage(-api.page);shell.takeFocus();}}
            IconButton {width:36;height:36;icon:"left";label:"Page précédente";available:api.page>0;highlighted:shell.contentFocused && shell.zone===3 && shell.pageButton===0;onClicked:{shell.pageButton=0;shell.changePage(-1);shell.takeFocus();}}
            Text {textFormat:Text.PlainText;width:142;height:36;text:"Page "+(api.page+1)+" / "+Math.max(1,Math.ceil(api.total/api.pageSize));horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;font.family:typeface.name;font.pixelSize:16;color:"#d0d0d0"}
            IconButton {width:36;height:36;icon:"right";label:"Page suivante";available:(api.page+1)*api.pageSize<api.total;highlighted:shell.contentFocused && shell.zone===3 && shell.pageButton===1;onClicked:{shell.pageButton=1;shell.changePage(1);shell.takeFocus();}}
        }
    }
    Rectangle {
        id: sidebar; objectName: "sidebar"; width: shell.navOpen ? 280 : 64; height: 720; visible: isLibrary && !shell.detailOpen
        color: "#101010"; clip: true
        Behavior on width { NumberAnimation { duration: 130 } }
        Brand { x: (parent.width-width)/2; y: 15; compact:true; visible:shell.navOpen }
        ListView { id: nav; objectName: "navigationList"; x: 0; y: shell.navOpen ? 115 : 20; width: parent.width; height: parent.height-y-18; interactive: false; clip: true; model: shell.navigation; currentIndex: shell.navIndex; highlightRangeMode: ListView.ApplyRange; preferredHighlightBegin: 0; preferredHighlightEnd: height-64; highlightMoveDuration: 130
            delegate: Item { width: nav.width; height: 64
                property bool focused: shell.navOpen && shell.navIndex === index
                property bool active: (index === 2 && api.globalSearch) || (index === 0 && api.watchlist) || (index === 1 && api.home) || (!api.home && !api.watchlist && !api.globalSearch && index > 2 && index-3 < api.pinnedLibraries.length && api.pinnedLibraries[index-3].key === api.section.key)
                Rectangle { y: 2; width: parent.width; height: 50; radius: 12; color: parent.focused ? "#a20d3326" : "transparent"; border.color: parent.focused ? "#5865ffe3" : "transparent"
                    GlowFrame { visible: parent.parent.focused; corner: 12; strength: .7 }
                    Rectangle { width: 3; height: parent.height; radius: 2; color: "#65ffe3"; visible: parent.parent.focused }
                }
                TvIcon { x: 20; y: 15; width: 22; height: 22; kind: modelData.icon; ink: parent.focused ? "#fcfcfc" : parent.active ? "#59d6a6" : "#b6b6b6" }
                Text { textFormat: Text.PlainText; visible: shell.navOpen; x: 57; width: parent.width-x-12; y: 17; text: modelData.title; font.family: typeface.name; font.pixelSize: 18; elide: Text.ElideRight; color: parent.focused || parent.active ? "#fcfcfc" : "#bbbbbb" }
                MouseArea { anchors.fill: parent; onClicked: { shell.openNav(); shell.navIndex = index; shell.selectNav(); shell.takeFocus(); } }
            }
        }
    }

    AuthScreen { anchors.fill: parent; api: shell.api;rememberFocused:shell.authChoice===1; visible: api.state === "auth" || api.state === "starting"; onConnectRequested: { api.connectAccount(); shell.takeFocus(); }onRememberToggled:{api.setRememberAccount(!api.rememberAccount);shell.authChoice=1;shell.takeFocus();} }
    ProfileScreen {id:profilePanel;anchors.fill:parent;api:shell.api;visible:api.state==="profiles"}
    LibraryScreen {id:libraryPanel;objectName:"libraryPanel";anchors.fill:parent;api:shell.api;visible:api.state==="libraries"}
    Item {
        anchors.fill: parent; visible: api.state === "servers"
        Text { textFormat: Text.PlainText; x: 90; y: 75; text: "Choisissez votre serveur"; color: "#f5f5f5"; font.family: typeface.name; font.pixelSize: 38; font.weight: Font.DemiBold }
        Text { textFormat: Text.PlainText; x: 90; y: 135; text: "Votre choix sera retrouvé automatiquement au prochain lancement."; color: "#afafaf"; font.family: typeface.name; font.pixelSize: 22 }
        ListView { x: 90; y: 214; width: 1100; height: 390; spacing: 14; clip: true; model: api.servers; currentIndex: shell.serverIndex; highlightRangeMode: ListView.ApplyRange
            delegate: TvButton { width: 1100; height: 74; text: modelData.name; textSize: 25; highlighted: !api.error && index === shell.serverIndex; onClicked: { api.chooseServer(index); shell.takeFocus(); } }
        }
    }

    DetailView { id:detailView;objectName:"detailView";anchors.fill:parent;api:shell.api;controller:shell;visible:shell.detailOpen }

    Rectangle { anchors.fill: parent; color: "#6b000000"; visible: !!shell.dropdown; MouseArea { anchors.fill: parent; onClicked: { shell.closeDropdown(); shell.takeFocus(); } } }
    DropdownMenu {
        id: filterMenu; objectName: "filterMenu"
        visible: !!shell.dropdown; x: shell.dropdown==="view" ? 96 : shell.filterButton === 0 ? 96 : shell.filterButton === 1 ? 262 : 552; y: shell.dropdown==="view" ? 78 : 148
        width: shell.dropdown === "sort" ? 400 : 330; title: shell.dropdown==="view" ? "AFFICHER" : shell.dropdown === "status" ? "STATUT" : shell.dropdown === "sort" ? "TRIER PAR" : "GENRE"
        options: shell.dropdownOptions; focusedIndex: shell.dropdownIndex; selectedIndex: shell.dropdownSelected; loading: shell.genrePending
        onChosen: { shell.applyFilter(index); shell.takeFocus(); }
    }
    Rectangle {
        anchors.fill: parent; color: "#da000000"; visible: !!shell.sheet && shell.sheet !== "search" && shell.sheet !== "settings"
        Rectangle {
            x: 320; y: 86; width: 640; height: 548; radius: 14; color: "#303030"; border.color: "#505050"
            Text { textFormat: Text.PlainText; x: 36; y: 28; width: parent.width - 72; text: shell.sheet === "info" ? "Informations du média" : shell.sheet === "trailers" ? "Bandes-annonces" : shell.sheet==="about" ? "À propos" : "Compte"; font.family: typeface.name; font.pixelSize: 28; color: "#f3f3f3"; elide: Text.ElideRight }
            ListView { x: 32; y: 106; width: 576; height: 350; spacing: 12; visible: shell.sheet === "trailers"; clip: true; interactive: false; model: shell.sheetOptions; currentIndex: shell.sheetIndex; highlightRangeMode: ListView.ApplyRange
                delegate: TvButton { width: 576; height: 58; text: modelData.title; highlighted: !api.error && shell.sheetIndex === index; onClicked: { shell.sheetIndex = index; shell.sheetAction(); shell.takeFocus(); } }
            }
            Text { textFormat: Text.PlainText; x: 36; y: 78; width: parent.width - 72; visible: shell.sheet === "account"; text: (api.profileName ? api.profileName+" · " : "")+api.serverName + " · " + api.connectionLabel; font.family: typeface.name; font.pixelSize: 18; color: "#bababa";elide:Text.ElideRight }
            ListView { x: 32; y: 124; width: 576; height: 350; spacing: 10; visible: shell.sheet === "account";clip:true;interactive:false;currentIndex:shell.sheetIndex;highlightRangeMode:ListView.ApplyRange
                model: shell.accountActions
                delegate: TvButton { width: 576; height: 58; text: modelData.title; highlighted: !api.error && shell.sheetIndex === index; onClicked: { shell.sheetIndex = index; shell.sheetAction(); shell.takeFocus(); } }
            }
            Text { textFormat: Text.PlainText; x: 36; y: 122; width: parent.width - 72; visible: shell.sheet === "info"; text: Plex.technicalInfo(api.detail); wrapMode: Text.Wrap; font.family: typeface.name; font.pixelSize: 22; lineHeight: 1.6; color: "#ddd" }
            Text { textFormat: Text.PlainText;x:36;y:112;width:parent.width-72;visible:shell.sheet==="about";text:AppInfo.name+" · "+AppInfo.version+"\n\nClient indépendant en développement, sans affiliation à Plex, Free ou Devialet. Aucun contenu fourni.\n\nUn compte Plex et un serveur accessible sont nécessaires. La connexion est enregistrée uniquement si « Rester connecté » est activé. La déconnexion efface les jetons de ce Player.\n\nAucune publicité ni mesure d’audience ajoutée par ce client. Les échanges passent par Plex et votre serveur.";wrapMode:Text.Wrap;font.family:typeface.name;font.pixelSize:19;color:"#dddddd";lineHeight:1.2}
            RemoteHints { x:36;y:494;keySize:30;textSize:15;groupSpacing:26;actions:shell.sheet === "info" || shell.sheet === "about" ? [{key:"back",label:"Fermer"}] : [{key:"vertical",label:"Choisir"},{key:"ok",label:"Valider"},{key:"back",label:"Fermer"}] }
        }
    }
    SettingsPanel {
        anchors.fill: parent; visible: shell.sheet === "settings"; api: shell.api; selectedIndex: shell.sheetIndex
        backdrop: shell.settingsImage
        onChosen: { shell.sheetIndex = index; shell.sheetAction(); shell.takeFocus(); }
    }
    Rectangle { x: 650; y: 42; width: 560; height: Math.max(54,noticeText.implicitHeight+28); radius: 8; color: "#f0181818"; border.color: "#65ffe3"; visible: !!api.notice
        Text { id:noticeText; textFormat: Text.PlainText; anchors.centerIn: parent; width:parent.width-32;wrapMode:Text.Wrap;text: api.notice; font.family: typeface.name; font.pixelSize: 17; color: "#fcfcfc" }
    }
    Rectangle {
        anchors.fill: parent; color: "#f2080808"; visible: shell.sheet === "search"
        Text { textFormat: Text.PlainText; x: 120; y: 65; text: "Rechercher dans toutes les bibliothèques"; font.family: typeface.name; font.pixelSize: 32; color: "white" }
        Rectangle { x: 120; y: 139; width: 1040; height: 70; color: "#454545"; radius: 4
            Text { textFormat: Text.PlainText; x: 22; anchors.verticalCenter: parent.verticalCenter; width: 995; text: shell.searchDraft || "Titre du film ou de la série"; font.family: typeface.name; font.pixelSize: 26; color: shell.searchDraft ? "white" : "#aaa"; elide: Text.ElideLeft }
        }
        Grid { x: 120; y: 246; columns: 10; spacing: 10
            Repeater { model: shell.keyboardKeys
                Rectangle { width: 95; height: 64; radius: 4; color: shell.keyboardIndex === index ? "white" : "#454545"
                    Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: modelData; font.family: typeface.name; font.pixelSize: index < 36 ? 24 : 13; color: shell.keyboardIndex === index ? "#222" : "#eee" }
                    MouseArea { anchors.fill: parent; onClicked: { shell.keyboardIndex = index; shell.searchKey(); shell.takeFocus(); } }
                }
            }
        }
        RemoteHints { x:120;y:602;actions:[{key:"arrows",label:"Choisir une lettre"},{key:"ok",label:"Valider"},{key:"back",label:"Fermer"}] }
    }
    Rectangle {
        anchors.fill: parent; color: "#ed000000"; visible: !!api.error
        Column { anchors.centerIn: parent; width: 840; spacing: 28
            Text { textFormat: Text.PlainText; text: "Action indisponible"; color: "#f5f5f5"; font.family: typeface.name; font.pixelSize: 38; font.weight: Font.DemiBold }
            Text { textFormat: Text.PlainText; width: parent.width; text: api.error; color: "#c6c6c6"; font.family: typeface.name; font.pixelSize: 25; wrapMode: Text.Wrap; lineHeight: 1.3 }
            Row { spacing: 18
                TvButton { text: "Réessayer"; width: 240; height: 58; highlighted: shell.errorChoice === 0; onClicked: { api.retry(); shell.takeFocus(); } }
                TvButton { text: "Retour"; width: 170; height: 58; highlighted: shell.errorChoice === 1; onClicked: shell.back() }
            }
        }
    }
    Text { textFormat: Text.PlainText; visible: (api.busy || api.homeLoading) && isLibrary && !shell.dropdown && !api.error && shell.recommended; x: 930; y: 682; width: 298; horizontalAlignment: Text.AlignRight; text: "Chargement…"; font.family: typeface.name; font.pixelSize: 16; color: "#59d6a6" }
}
