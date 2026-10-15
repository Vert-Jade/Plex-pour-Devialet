"""Additional regression journeys on the rendered production QML, using fictional data."""
from PySide6.QtCore import QObject, QPointF, Qt, QMetaObject
from PySide6.QtTest import QTest


def run(view, root, service, shell, items, capture, key):
    def invoke(obj, method):
        assert QMetaObject.invokeMethod(obj, method)
        QTest.qWait(180)

    def children(item):
        yield item
        for child in item.childItems():
            yield from children(child)

    def glows():
        found = []
        for item in children(shell):
            if item.objectName() != 'focusGlow' or not item.isVisible():
                continue
            point = QPointF(item.width()/2, item.height()/2)
            parent = item.parentItem()
            visible = True
            while parent:
                mapped = item.mapToItem(parent, point)
                if parent.opacity() == 0 or (parent.clip() and not (0 <= mapped.x() <= parent.width() and 0 <= mapped.y() <= parent.height())):
                    visible = False
                parent = parent.parentItem()
            if visible:
                found.append(item)
        return found

    def one_focus(label):
        QTest.qWait(180)
        found = glows()
        assert len(found) == 1, (label, len(found), shell.property('zone'), shell.property('sheet'))

    def bounds(item, left=0, right=1280):
        point = item.mapToItem(shell, QPointF(0, 0))
        assert point.x() >= left-1 and point.x()+item.width() <= right+1, (item.objectName(), point.x(), item.width(), left, right)

    sidebar = root.findChild(QObject, 'sidebar')
    original_libs = service.property('rawLibraries').toVariant()
    original_prefs = service.property('libraryPrefs').toVariant()
    service.setProperty('state', 'library')
    service.setProperty('browsePath', '')
    service.setProperty('history', [])
    service.setProperty('allItems', items)
    populated = [{'title':'Continuer à regarder','items':items}, {'title':'Nouveaux ajouts · Films','items':items}]
    for size in [(1280, 720), (1920, 1080)]:
        view.resize(*size)
        for scale in [90, 95, 100]:
            service.setProperty('uiScale', scale)
            service.setProperty('hubs', populated)
            shell.setProperty('zone', 2)
            invoke(service, 'showHome')
            one_focus('Home card')
            assert sidebar.width() == 64
            key(Qt.Key_Up); one_focus('Home play')
            key(Qt.Key_Down); key(Qt.Key_Escape); one_focus('Home sidebar')
            assert sidebar.width() == 280
            key(Qt.Key_Down); chosen = shell.property('navIndex')
            invoke(service, 'libraryLoaded')
            assert shell.property('navIndex') == chosen, 'A late reply moved sidebar focus'
            key(Qt.Key_Right); one_focus('Home collapsed again')
            assert sidebar.width() == 64
            service.setProperty('hubs', [])
            service.setProperty('homeNotice', 'Épinglez vos bibliothèques depuis Mes bibliothèques pour personnaliser l’accueil.')
            shell.setProperty('zone', 2); invoke(service, 'libraryLoaded')
            one_focus('Empty home action')
            key(Qt.Key_Escape); one_focus('Empty home sidebar')
            text = root.findChild(QObject, 'homeEmptyText')
            bounds(text, 312, 1240)
            assert text.property('lineCount') >= 2 and not text.property('truncated')
            if scale == 95:
                capture('accueil-vide-'+str(size[0]))
            key(Qt.Key_Right);key(Qt.Key_Return)
            assert service.property('state') == 'libraries'
            key(Qt.Key_Escape)
    service.setProperty('homeNotice', '')
    service.setProperty('uiScale', 95);view.resize(1280, 720)
    service.setProperty('view', 1);service.setProperty('home', False)
    service.setProperty('watchlist', False);service.setProperty('globalSearch', False)
    service.setProperty('items', items);service.setProperty('total', len(items))
    shell.setProperty('zone', 2);invoke(service, 'libraryLoaded')
    key(Qt.Key_Escape);one_focus('Library sidebar')
    bounds(root.findChild(QObject, 'posterGrid'), 280)
    bounds(root.findChild(QObject, 'pageControls'), 280)
    service.setProperty('busy', True)
    shell.setProperty('navIndex', 1);key(Qt.Key_Return)
    assert service.property('home'), 'A slow request prevented leaving the library'
    service.setProperty('busy', False)
    key(Qt.Key_Escape);shell.setProperty('navIndex', 3);key(Qt.Key_Return)
    key(Qt.Key_Escape)
    key(Qt.Key_Right);key(Qt.Key_Up);key(Qt.Key_Right);key(Qt.Key_Right)
    for index in range(12):
        key(Qt.Key_Return)
        assert shell.property('dropdown') == 'sort'
        for _ in range(12):key(Qt.Key_Up)
        for _ in range(index):key(Qt.Key_Down)
        one_focus('Sort '+str(index))
        if index in (7, 11):capture('tri-'+str(index))
        key(Qt.Key_Return);assert service.property('sortIndex') == index
        one_focus('Applied sort')
    # Modal focus is exclusive, even when an error interrupts another panel.
    key(Qt.Key_Menu);one_focus('Settings over filter')
    service.setProperty('error', 'Le serveur ne répond pas.')
    one_focus('Error over settings')
    key(Qt.Key_Return);one_focus('Retry returns to settings');key(Qt.Key_Escape)
    # Explicitly exercise a detail with more actors/extras than fit on one row.
    shell.setProperty('zone', 2);key(Qt.Key_Return)
    extra = {'title':'Dans les coulisses','duration':180000,'extraType':2,'thumb':items[0]['thumb'],'Media':[{'Part':[{'key':'/library/parts/fixture/file.mp4'}]}]}
    detail = dict(items[0], Role=[{'id':str(i),'tag':'Interprète '+str(i+1),'role':'Personnage '+str(i+1)} for i in range(14)], Extras={'Metadata':[dict(extra,extraType=1,title='Bande-annonce')]+[dict(extra,title='Bonus '+str(i+1)) for i in range(9)]})
    service.setProperty('detail', detail);QTest.qWait(200)
    key(Qt.Key_Right);key(Qt.Key_Right)
    assert shell.property('detailButton') == 5
    one_focus('Trailer reel');capture('fiche-actions')
    previous = service.property('trailerCount');key(Qt.Key_Return)
    assert service.property('trailerCount') == previous+1
    key(Qt.Key_Down);one_focus('Full synopsis')
    key(Qt.Key_Down);one_focus('Cast')
    for _ in range(13):key(Qt.Key_Right)
    one_focus('Last cast member');capture('fiche-distribution')
    assert shell.property('detailSecondary') == 13
    key(Qt.Key_Return)
    assert not shell.property('detailOpen') and service.property('lastActor') == 13
    key(Qt.Key_Escape)
    assert shell.property('detailOpen') and shell.property('detailZone') == 2 and shell.property('detailSecondary') == 13
    one_focus('Return to original cast selection')
    key(Qt.Key_Down);one_focus('Bonus row')
    for _ in range(8):key(Qt.Key_Right)
    one_focus('Last bonus');capture('fiche-bonus')
    key(Qt.Key_Return);assert service.property('lastExtra') == 9
    key(Qt.Key_Up);key(Qt.Key_Up);key(Qt.Key_Up);one_focus('Back to detail actions')
    service.setProperty('error', 'Le fichier est momentanément inaccessible.')
    one_focus('Error over detail');key(Qt.Key_Escape);key(Qt.Key_Escape)
    # No unavailable action can become selected at a pagination boundary.
    service.setProperty('total', 120);service.setProperty('page', 2)
    shell.setProperty('zone', 2);invoke(service, 'libraryLoaded')
    key(Qt.Key_Down);key(Qt.Key_Down)
    assert shell.property('zone') == 3 and shell.property('pageButton') == 0
    key(Qt.Key_Right);assert shell.property('pageButton') == 0
    key(Qt.Key_Left);assert shell.property('pageButton') == 2
    one_focus('First page action');capture('pagination')
    key(Qt.Key_Return);assert service.property('page') == 0
    # Sidebar scrolling must expose its last action with a large library list.
    libraries = [{'key':str(i+1),'title':'Bibliothèque '+str(i+1),'type':'movie'} for i in range(24)]
    service.setProperty('rawLibraries', libraries)
    service.setProperty('libraryPrefs', {'pinned':[l['key'] for l in libraries], 'adult':[], 'mature':[]})
    shell.setProperty('zone', 2);key(Qt.Key_Escape)
    for _ in range(32):key(Qt.Key_Down)
    one_focus('Last sidebar action');key(Qt.Key_Return)
    assert shell.property('sheet') == 'settings'
    key(Qt.Key_Escape)
    service.setProperty('rawLibraries', original_libs);service.setProperty('libraryPrefs', original_prefs)
    service.setProperty('page', 0);service.setProperty('sortIndex', 0)
    service.setProperty('total', len(items));service.setProperty('detail', items[0])
    shell.setProperty('zone', 2)
    assert not service.property('error')
    print('UI AUDIT OK: focus unique, accueil vide, sidebar, tris 12/12, erreurs, distribution/bonus, pagination, 24 bibliothèques; 720p/1080p à 90/95/100 %.')
