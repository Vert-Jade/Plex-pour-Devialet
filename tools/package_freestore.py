"""Build a FreeStore candidate (gzip-compressed USTAR, .fbxqml), without publishing.

Format verified against Free's QtCreator plugin, src/freestorepackager.cc.
Only the public application's explicit resource list is packaged.
"""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile

from devialet import APP_FILES, ROOT


def public_files(identifier, app_dir=None):
    if not re.fullmatch(r'[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+', identifier):
        raise ValueError('Identifiant FreeFactory invalide.')
    app_dir = (app_dir or ROOT / 'app').resolve()
    files = {}
    for resource in sorted(APP_FILES):
        name = resource.lstrip('/')
        source = app_dir / name
        if not source.resolve().is_relative_to(app_dir) or source.is_symlink():
            raise ValueError('Ressource hors du dossier public : '+name)
        files[name] = source.read_bytes()
    manifest = json.loads(files['manifest.json'])
    manifest.update(identifier=identifier, name='Plex pour Devialet',
                    description='Client indépendant pour vos films et séries Plex.',
                    icon='assets/app-icon.png')
    entries = manifest.get('entryPoints', {})
    if not entries or sum(bool(e.get('default')) for e in entries.values()) != 1:
        raise ValueError('Un seul point d’entrée par défaut est nécessaire.')
    for entry in entries.values():
        if entry['file'] not in files:
            raise ValueError('Point d’entrée absent du paquet.')
    if manifest['icon'] not in files:
        raise ValueError('Icône absente du paquet.')
    files['manifest.json'] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf8')
    # Never reuse the local launcher's private .local/ui.json configuration.
    if files['AppConfig.js'].decode('utf8').split('var welcomeName = ',1)[1].strip() != '"";':
        raise ValueError('La version publique doit avoir un accueil sans prénom personnel.')
    for name, data in files.items():
        if name.endswith(('.qml','.js','.json')):
            text = data.decode('utf-8-sig')
            if re.search(r'(?i)[A-Z]:[/\\]Users[/\\]|PlexOnlineToken|PRIVATE KEY',text):
                raise ValueError('Donnée locale interdite dans '+name)
    return files


def write_package(destination, identifier, app_dir=None):
    files = public_files(identifier,app_dir)
    destination = Path(destination)
    destination.parent.mkdir(parents=True,exist_ok=True)
    directories = set()
    for name in files:
        directories.update(str(p).replace('\\','/') for p in Path(name).parents if str(p) != '.')
    with destination.open('wb') as output:
        with gzip.GzipFile(fileobj=output,mode='wb',filename='',mtime=0) as compressed:
            with tarfile.open(fileobj=compressed,mode='w',format=tarfile.USTAR_FORMAT) as archive:
                for name in sorted(directories,key=lambda s:(s.count('/'),s)):
                    member=tarfile.TarInfo(name+'/');member.type=tarfile.DIRTYPE;member.mode=0o755
                    archive.addfile(member)
                for name,data in sorted(files.items()):
                    member=tarfile.TarInfo(name);member.size=len(data);member.mode=0o644
                    archive.addfile(member,io.BytesIO(data))
    report = verify_package(destination)
    destination.with_suffix('.sha256').write_text(report['sha256']+'  '+destination.name+'\n',encoding='utf8')
    destination.with_suffix('.verification.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
    return report


def verify_package(path):
    with tarfile.open(path,'r:gz') as archive:
        members=archive.getmembers()
        for m in members:
            if m.name.startswith('/') or '..' in Path(m.name).parts or not (m.isfile() or m.isdir()):
                raise ValueError('Entrée de paquet non sûre.')
            if m.uid or m.gid or m.uname or m.gname:
                raise ValueError('Propriétaire local présent dans le paquet.')
        actual={m.name:archive.extractfile(m).read() for m in members if m.isfile()}
    expected={s.lstrip('/') for s in APP_FILES}
    if set(actual) != expected:
        raise ValueError('La liste des fichiers ne correspond pas aux ressources publiques.')
    manifest=json.loads(actual['manifest.json'])
    return {'file':Path(path).name,'identifier':manifest['identifier'],
            'format':'gzip / USTAR','files':len(actual),'bytes':Path(path).stat().st_size,
            'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            'publication':'not_submitted','freestore_validation':'pending','release_ready':False,
            'resources':{n:hashlib.sha256(b).hexdigest() for n,b in sorted(actual.items())}}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--identifier',required=True,help='Must belong to the actual FreeFactory account prefix')
    parser.add_argument('--version',default='0.5.0-dev')
    args=parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*',args.version):parser.error('Version invalide')
    report=write_package(ROOT/'dist'/('Plex-pour-Devialet-'+args.version+'.fbxqml'),args.identifier)
    print('Paquet construit et relu :',report['file'])
    print('Ressources publiques :',report['files'],'| taille :',report['bytes'],'octets')
    print('SHA-256 :',report['sha256'])
    print('Candidat non déposé. Préfixe à confirmer dans FreeFactory ; acceptation Free non vérifiée.')
