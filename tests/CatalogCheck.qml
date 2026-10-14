import QtQuick 2.4
import fbx.application 1.0
import "Plex.js" as Plex

Application {
    id:root
    property var config: null
    property int phase: 0
    property int failures: 0
    property bool finished: false
    function report(name,ok){console.log((ok ? "QA_PASS " : "QA_FAIL ")+name);if(!ok)failures++;}
    function finish(){if(finished)return;finished=true;console.log("QA_DONE failures="+failures);}
    Component.onCompleted:{var xhr=new XMLHttpRequest();xhr.onreadystatechange=function(){if(xhr.readyState===XMLHttpRequest.DONE && xhr.status===200)root.config=JSON.parse(xhr.responseText);};xhr.open("GET",Qt.resolvedUrl("qa-config.json"));xhr.send();}
    PlexService {id:api
        onLibraryLoaded:{
            if(root.phase===1){root.report("global_search_all_results_allowed",api.items.length>0 && api.items.every(function(m){return Plex.allowedMedia(m,api.libraries);}) && !api.searchNotice);root.phase=2;api.section=root.config.libraries[0];api.selectView(2);}
            else if(root.phase===2){root.report("collections_endpoint",!api.error);root.phase=3;api.openMedia(root.config.media);}
            else if(root.phase===4){root.report("actor_filter_endpoint",!api.error);root.phase=5;api.loadProfiles();}
        }
        onDetailsLoaded:{if(root.phase===3){root.report("detail_with_chapters_extras",String(api.detail.ratingKey)===String(root.config.media.ratingKey));if((api.detail.Role || []).length && api.detail.Role[0].id){root.phase=4;api.openActor(0);}else{root.phase=5;api.loadProfiles();}}}
        onNextEpisodeReady:{if(root.phase===6){root.report("next_episode_endpoint",!media.ratingKey || Plex.allowedMedia(media,api.libraries));root.finish();}}
    }
    Timer {interval:500;repeat:true;running:!root.finished
        onTriggered:{
            if(!root.config)return;
            if(api.error){root.report("catalog_error_phase_"+root.phase,false);root.finish();return;}
            if(root.phase===0 && api.state==="auth"){
                api.ownerToken=root.config.token;api.accountToken=root.config.token;api.serverUrl=root.config.base;api.serverToken=root.config.token;api.libraries=root.config.libraries;api.state="library";
                root.phase=1;api.search(root.config.query);
            }else if(root.phase===5 && !api.profilesLoading){
                root.report("native_xml_home_profiles",api.profiles.length>0 && !api.profileError);
                api.state="library";root.phase=6;api.autoNextEpisode=true;api.prepareNextEpisode(root.config.media);
            }
        }
    }
    Timer {interval:90000;running:!root.finished;onTriggered:{root.report("catalog_timeout_phase_"+root.phase,false);root.finish();}}
}
