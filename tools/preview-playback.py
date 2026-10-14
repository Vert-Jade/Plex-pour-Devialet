"""Native QML rendering/navigation of the playback options, no server writes."""
import os
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_BACKEND']='software'
from pathlib import Path
from PySide6.QtCore import QUrl,Qt,QObject,QMetaObject,qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
root_path=Path(__file__).resolve().parents[1]
(root_path/'.local/preview').mkdir(parents=True,exist_ok=True)
errors=[]
def message(kind,context,text):
    if any(t in text for t in ('Error','Cannot assign','Invalid','Binding loop')):errors.append(text);print(text)
qInstallMessageHandler(message)
app=QGuiApplication([]);view=QQuickView();view.setResizeMode(QQuickView.SizeRootObjectToView)
view.setSource(QUrl.fromLocalFile(str(root_path/'tests/preview/PlaybackScene.qml')))
assert view.status()!=QQuickView.Error,[e.toString() for e in view.errors()]
view.resize(1280,720);view.show();root=view.rootObject();panel=root.findChild(QObject,'playbackOptions')
def key(k):QTest.keyClick(view,k);QTest.qWait(100)
def capture(name):
    QTest.qWait(400);view.grabWindow().save(str(root_path/'.local/preview'/name))
capture('options-lecture.png')
key(Qt.Key_Down);key(Qt.Key_Return);assert panel.property('submenu')=='audio'
key(Qt.Key_Down);key(Qt.Key_Return);assert root.property('lastKind')=='audio' and root.property('lastValue')==2
key(Qt.Key_Down);key(Qt.Key_Return);capture('options-sous-titres.png')
key(Qt.Key_Down);key(Qt.Key_Return);assert root.property('lastKind')=='subtitles' and root.property('lastValue')==4
for _ in range(4):key(Qt.Key_Down)
key(Qt.Key_Return);key(Qt.Key_Down);key(Qt.Key_Return);assert root.property('lastKind')=='size' and root.property('lastValue')==125
key(Qt.Key_Escape);assert root.property('closed')
panel.setProperty('row',0);view.resize(1920,1080);capture('options-lecture-1080p.png')
QMetaObject.invokeMethod(root,'addChapters');key(Qt.Key_Return)
assert panel.property('submenu')=='chapter'
key(Qt.Key_Down);key(Qt.Key_Return)
assert root.property('lastKind')=='chapter' and root.property('lastValue')==120000
key(Qt.Key_Return);capture('options-chapitres.png');key(Qt.Key_Escape)
for _ in range(8):key(Qt.Key_Down)
options=root.findChild(QObject,'optionList')
assert options.property('currentIndex')==8 and options.property('contentY')>0
view.close();assert not errors,errors
print('Playback QML OK: audio, sous-titres, taille, retour, focus et rendu 720p/1080p.')
