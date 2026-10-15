"""Render the real Shell.qml with clearly fictional data, and exercise remote keys."""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_BACKEND'] = 'software'
import json
import hashlib
from pathlib import Path
import sys
from PySide6.QtCore import QUrl, Qt, QObject, QMetaObject, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication, QFont, QFontDatabase
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.local' / 'preview'
OUT.mkdir(parents=True, exist_ok=True)
store_marker = OUT / 'store-captures-ok.txt'
if store_marker.exists(): store_marker.unlink()
app = QGuiApplication(sys.argv)
qml_errors=[]
def qml_message(kind, context, message):
    if any(term in message for term in ('ReferenceError','TypeError','Error:','Cannot assign','Invalid property','Failed to')):
        qml_errors.append(message)
        print(message)
qInstallMessageHandler(qml_message)
QFontDatabase.addApplicationFont(str(ROOT/'app/fonts/NotoSans-Regular.ttf'))
QFontDatabase.addApplicationFont(str(ROOT/'app/fonts/NotoSans-SemiBold.ttf'))
app.setFont(QFont('Noto Sans'))
view = QQuickView()
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.setSource(QUrl.fromLocalFile(str(ROOT / 'tests/preview/Scene.qml')))
if view.status() == QQuickView.Error:
    for error in view.errors(): print(error.toString())
    raise SystemExit(1)
view.resize(1280,720)
view.show()
root = view.rootObject()
service = root.property('service')
if '--store' in sys.argv:
    assert '--real' not in sys.argv, 'Store screenshots must use fictional data.'
    service.setProperty('welcomeName','')
shell = root.findChild(QObject, 'shell')
titles = ['Au-delà des cimes','Le dernier voyage','Les jours heureux','La grande traversée','Une nuit à Paris','Lumière du Nord','Horizons','À contre-courant','Le temps retrouvé','Terre sauvage']
colors = [('172f42','daaa67'),('392732','d0ac91'),('264c48','d5cd9e'),('1b345a','cf9b5b'),('2d2946','bf8d8d')]
items = []
for i, title in enumerate(titles):
    c,a = colors[i%5]
    path = OUT / f'poster-{i}.svg'
    path.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="360" height="510"><defs><linearGradient id="g" x2="0" y2="1"><stop stop-color="#{c}"/><stop offset="1" stop-color="#080e16"/></linearGradient></defs><rect width="360" height="510" fill="url(#g)"/><circle cx="{130+i*9}" cy="155" r="87" fill="#{a}" opacity=".65"/><path d="M0 355L100 195L210 370L305 255L360 365V510H0" fill="#{c}"/><path d="M0 420L180 290L360 460V510H0" fill="#0d1723"/><text x="25" y="460" fill="#fff" font-family="sans-serif" font-size="23">{title.upper()}</text><text x="25" y="486" fill="#{a}" font-family="sans-serif" font-size="11" letter-spacing="4">APERÇU · DONNÉES FICTIVES</text></svg>''',encoding='utf8')
    items.append(dict(title=title,year=2025-i,type='movie',ratingKey=str(i),thumb=QUrl.fromLocalFile(str(path)).toString(),duration=6780000,viewOffset=1420000 if i==0 else 0,viewCount=1 if i==3 else 0,summary='Un voyage inattendu réunit deux inconnus et les conduit à travers des paysages grandioses. Entre rencontres et découvertes, chacun apprend à regarder le monde autrement.'))
if '--real' in sys.argv:
    data=json.loads((OUT/'library.json').read_text(encoding='utf-8'))
    items=data['items']
    service.setProperty('rawLibraries',data['libraries'])
    service.setProperty('section',data['section'])
    service.setProperty('browseTitle',data['section']['title'])
    service.setProperty('total',data['total'])
    service.setProperty('sortIndex',2)
service.setProperty('allItems',items)
service.setProperty('hubs',[{'title':'Continuer à regarder','items':items[:5]},{'title':'Nouveaux ajouts · Films','items':items},{'title':'Nouveaux ajouts · Séries','items':items[3:]}])
service.setProperty('items',items)
QMetaObject.invokeMethod(service,'libraryLoaded')
def capture(name):
    QTest.qWait(700)
    # Force a fresh software frame after asynchronous image/metadata changes.
    w,h=view.width(),view.height()
    view.resize(w+1,h);QTest.qWait(40);view.resize(w,h);QTest.qWait(300)
    image = view.grabWindow()
    assert not image.isNull()
    image.save(str(OUT / (name+'.png')))

def key(k): QTest.keyClick(view,k); QTest.qWait(80)
shell.forceActiveFocus()
# These are remote key sequences against the real QML, not a web mock-up.
capture('bibliotheque')
key(Qt.Key_Right); assert shell.property('itemIndex') == 1
key(Qt.Key_Down); assert shell.property('itemIndex') == 7
key(Qt.Key_Up); assert shell.property('itemIndex') == 1
key(Qt.Key_Left); assert shell.property('itemIndex') == 0
key(Qt.Key_Left); assert shell.property('zone') == 0
capture('navigation')
key(Qt.Key_Right); assert shell.property('zone') == 2
assert shell.property('itemIndex') == 0
key(Qt.Key_Return); assert shell.property('detailOpen')
capture('fiche')
key(Qt.Key_Down);key(Qt.Key_Return);assert shell.property('sheet') == ''
assert shell.property('detailOpen') and shell.property('detailZone') == 1
assert not root.findChild(QObject, 'detailSummary').property('truncated')
key(Qt.Key_Up)
# Every visible action is reachable; skip restart when no offset exists.
while shell.property('detailButton') != 3: key(Qt.Key_Right)
key(Qt.Key_Return);assert shell.property('sheet') == 'info'
key(Qt.Key_Escape);key(Qt.Key_Escape);assert not shell.property('detailOpen')
assert shell.property('itemIndex') == 0
# Trailer actions are keyboard-accessible and return to the unchanged media.
key(Qt.Key_Return)
trailer={'title':'Bande-annonce de test','extraType':1,'Media':[{'container':'mp4','videoCodec':'h264','audioCodec':'aac','Part':[{'key':'/services/iva/assets/fixture/video.mp4'}]}]}
detail=dict(items[0],Extras={'Metadata':[trailer]})
service.setProperty('detail',detail)
key(Qt.Key_Right);key(Qt.Key_Right);key(Qt.Key_Return)
assert service.property('trailerCount') == 1 and shell.property('detailOpen')
detail['Extras']['Metadata'].append(dict(trailer,title='Seconde bande-annonce de test'))
service.setProperty('detail',detail)
key(Qt.Key_Return);assert shell.property('sheet') == 'trailers'
key(Qt.Key_Down);key(Qt.Key_Return);assert service.property('trailerCount') == 2 and not shell.property('sheet')
key(Qt.Key_Escape);assert not shell.property('detailOpen')
service.setProperty('detail',items[0])
key(Qt.Key_Up);assert shell.property('zone') == 1
key(Qt.Key_Return); assert shell.property('dropdown') == 'status'
key(Qt.Key_Down); assert service.property('filterIndex') == 0
key(Qt.Key_Escape); assert service.property('filterIndex') == 0
key(Qt.Key_Return);key(Qt.Key_Down);key(Qt.Key_Return)
assert service.property('filterIndex') == 1 and not shell.property('dropdown')
key(Qt.Key_Right);key(Qt.Key_Return);assert shell.property('dropdown') == 'genre'
capture('genres')
key(Qt.Key_Down);key(Qt.Key_Return);assert service.property('genreTitle') == 'Aventure'
service.setProperty('sortIndex',0)
key(Qt.Key_Right);key(Qt.Key_Return);assert shell.property('dropdown') == 'sort'
key(Qt.Key_Down);key(Qt.Key_Return);assert service.property('sortIndex') == 1
# Dismiss a pending menu. A late network reply must not reopen it.
service.setProperty('genres',[]);service.setProperty('deferGenres',True)
key(Qt.Key_Left);key(Qt.Key_Return);assert shell.property('genrePending')
key(Qt.Key_Escape);QMetaObject.invokeMethod(service,'genresLoaded')
assert not shell.property('dropdown')
service.setProperty('genres',[{'key':'','title':'Tous les genres'},{'key':'1','title':'Aventure'}])
service.setProperty('deferGenres',False)
# Only Library remains; other tabs must not be reachable.
key(Qt.Key_Up);assert shell.property('zone') == 4
key(Qt.Key_Right);assert shell.property('tabIndex') == 0
key(Qt.Key_Return);assert shell.property('dropdown') == 'view'
key(Qt.Key_Return);assert service.property('view') == 1 and not shell.property('dropdown')
key(Qt.Key_Down);key(Qt.Key_Down);assert shell.property('zone') == 2
key(Qt.Key_Escape);assert shell.property('zone') == 0
while shell.property('navIndex') > 1: key(Qt.Key_Up)
key(Qt.Key_Return);assert service.property('home')
capture('accueil')
key(Qt.Key_Up);assert shell.property('zone') == 5
key(Qt.Key_Return);assert service.property('playCount') == 1 and not shell.property('detailOpen')
key(Qt.Key_Right);key(Qt.Key_Return);assert service.property('notice') == 'Ajouté à Ma liste'
service.setProperty('notice','')
key(Qt.Key_Right);key(Qt.Key_Return);assert shell.property('detailOpen')
key(Qt.Key_Escape);key(Qt.Key_Down);assert shell.property('zone') == 2
key(Qt.Key_Right);key(Qt.Key_Down)
assert shell.property('hubIndex') == 1 and shell.property('itemIndex') == 1
for _ in range(7): key(Qt.Key_Right)
assert shell.property('itemIndex') == 8
key(Qt.Key_Return);assert shell.property('detailOpen')
key(Qt.Key_Escape);assert shell.property('hubIndex') == 1 and shell.property('itemIndex') == 8
# Empty Continue Watching still allows moving down to recent additions.
service.setProperty('hubs',[{'title':'Continuer à regarder','items':[]},{'title':'Nouveaux ajouts · Films','items':items}])
QMetaObject.invokeMethod(service,'libraryLoaded')
assert shell.property('zone') == 2
key(Qt.Key_Down);assert shell.property('hubIndex') == 1 and shell.property('itemIndex') == 0
# Watchlist is the very first source, Home the second, Search the third.
key(Qt.Key_Escape)
while shell.property('navIndex') > 0:key(Qt.Key_Up)
key(Qt.Key_Return);assert service.property('watchlist')
assert shell.property('navIndex') == 0
capture('watchlist')
key(Qt.Key_Up);assert shell.property('zone') == 0
key(Qt.Key_Down);key(Qt.Key_Down);key(Qt.Key_Return);assert shell.property('sheet') == 'search'
key(Qt.Key_Return);key(Qt.Key_Right);key(Qt.Key_Return);assert shell.property('searchDraft') == 'AB'
capture('recherche')
for _ in range(3):key(Qt.Key_Down)
for _ in range(8):key(Qt.Key_Right)
assert shell.property('keyboardIndex') == 39
key(Qt.Key_Return);assert service.property('searchText') == 'AB' and not shell.property('sheet')
# Six columns: keep the desired column across an incomplete last row.
service.setProperty('items',items[:8]);service.setProperty('total',8)
QMetaObject.invokeMethod(service,'libraryLoaded');shell.setProperty('zone',2)
for _ in range(5): key(Qt.Key_Right)
assert shell.property('itemIndex') == 5
key(Qt.Key_Right);assert shell.property('itemIndex') == 5
key(Qt.Key_Down);assert shell.property('itemIndex') == 7
key(Qt.Key_Up);assert shell.property('itemIndex') == 5
# Server pagination is separate from visible rows; bounds remain safe.
service.setProperty('total',80)
key(Qt.Key_Down);key(Qt.Key_Down);assert shell.property('zone') == 3
key(Qt.Key_Return);assert service.property('page') == 1 and shell.property('itemIndex') == 0
key(Qt.Key_Down);key(Qt.Key_Down);assert shell.property('pageButton') == 0
key(Qt.Key_Right);assert shell.property('pageButton') == 0
key(Qt.Key_Left);assert shell.property('pageButton') == 2
key(Qt.Key_Return);assert service.property('page') == 0
# Error overlays and logout confirmation never lose the remote focus.
service.setProperty('error','Serveur temporairement indisponible.')
key(Qt.Key_Return);assert not service.property('error')
key(Qt.Key_Menu);assert shell.property('sheet') == 'settings';capture('parametres')
assert root.findChild(QObject,'backdropBlur').property('imageReady'), 'Settings snapshot did not load'
assert service.property('autoSkipIntro') and service.property('autoSkipCredits')
key(Qt.Key_Return);assert not service.property('autoSkipIntro')
key(Qt.Key_Right);assert service.property('autoSkipIntro')
key(Qt.Key_Down);key(Qt.Key_Left);assert not service.property('autoSkipCredits')
key(Qt.Key_Return);assert service.property('autoSkipCredits')
key(Qt.Key_Down);key(Qt.Key_Right);assert service.property('rewindSeconds') == 5
key(Qt.Key_Left);assert service.property('rewindSeconds') == 0
key(Qt.Key_Down);key(Qt.Key_Left);assert service.property('uiScale') == 94
key(Qt.Key_Right);assert service.property('uiScale') == 95
canvas = root.findChild(QObject,'safeCanvas')
assert abs(canvas.property('scale') - .95) < .001
view.resize(1920,1080);QTest.qWait(100)
assert abs(canvas.property('scale') - 1.425) < .001
capture('parametres-1080p');view.resize(1280,720)
key(Qt.Key_Down);key(Qt.Key_Return);assert not service.property('themeMusic')
key(Qt.Key_Return);assert service.property('themeMusic')
key(Qt.Key_Down);key(Qt.Key_Left);assert service.property('themeVolume') == 20
key(Qt.Key_Right);assert service.property('themeVolume') == 25
capture('parametres-musique')
for _ in range(10):key(Qt.Key_Down)
key(Qt.Key_Return);assert not shell.property('sheet')
key(Qt.Key_Menu);assert service.property('uiScale') == 95
key(Qt.Key_Escape)
shell.setProperty('zone',0)
for _ in range(30):key(Qt.Key_Down)
key(Qt.Key_Up);key(Qt.Key_Return);assert shell.property('sheet') == 'account'
capture('compte')
for _ in range(3):key(Qt.Key_Down)
key(Qt.Key_Return);assert shell.property('confirmLogout')
key(Qt.Key_Escape);assert not shell.property('sheet')
service.setProperty('state','auth');capture('connexion')
service.setProperty('code','');service.setProperty('message','Retrouvez vos films et séries sur votre télévision.')
capture('connexion-accueil')
view.resize(1920,1080);capture('connexion-1080p')
key(Qt.Key_Down);key(Qt.Key_Return);assert not service.property('rememberAccount')
key(Qt.Key_Return);assert service.property('rememberAccount')
# Final screenshot retains real library data and neutral filters.
service.setProperty('globalSearch',False);service.setProperty('home',False);service.setProperty('watchlist',False)
service.setProperty('browsePath','');service.setProperty('history',[])
service.setProperty('browseTitle',service.property('section').toVariant().get('title','Bibliothèque'))
service.setProperty('state','library');service.setProperty('view',1);service.setProperty('items',items)
service.setProperty('searchText','');service.setProperty('filterIndex',0);service.setProperty('sortIndex',2 if '--real' in sys.argv else 0);service.setProperty('genreTitle','Tous les genres')
service.setProperty('total',data['total'] if '--real' in sys.argv else len(items))
QMetaObject.invokeMethod(service,'libraryLoaded');shell.setProperty('zone',2)
capture('bibliotheque-1080p')
if '--real' in sys.argv:
    home_data=json.loads((OUT/'home.json').read_text(encoding='utf8'))
    service.setProperty('home',True);service.setProperty('watchlist',False);service.setProperty('view',0);service.setProperty('hubs',home_data);service.setProperty('items',home_data[0]['items']);service.setProperty('browseTitle','Accueil')
    QMetaObject.invokeMethod(service,'libraryLoaded');shell.setProperty('zone',2)
    capture('accueil-1080p');view.resize(1280,720);capture('accueil')
    key(Qt.Key_Menu);capture('parametres');key(Qt.Key_Escape)
    key(Qt.Key_Down);capture('nouveaux-ajouts')
    watch_data=json.loads((OUT/'watchlist.json').read_text(encoding='utf8'))
    service.setProperty('home',False);service.setProperty('watchlist',True);service.setProperty('view',1);service.setProperty('items',watch_data);service.setProperty('total',len(watch_data));service.setProperty('browseTitle','Liste de suivis')
    QMetaObject.invokeMethod(service,'libraryLoaded');shell.setProperty('zone',2)
    capture('watchlist');key(Qt.Key_Escape);capture('navigation')
# Public-release journeys: library view selector, extra settings, profiles and PIN.
service.setProperty('globalSearch',False);service.setProperty('home',False);service.setProperty('watchlist',False)
shell.setProperty('zone',4);shell.setProperty('detailOpen',False);shell.setProperty('sheet','')
key(Qt.Key_Return);key(Qt.Key_Down);key(Qt.Key_Return)
assert service.property('view') == 2
capture('collections')
key(Qt.Key_Return);key(Qt.Key_Up);key(Qt.Key_Return);assert service.property('view') == 1
# The selector exposes both playlists and folders without losing remote focus.
key(Qt.Key_Return);key(Qt.Key_Down);key(Qt.Key_Down);key(Qt.Key_Return)
assert service.property('view') == 3
capture('listes-de-lecture')
key(Qt.Key_Down);key(Qt.Key_Return);assert service.property('browsePath')
key(Qt.Key_Escape);assert not service.property('browsePath') and service.property('view') == 3
shell.setProperty('zone',4);key(Qt.Key_Return);key(Qt.Key_Down);key(Qt.Key_Return)
assert service.property('view') == 5
capture('dossiers')
key(Qt.Key_Down);key(Qt.Key_Return);assert service.property('browsePath')
key(Qt.Key_Escape);assert not service.property('browsePath') and service.property('view') == 5
shell.setProperty('zone',4);key(Qt.Key_Return)
for _ in range(3):key(Qt.Key_Up)
key(Qt.Key_Return);assert service.property('view') == 1
key(Qt.Key_Menu)
for _ in range(6):key(Qt.Key_Down)
key(Qt.Key_Right);assert service.property('audioLanguage') == 'fra'
key(Qt.Key_Down);key(Qt.Key_Right);assert service.property('subtitleLanguage') == 'fra'
key(Qt.Key_Down);key(Qt.Key_Right);assert service.property('subtitlePolicy') == 1
preferences=root.findChild(QObject,'preferenceList')
assert preferences.property('currentIndex') == 8, (shell.property('sheetIndex'),preferences.property('currentIndex'),preferences.property('contentY'))
assert preferences.property('contentY') <= 8*86
assert preferences.property('contentY') + preferences.property('height') >= 9*86
capture('parametres-langues')
for _ in range(3):key(Qt.Key_Down)
key(Qt.Key_Return);assert not service.property('autoNextEpisode')
capture('parametres-enchainement')
key(Qt.Key_Return);assert service.property('autoNextEpisode');key(Qt.Key_Escape)
QMetaObject.invokeMethod(service,'loadProfiles');QTest.qWait(150)
capture('profils')
key(Qt.Key_Down);key(Qt.Key_Return);capture('profil-pin')
for _ in range(4):key(Qt.Key_Return)
for _ in range(3):key(Qt.Key_Down)
key(Qt.Key_Right);key(Qt.Key_Right);key(Qt.Key_Return)
assert service.property('profileError') and service.property('profileId') == '1'
key(Qt.Key_Escape);key(Qt.Key_Up);key(Qt.Key_Return)
assert service.property('state') == 'library' and service.property('profileId') == '1'
QMetaObject.invokeMethod(service,'openLibraries');QTest.qWait(100)
key(Qt.Key_Return);assert len(service.property('pinnedLibraries').toVariant())==2
key(Qt.Key_Menu);key(Qt.Key_Down);key(Qt.Key_Return)
assert service.property('libraryPrefs').toVariant()['mature']
key(Qt.Key_Menu);key(Qt.Key_Down);capture('bibliotheques-confidentialite');key(Qt.Key_Return)
assert service.property('libraryPrefs').toVariant()['adult'] and not service.property('libraryPrefs').toVariant()['mature']
key(Qt.Key_Menu);key(Qt.Key_Up);key(Qt.Key_Up);key(Qt.Key_Return)
key(Qt.Key_Return)
key(Qt.Key_Escape);assert service.property('state')=='library'
key(Qt.Key_Menu)
QTest.qWait(300);assert shell.property('sheet')=='settings'
for _ in range(13):key(Qt.Key_Down)
key(Qt.Key_Return);assert service.property('allowAdultSearch'),shell.property('sheetIndex')
key(Qt.Key_Return);assert not service.property('allowAdultSearch')
capture('parametres-confidentialite')
key(Qt.Key_Escape)
from ui_audit import run as audit_ui
audit_ui(view, root, service, shell, items, capture, key)
view.close()
assert not qml_errors, qml_errors
if '--store' in sys.argv:
    safe_captures = ['accueil.png','bibliotheque-1080p.png','connexion-1080p.png','parametres-1080p.png']
    store_marker.write_text(json.dumps({n:hashlib.sha256((OUT/n).read_bytes()).hexdigest() for n in safe_captures}),encoding='utf8')
print('QML OK: grille 6 colonnes, focus/restauration, onglet Bibliothèque seul, accueil/reprises, Watchlist en tête, rangées, menus OK/annulation, réponse tardive, recherche, pagination, fiche, compte et connexion; 720p/1080p.')
