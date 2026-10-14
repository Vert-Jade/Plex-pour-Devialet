"""Read local PMS for private visual QA. The token is never saved or printed."""
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import urllib.request, urllib.parse
import winreg
import unicodedata
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'.local'/'preview'
OUT.mkdir(parents=True,exist_ok=True)
key=winreg.OpenKey(winreg.HKEY_CURRENT_USER,r'Software\Plex, Inc.\Plex Media Server')
token=winreg.QueryValueEx(key,'PlexOnlineToken')[0]
def get(path):
    req=urllib.request.Request('http://127.0.0.1:32400'+path,headers={'X-Plex-Token':token,'Accept':'application/json','Accept-Language':'fr','X-Plex-Language':'fr'})
    with urllib.request.urlopen(req,timeout=20) as r:return r.read()
def api(path):return json.loads(get(path))['MediaContainer']
sections=[s for s in api('/library/sections')['Directory'] if s['type'] in ('movie','show')]
movies=[s for s in sections if s['type']=='movie']
section=max(movies,key=lambda s: api('/library/sections/'+s['key']+'/all?X-Plex-Container-Start=0&X-Plex-Container-Size=1').get('totalSize',0))
base='/library/sections/'+section['key']
container=api(base+'/all?sort=addedAt:desc&X-Plex-Container-Start=0&X-Plex-Container-Size=20')
rows=container.get('Metadata',[])
for status in ('unwatched=1','inProgress=1','unwatched=0'):
    result=api(base+'/all?'+status+'&X-Plex-Container-Size=1')
    assert isinstance(result.get('Metadata',[]),list)
    print('Filtre local valide :',status.split('=')[0])
genres=api(base+'/genre').get('Directory',[])
if genres:
    result=api(base+'/all?genre='+urllib.parse.quote(str(genres[0]['key']))+'&X-Plex-Container-Size=1')
    print('Filtre genre local valide')
pivot=api(base+'?includeDetails=1')
print('Metadonnees de section accessibles. Genres :',len(genres))
for route in ['/hubs?count=2','/hubs/sections/'+section['key']+'?count=2',base+'/collections','/playlists?playlistType=video&sectionID='+section['key'],base+'/all?title=Mask&X-Plex-Container-Size=1']:
    api(route)
print('Accueil, recommandations, collections, listes et recherche : reponses locales valides')

def download(pair):
    i,item=pair[:2]
    prefix=pair[2] if len(pair)>2 else ""
    if i == 0 and not item.get("cloudOnly"): item=dict(item,**api('/library/metadata/'+str(item['ratingKey']))['Metadata'][0])
    result={k:item[k] for k in ('title','year','type','ratingKey','duration','summary','viewOffset','viewCount','contentRating','grandparentTitle','parentTitle','parentIndex','index','librarySectionID','cloudOnly','guid') if k in item}
    for field in ('Genre','Role'):
        result[field]=[{'tag':r['tag']} for r in item.get(field,[]) if r.get('tag')]
    result['Media']=[{k:m[k] for k in ('videoResolution','videoCodec','audioCodec','audioChannels','container','bitrate') if k in m} for m in item.get('Media',[])]
    for field,w,h in [('thumb',360,540),('art',1280,720),('grandparentThumb',360,540),('parentThumb',360,540)]:
        if not item.get(field): continue
        path=OUT/f'real-{prefix}{i}-{field}.jpg'
        params=urllib.parse.urlencode({'url':item[field],'width':w,'height':h,'minSize':1,'upscale':1})
        try:
            if item[field].startswith('https://'):
                remote=item[field].replace('/t/p/original/','/t/p/'+('w1280' if w>600 else 'w342')+'/')
                image=urllib.request.urlopen(urllib.request.Request(remote,headers={'User-Agent':'DevialetCinemaPreview'}),timeout=20).read()
            else: image=get('/photo/:/transcode?'+params)
            path.write_bytes(image); result[field]=path.as_uri()
        except Exception: pass
    return result
with ThreadPoolExecutor(max_workers=5) as pool:items=list(pool.map(download,enumerate(rows)))
(OUT/'library.json').write_text(json.dumps({'items':items,'libraries':[{'key':s['key'],'type':s['type'],'title':s['title']} for s in sections],'section':{'key':section['key'],'type':section['type'],'title':section['title']},'total':container.get('totalSize',len(rows))},ensure_ascii=False),encoding='utf8')
print('Affiches et donnees reelles disponibles pour la previsualisation locale :',len(items))

# Private read-only snapshots of the family home and the real account Watchlist.
visible=sorted([s for s in sections if ''.join(s['title'].split()) not in ('18+','+18','18')],key=lambda s: ''.join(c for c in unicodedata.normalize('NFD',s['title'].casefold()) if not unicodedata.combining(c)))
allowed={str(s['key']) for s in visible}
continue_rows=api('/hubs/continueWatching?count=20').get('Hub',[{}])[0].get('Metadata',[])
continue_rows=[m for m in continue_rows if str(m.get('librarySectionID')) in allowed]
home=[{'title':'Continuer à regarder','items':continue_rows[:12]}]
checked=0
for lib in visible:
    box=api('/hubs/sections/'+lib['key']+'?count=12')
    checked+=1
    rows=next((h.get('Metadata',[]) for h in box.get('Hub',[]) if '.recentlyadded.' in h.get('hubIdentifier','')),[])
    if rows and len(home)<4: home.append({'title':'Nouveaux ajouts · '+lib['title'],'items':rows})
for n,row in enumerate(home):
    with ThreadPoolExecutor(max_workers=5) as pool: row['items']=list(pool.map(download,[(i,m,'home-'+str(n)+'-') for i,m in enumerate(row['items'])]))
(OUT/'home.json').write_text(json.dumps(home,ensure_ascii=False),encoding='utf8')
req=urllib.request.Request('https://discover.provider.plex.tv/library/sections/watchlist/all?X-Plex-Container-Start=0&X-Plex-Container-Size=40&sort=watchlistedAt:desc',headers={'Accept':'application/json','X-Plex-Token':token,'Accept-Language':'fr'})
remote=json.load(urllib.request.urlopen(req,timeout=20))['MediaContainer']
rows=remote.get('Metadata',[])
guids=','.join(r['guid'] for r in rows if r.get('guid'))
found=api('/library/all?'+urllib.parse.urlencode({'guid':guids,'X-Plex-Container-Size':10000})).get('Metadata',[]) if guids else []
watchlist=[]
for row in rows:
    matches=[m for m in found if m.get('guid')==row.get('guid')]
    available=[m for m in matches if str(m.get('librarySectionID')) in allowed]
    if matches and not available: continue
    watchlist.append(dict(available[0] if available else row,cloudOnly=not bool(available)))
with ThreadPoolExecutor(max_workers=5) as pool: watchlist=list(pool.map(download,[(i,m,'watch-') for i,m in enumerate(watchlist)]))
(OUT/'watchlist.json').write_text(json.dumps(watchlist,ensure_ascii=False),encoding='utf8')
print('Accueil : reprises et',checked,'bibliotheques visibles verifiees. Watchlist privee :',len(watchlist),'titres sur la premiere page.')
