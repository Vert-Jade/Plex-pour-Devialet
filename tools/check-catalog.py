"""Read-only native Devialet catalogue QA. No account switch or history writes.

PMS credentials stay in RAM and are served exclusively to the selected LAN Player.
The isolated QA app identifier never reads or writes the regular app's settings.
"""
import functools,http.server,ipaddress,json,re,socket,threading,urllib.request,winreg
from pathlib import Path
import devialet

ROOT=Path(__file__).resolve().parents[1]
def main():
    player=json.loads((ROOT/'.local/players.json').read_text(encoding='utf8'))[0]
    assert ipaddress.ip_address(player).is_private
    with socket.create_connection((player,80),timeout=4) as connection:local=connection.getsockname()[0]
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER,r'Software\Plex, Inc.\Plex Media Server') as key:token=winreg.QueryValueEx(key,'PlexOnlineToken')[0]
    def get(path):
        req=urllib.request.Request('http://127.0.0.1:32400'+path,headers={'Accept':'application/json','X-Plex-Token':token})
        with urllib.request.urlopen(req,timeout=15) as r:return json.load(r)['MediaContainer']
    libs=get('/library/sections')['Directory']
    libs=[{k:l[k] for k in ('key','title','type')} for l in libs if l['type'] in ('movie','show') and not re.fullmatch(r'(18\+|\+18|18)',re.sub(r'\s','',l['title']))]
    seed=json.loads((ROOT/'.local/playback-probe-media.json').read_text(encoding='utf8'))
    media=get('/library/metadata/'+str(int(seed['ratingKey']))+'?includeChapters=1&includeExtras=1&includeMarkers=1')['Metadata'][0]
    assert str(media['librarySectionID']) in {str(l['key']) for l in libs}
    config=json.dumps({'token':token,'base':f'http://{local}:32400','libraries':libs,'media':media,'query':(media.get('grandparentTitle') or media['title'])[:5]}).encode()
    class Handler(devialet.AppHandler):
        def do_GET(self):
            if self.client_address[0]!=player:self.send_error(403);return
            data=None
            if self.path=='/qa-config.json':data=config
            elif self.path=='/CatalogCheck.qml':data=(ROOT/'tests/CatalogCheck.qml').read_bytes()
            elif self.path=='/Request.qml':
                source=(ROOT/'app/Request.qml').read_text(encoding='utf8')
                source=source.replace('catch (e) { failed(-2); return; }','catch (e) { if(format==="xml")console.log("QA_FAIL xml_parser_"+String(e).replace(/[^A-Za-z0-9_]/g,"_"));failed(-2);return; }')
                data=source.encode()
            elif self.path=='/PlexService.qml':
                source=(ROOT/'app/PlexService.qml').read_text(encoding='utf8')
                source=source.replace('function(){profilesLoading=false;profileError="Les profils Plex sont indisponibles. Réessayez.";}', 'function(status){console.log("QA_FAIL profile_http_"+status);profilesLoading=false;profileError="Les profils Plex sont indisponibles. Réessayez.";}')
                data=source.encode()
            elif self.path=='/manifest.json':
                manifest=json.loads((ROOT/'app/manifest.json').read_text(encoding='utf8'))
                manifest['identifier']='fr.local.plexdevialet.catalogcheck'
                manifest['entryPoints']['main']['file']='CatalogCheck.qml'
                data=json.dumps(manifest).encode()
            if data is not None:
                self.send_response(200);self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data);return
            super().do_GET()
    completed=threading.Event();report=[]
    def output(port):
        try:
            with socket.create_connection((player,port),timeout=5) as conn:
                conn.settimeout(None);buffer=''
                while not completed.is_set():
                    data=conn.recv(4096)
                    if not data:break
                    buffer+=data.decode('utf8','replace')
                    while '\n' in buffer:
                        line,buffer=buffer.split('\n',1)
                        marker=re.search(r'QA_(?:PASS|FAIL|DONE) [A-Za-z0-9_=]+',line)
                        if marker:
                            clean=marker.group();report.append(clean);print(clean,flush=True)
                            if clean.startswith('QA_DONE'):completed.set()
                        elif any(x in line for x in ('TypeError','ReferenceError','is not a type','Cannot assign')):
                            print(re.sub(r'https?://\S+','[URL]',line),flush=True)
                    buffer=buffer[-16384:]
        except OSError:pass
    with http.server.ThreadingHTTPServer((local,0),functools.partial(Handler,directory=str(ROOT/'app'))) as server:
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        req=urllib.request.Request(f'http://{player}/pub/devel',data=json.dumps(devialet.payload(local,server.server_port)).encode(),headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=12) as response:result=json.load(response)
        assert not result.get('error'),'Player refused QA launch'
        for key in ('stdout_port','stderr_port'):
            if result.get('result',{}).get(key):threading.Thread(target=output,args=(result['result'][key],),daemon=True).start()
        print('Native read-only catalogue checks launched.',flush=True)
        completed.wait(110);server.shutdown();thread.join(timeout=3)
    (ROOT/'.local/catalog-native.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    assert any(s=='QA_DONE failures=0' for s in report),'Native catalogue checks failed or incomplete'
if __name__=='__main__':main()
