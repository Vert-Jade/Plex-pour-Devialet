.pragma library

var languages = [{title:"Choix de Plex",value:""},{title:"Français",value:"fra"},{title:"Anglais",value:"eng"},{title:"Japonais",value:"jpn"},{title:"Espagnol",value:"spa"},{title:"Allemand",value:"deu"},{title:"Italien",value:"ita"}];
function languageTitle(value) { for(var i=0;i<languages.length;i++) if(languages[i].value===value)return languages[i].title;return "Choix de Plex"; }
function settingsRows(a) {
    return [
        {title:"Passer les intros",hint:"Saut automatique lorsqu’un repère Plex est disponible.",value:a.autoSkipIntro ? "Automatique" : "Désactivé",icon:"skip"},
        {title:"Passer les génériques de fin",hint:"Les scènes après le générique restent accessibles.",value:a.autoSkipCredits ? "Automatique" : "Désactivé",icon:"credits"},
        {title:"Recul à la reprise",hint:"Revoir quelques secondes pour retrouver le fil.",value:a.rewindSeconds ? a.rewindSeconds+" secondes" : "Aucun",icon:"rewind"},
        {title:"Taille de l’interface",hint:"Ajustez jusqu’à voir tous les bords de l’interface.",value:a.uiScale+" %",icon:"screen"},
        {title:"Thèmes musicaux",hint:"Écouter le thème du titre sélectionné lorsqu’il est disponible.",value:a.themeMusic ? "Activés" : "Désactivés",icon:"music"},
        {title:"Volume des thèmes",hint:"Un volume indépendant de celui des films et séries.",value:a.themeVolume+" %",icon:"volume"},
        {title:"Langue audio préférée",hint:"Si cette langue est absente, conserver le choix de Plex.",value:languageTitle(a.audioLanguage),icon:"volume"},
        {title:"Langue des sous-titres",hint:"Utiliser les pistes disponibles dans le fichier ou sur le serveur.",value:languageTitle(a.subtitleLanguage),icon:"info"},
        {title:"Sous-titres par défaut",hint:"Modifiable pendant chaque lecture depuis les options.",value:["Choix de Plex","Désactivés","Toujours","Audio étranger"][a.subtitlePolicy || 0],icon:"info"},
        {title:"Bande-annonce avant un film",hint:"Une bande-annonce disponible ; uniquement avant une nouvelle lecture.",value:a.cinemaTrailers ? "Activée" : "Désactivée",icon:"play"},
        {title:"Retrouver mon profil",hint:"Ouvrir le dernier profil connecté au démarrage de l’application.",value:a.rememberProfile ? "Automatique" : "Choisir au début",icon:"user"},
        {title:"Épisode suivant",hint:"Un compte à rebours de 15 secondes, annulable avec Retour.",value:a.autoNextEpisode ? "Automatique" : "Désactivé",icon:"play"},
        {title:"Rester connecté",hint:"Mémoriser la connexion sur ce Player. Aucun mot de passe Plex enregistré.",value:a.rememberAccount ? "Activé" : "Cette session",icon:"user"},
        {title:"Résultats adultes dans la recherche",hint:"Selon la classification Plex et les bibliothèques signalées comme adultes.",value:a.allowAdultSearch ? "Autorisés" : "Masqués",icon:"search"},
        {title:"Mes bibliothèques",hint:"Choisir les bibliothèques épinglées et celles réservées aux adultes.",value:"Choisir",icon:"folder"}
    ];
}
function preferenceMap(serialized) {
    try {
        var value = JSON.parse(serialized || "{}");
        return value && typeof value === "object" && !(value instanceof Array) ? value : {};
    } catch(e) { return {}; }
}
function libraryPreferences(serialized,scope) {
    var values = preferenceMap(serialized);
    if (!Object.prototype.hasOwnProperty.call(values,scope)) return null;
    var prefs = values[scope];
    if (!prefs || !(prefs.pinned instanceof Array) || !(prefs.adult instanceof Array)) return null;
    return {pinned:prefs.pinned.map(String),adult:prefs.adult.map(String)};
}
function adultSearchResult(item,library,adultLibraries) {
    if((adultLibraries || []).indexOf(String(library.key))>=0)return true;
    var rating=String(item.contentRating || item.parentContentRating || item.grandparentContentRating || "").toUpperCase().replace(/\s/g,"");
    // Age restrictions alone (18+, NC-17, TV-MA) do not mean explicit content.
    return /^(?:[A-Z]{2}\/)?(?:X|XXX|ADULT|R18)$/.test(rating) || item.adult===true || item.adult===1;
}
function allowNextCountdown(item,lastInteraction,now) {
    return Number(item.duration || 0)<1200000 || now-lastInteraction<7200000;
}
function xmlNode(node) {
    if (!node || node.nodeType !== 1) throw new Error("Invalid XML");
    var result={},i,a,child;
    // Qt's embedded DOM exposes indexed collections, without NodeList.item().
    for(i=0;i<node.attributes.length;i++){ a=node.attributes[i];result[a.nodeName]=a.nodeValue; }
    for(i=0;i<node.childNodes.length;i++){ child=node.childNodes[i];if(child.nodeType===1){if(!result[child.nodeName])result[child.nodeName]=[];result[child.nodeName].push(xmlNode(child));} }
    return result;
}
function chapters(item) {
    return ((item || {}).Chapter || []).filter(function(c){return isFinite(Number(c.startTimeOffset)) && Number(c.startTimeOffset)>=0 && Number(c.startTimeOffset)<Number(item.duration);}).map(function(c,i){return {title:(c.title || "Chapitre "+(i+1))+" · "+clock(c.startTimeOffset),value:Number(c.startTimeOffset),thumb:safePath(c.thumb) ? c.thumb : ""};});
}
function extras(item) { return (((item || {}).Extras || {}).Metadata || []).filter(function(e){return !!trailerPart(e);}); }
function mergeSearch(existing,rows,library,libraries) {
    var output=existing.slice(),seen={};output.forEach(function(m){seen[String(m.ratingKey)]=true;});
    rows.forEach(function(m){var copy=JSON.parse(JSON.stringify(m));if(!copy.librarySectionID)copy.librarySectionID=library.key;if(!allowedMedia(copy,libraries) || ["movie","show","episode"].indexOf(copy.type)<0 || !copy.ratingKey || seen[String(copy.ratingKey)])return;copy.libraryTitle=library.title;seen[String(copy.ratingKey)]=true;output.push(copy);});
    return output;
}

// Only Plex markers are used, preserving scenes between or after credits.
// Consume once per playback so the user can deliberately rewind into a marker.
function skipMarker(markers, position, duration, intro, credits, consumed) {
    if (!isFinite(position) || !isFinite(duration) || duration <= 0 || position < 0) return null;
    for (var i = 0; i < (markers || []).length; i++) {
        var marker = markers[i];
        if (!marker || (marker.type !== "intro" && marker.type !== "credits")) continue;
        if ((marker.type === "intro" && !intro) || (marker.type === "credits" && !credits)) continue;
        var start = Number(marker.startTimeOffset), end = Number(marker.endTimeOffset);
        if (marker.startTimeOffset === undefined || marker.endTimeOffset === undefined || marker.startTimeOffset === null || marker.endTimeOffset === null || !isFinite(start) || !isFinite(end) || start < 0 || end <= start || end > duration) continue;
        var key = marker.type + ":" + start + ":" + end;
        if (consumed[key] || position < start || position >= end) continue;
        return {key:key, target:end, type:marker.type};
    }
    return null;
}
function trailerPart(extra) {
    var variants = extra.Media || [], fallback = null;
    for (var i=0;i<variants.length;i++) {
        var media = variants[i], part = (media.Part || [])[0];
        if (!part || !safePath(part.key)) continue;
        if (!fallback) fallback = part;
        if (media.container === "mp4" && media.videoCodec === "h264" && media.audioCodec === "aac") return part;
    }
    return fallback;
}
function trailers(item) {
    return (((item || {}).Extras || {}).Metadata || []).filter(function(extra) { return Number(extra.extraType) === 1 && trailerPart(extra); });
}

function query(values) {
    var parts = [];
    for (var key in values) {
        if (values[key] !== undefined && values[key] !== "") parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(values[key]));
    }
    return parts.join("&");
}
function pathWithQuery(path, values) { return path + (path.indexOf("?") < 0 ? "?" : "&") + query(values); }
function privateHttp(uri) {
    return /^http:\/\/(10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)(:\d+)?\/?$/.test(uri);
}
function connections(server) {
    var rows = (server.connections || []).filter(function(c) {
        return /^https:\/\/[^\s/?#@]+\/?$/.test(c.uri) || (c.local && !server.httpsRequired && privateHttp(c.uri));
    });
    return rows.sort(function(a, b) {
        function score(c) { return (c.relay ? 100 : 0) + (c.local ? 0 : 20) + (/^https:/.test(c.uri) ? 0 : 5); }
        return score(a) - score(b);
    });
}
function libraryPath(section, filter, sort, genre, start, size) {
    var params = {sort: ["titleSort:asc", "addedAt:desc", "year:desc", "titleSort:desc", "originallyAvailableAt:desc", "rating:desc", "duration:desc"][sort] || "titleSort:asc",
        "X-Plex-Container-Start": start, "X-Plex-Container-Size": size};
    if (filter === 1) params.unwatched = 1;
    if (filter === 2) params.inProgress = 1;
    if (filter === 3) params.unwatched = 0;
    if (genre) params.genre = genre;
    return pathWithQuery(section.browseKey || "/library/sections/" + encodeURIComponent(section.key) + "/all", params);
}
function safePath(value) {
    if(typeof value!=="string" || !/^\/(?!\/)/.test(value) || /[\\\x00-\x20\x7f#]/.test(value))return false;
    var path=value.split("?")[0];
    try{path=decodeURIComponent(path);}catch(e){return false;}
    return !/[\\\x00-\x1f\x7f]/.test(path) && !/^\/\//.test(path) && !/(^|\/)\.\.?($|\/)/.test(path);
}
function mediaUrl(base, path, token) {
    if (!safePath(path)) return "";
    return base.replace(/\/$/, "") + pathWithQuery(path, {"X-Plex-Token": token});
}
function folderPath(path, sectionKey) {
    if (!safePath(path)) return false;
    var base = path.split("?")[0];
    return base === "/library/sections/"+encodeURIComponent(sectionKey)+"/folder" || /^\/library\/metadata\/\d+(\/children)?$/.test(base);
}
function duration(ms) {
    var minutes = Math.floor((Number(ms) || 0) / 60000);
    return minutes >= 60 ? Math.floor(minutes / 60) + " h " + (minutes % 60 ? minutes % 60 + " min" : "") : minutes + " min";
}
function qualityBadge(item) {
    var media = ((item || {}).Media || [])[0] || {};
    var resolution = Number(media.height || media.videoResolution);
    if (media.videoResolution === "4k" || resolution >= 2160) return "4K";
    if (resolution >= 720) return "HD";
    return media.videoResolution || media.height ? "SD" : "";
}
function clock(ms) {
    var secs = Math.max(0, Math.floor((Number(ms) || 0) / 1000));
    return Math.floor(secs / 60) + ":" + (secs % 60 < 10 ? "0" : "") + secs % 60;
}
function label(item) {
    if (item.type === "episode") {
        var parts = [];
        if (item.grandparentTitle) parts.push(item.grandparentTitle);
        var number = item.parentIndex !== undefined ? "S" + item.parentIndex : "";
        if (item.index !== undefined) number += "E" + item.index;
        if (number) parts.push(number);
        if (item.title) parts.push(item.title);
        return parts.join(" · ") || "Épisode";
    }
    return item.title || "Sans titre";
}
function age(value) {
    if (!value) return "";
    if (value === "fr/U" || value === "fr/TP") return "Tous publics";
    return /^fr\/\d+$/.test(value) ? value.slice(3) + "+" : value;
}
function technicalInfo(item) {
    var m = (item.Media || [])[0];
    if (!m) return "Aucune information technique disponible.";
    var rows = [];
    if (m.videoResolution) rows.push("Vidéo : " + String(m.videoResolution).toUpperCase() + (m.videoCodec ? " · " + m.videoCodec.toUpperCase() : ""));
    if (m.audioCodec) rows.push("Audio : " + m.audioCodec.toUpperCase() + (m.audioChannels ? " · " + m.audioChannels + " canaux" : ""));
    if (m.container) rows.push("Conteneur : " + m.container.toUpperCase());
    if (m.bitrate) rows.push("Débit : " + (Number(m.bitrate)/1000).toFixed(1) + " Mbit/s");
    return rows.join("\n") || "Aucune information technique disponible.";
}
function sortName(value) {
    return String(value || "").toLowerCase().replace(/[àâäáãå]/g,"a").replace(/[éèêë]/g,"e").replace(/[îïíì]/g,"i").replace(/[ôöóòõ]/g,"o").replace(/[ùûüú]/g,"u").replace(/ç/g,"c").replace(/œ/g,"oe");
}
function visibleLibraries(rows) {
    return rows.filter(function(s) {
        return s.type === "movie" || s.type === "show";
    }).sort(function(a,b) { var x=sortName(a.title),y=sortName(b.title); return x < y ? -1 : x > y ? 1 : 0; });
}
function allowedMedia(item, libraries) {
    for (var i=0;i<libraries.length;i++) if (String(libraries[i].key) === String(item.librarySectionID)) return true;
    return false;
}
function publicImage(path) {
    return typeof path === "string" && /^https:\/\/(image\.tmdb\.org|images\.plex\.tv|metadata-static\.plex\.tv|artworks\.thetvdb\.com)\//.test(path);
}
function resolveWatchlist(rows, matches, libraries) {
    var output = [];
    rows.forEach(function(row) {
        var all = matches.filter(function(m) { return m.guid === row.guid; });
        var allowed = all.filter(function(m) { return allowedMedia(m,libraries); });
        if (all.length && !allowed.length) return;
        var item = JSON.parse(JSON.stringify(allowed.length ? allowed[0] : row));
        item.watchlistGuid = row.guid; item.cloudOnly = !allowed.length;
        if (item.cloudOnly) { item.thumb = publicImage(item.thumb) ? item.thumb : ""; item.art = publicImage(item.art) ? item.art : ""; }
        output.push(item);
    });
    return output;
}
