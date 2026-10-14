"""Render the existing vector wordmark as an app icon; copy fictional QA captures."""
import os
os.environ['QT_QPA_PLATFORM']='offscreen'
from pathlib import Path
import shutil
import hashlib
import json
from PySide6.QtCore import QRectF
from PySide6.QtGui import QGuiApplication,QImage,QPainter,QColor
from PySide6.QtSvg import QSvgRenderer

ROOT=Path(__file__).resolve().parents[1]
app=QGuiApplication([])
icon=QImage(512,512,QImage.Format_ARGB32)
icon.fill(QColor('#080808'))
renderer=QSvgRenderer(str(ROOT/'app/assets/plex-logo.svg'))
assert renderer.isValid()
painter=QPainter(icon)
size=renderer.defaultSize()
width=394;height=width*size.height()/size.width()
renderer.render(painter,QRectF((512-width)/2,(512-height)/2,width,height))
painter.end()
assert icon.save(str(ROOT/'app/assets/app-icon.png'))
target=ROOT/'distribution/images';target.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'app/assets/app-icon.png',target/'icone-512.png')
preview=ROOT/'.local/preview'
# Only run this after preview.py --store. Its marker is written on successful QA.
assert (preview/'store-captures-ok.txt').is_file(),'Run preview.py --store first.'
approved=json.loads((preview/'store-captures-ok.txt').read_text(encoding='utf8'))
for source,destination in [('accueil.png','accueil-demo.png'),('bibliotheque-1080p.png','bibliotheque-demo.png'),('connexion-1080p.png','connexion.png'),('parametres-1080p.png','parametres-demo.png')]:
    assert hashlib.sha256((preview/source).read_bytes()).hexdigest()==approved[source],'Preview changed since fictional-data QA.'
    shutil.copy2(preview/source,target/destination)
print('Icône 512 px et 4 captures publiques de démonstration préparées.')
