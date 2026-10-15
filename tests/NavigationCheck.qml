import QtQuick 2.4
import fbx.application 1.0

Application {
    id: root
    property int step: 0
    property int failures: 0
    property bool finished: false
    readonly property var api: scene.service
    readonly property var shell: scene.controller
    NavigationFixture { id:scene; anchors.fill:parent }
    function report(name,ok){console.log((ok ? "QA_PASS " : "QA_FAIL ")+name);if(!ok)failures++;}
    function find(item,name){if(item.objectName===name)return item;var children=item.children || [];for(var i=0;i<children.length;i++){var match=find(children[i],name);if(match)return match;}return null;}
    function glowCount(item){var n=item.objectName==="focusGlow" && item.visible ? 1 : 0,children=item.children || [];for(var i=0;i<children.length;i++)n+=glowCount(children[i]);return n;}
    function finish(){finished=true;console.log("QA_DONE failures="+failures);}
    Timer {interval:400;repeat:true;running:!root.finished
        onTriggered:{
            try {
                if(root.step===0){
                    var items=[];for(var i=0;i<16;i++)items.push({type:"movie",ratingKey:String(i+1),title:"Film de démonstration "+(i+1),year:2025,duration:5400000,summary:"Données fictives pour vérifier la navigation."});
                    api.allItems=items;api.items=items;api.hubs=[{title:"Continuer à regarder",items:items}];shell.zone=2;api.showHome();
                } else if(root.step===1){root.report("home_single_focus_collapsed",glowCount(shell)===1 && shell.sidebarWidth===64);shell.openNav();}
                else if(root.step===2){root.report("home_single_focus_expanded",glowCount(shell)===1 && shell.sidebarWidth===280);shell.closeNav();api.hubs=[];api.homeNotice="Épinglez vos bibliothèques depuis Mes bibliothèques pour personnaliser l’accueil.";shell.zone=2;api.libraryLoaded();}
                else if(root.step===3){root.report("empty_home_has_action",shell.zone===4 && glowCount(shell)===1);shell.openNav();}
                else if(root.step===4){var text=root.find(shell,"homeEmptyText"),pos=text.mapToItem(shell,0,0);root.report("empty_home_text_clear_of_sidebar",pos.x>=312 && pos.x+text.width<=1241 && text.lineCount>=2);shell.closeNav();shell.activate();}
                else if(root.step===5){root.report("library_preferences_reachable",api.state==="libraries");root.find(shell,"libraryPanel").openOptions();}
                else if(root.step===6){root.report("library_options_single_focus",glowCount(shell)===1);api.classifyLibrary(0,"mature");root.report("mature_distinct_from_explicit",api.libraryFlag(api.libraries[0].key,"mature") && !api.libraryFlag(api.libraries[0].key,"adult"));api.closeLibraries();api.selectLibrary(0);shell.zone=1;shell.openFilter(2);shell.dropdownIndex=11;}
                else if(root.step===7){root.report("sort_menu_last_option_focused",glowCount(shell)===1 && shell.dropdownOptions.length===12);shell.applyFilter(11);root.report("sort_menu_applies_order",api.sortIndex===11);shell.zone=2;shell.openCurrent();}
                else if(root.step===8){
                    var d=JSON.parse(JSON.stringify(api.detail));d.Role=[];for(var a=0;a<12;a++)d.Role.push({id:String(a),tag:"Interprète "+a,role:"Personnage"});
                    d.Extras={Metadata:[]};for(var e=0;e<9;e++)d.Extras.Metadata.push({title:"Bonus "+e,extraType:e===0 ? 1 : 2,Media:[{Part:[{key:"/library/parts/fixture/file.mp4"}]}]});api.detail=d;
                    shell.detailZone=0;shell.detailButton=5;
                } else if(root.step===9){root.report("detail_reel_single_focus",glowCount(shell)===1);shell.activate();root.report("detail_trailer_action",api.trailerCount===1);shell.move(0,1);shell.move(0,1);for(var a=0;a<11;a++)shell.move(1,0);}
                else if(root.step===10){root.report("detail_cast_scroll_focus",shell.detailZone===2 && shell.detailSecondary===11 && glowCount(shell)===1);shell.activate();shell.back();root.report("actor_back_restores_detail_selection",shell.detailOpen && shell.detailZone===2 && shell.detailSecondary===11);shell.move(0,1);for(var e=0;e<7;e++)shell.move(1,0);}
                else if(root.step===11){root.report("detail_bonus_scroll_focus",shell.detailZone===3 && shell.detailSecondary===7 && glowCount(shell)===1);shell.activate();root.report("detail_bonus_correct_index",api.lastExtra===8);shell.back();shell.openSettings();}
                else if(root.step===12){api.error="Erreur simulée";}
                else if(root.step===13){root.report("error_over_settings_single_focus",glowCount(shell)===1);shell.activate();shell.back();shell.zone=2;shell.openCurrent();}
                else if(root.step===14){
                    var extended=JSON.parse(JSON.stringify(api.detail));
                    extended.summary="";for(var p=0;p<60;p++)extended.summary+="Un voyage inattendu mène les voyageurs à travers des paysages grandioses. ";
                    extended.summary+="Dernière phrase du résumé.";extended.Role=[{id:"1",tag:"Interprète"}];extended.Extras={};api.detail=extended;
                } else if(root.step===15){
                    var summary=root.find(shell,"detailSummary"),canvas=root.find(shell,"detailCanvas");
                    root.report("summary_complete_inline",summary.text===api.detail.summary && !summary.truncated && summary.height>canvas.height);
                    shell.move(0,1);shell.activate();shell.move(0,1);
                } else if(root.step===16){
                    var detail=root.find(shell,"detailView");
                    root.report("summary_remote_scroll_without_modal",shell.detailZone===1 && !shell.sheet && detail.scrollTarget>detail.summaryStart && glowCount(shell)===0);
                    for(var s=0;s<80 && detail.scrollTarget<detail.summaryEnd;s++)shell.move(0,1);
                } else if(root.step===17){
                    var summary=root.find(shell,"detailSummary"),canvas=root.find(shell,"detailCanvas");
                    root.report("summary_last_line_visible",shell.detailZone===1 && summary.mapToItem(shell,0,summary.height).y<=canvas.height-23);
                    shell.move(0,1);
                } else if(root.step===18){
                    root.report("summary_then_cast",shell.detailZone===2 && glowCount(shell)===1);
                    for(var u=0;u<80 && shell.detailZone!==0;u++)shell.move(0,-1);
                } else if(root.step===19){
                    root.report("summary_return_to_actions",shell.detailZone===0 && root.find(shell,"detailCanvas").contentY===0 && glowCount(shell)===1);
                    var cloud=JSON.parse(JSON.stringify(api.detail));cloud.cloudOnly=true;cloud.Role=[];api.detail=cloud;
                    for(var d=0;d<80;d++)shell.move(0,1);
                } else if(root.step===20){
                    var detail=root.find(shell,"detailView"),summary=root.find(shell,"detailSummary");
                    root.report("summary_watchlist_keeps_full_text",summary.text.indexOf(api.detail.summary)===0 && !summary.truncated);
                    root.report("summary_end_stays_put_without_rows",shell.detailZone===1 && detail.scrollTarget===detail.summaryEnd && summary.mapToItem(shell,0,summary.height).y<=root.find(shell,"detailCanvas").height-23);
                    root.finish();
                }
                root.step++;
            }catch(e){root.report("native_ui_exception_step_"+root.step,false);root.finish();}
        }
    }
    Timer {interval:30000;running:!root.finished;onTriggered:{root.report("native_ui_timeout",false);root.finish();}}
}
