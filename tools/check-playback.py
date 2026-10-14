"""Temporary native Player check. Credentials stay in RAM; no timeline writes.

Uses a visible library sample from .local/playback-probe-media.json. Restores
Plex's selected tracks afterwards and serves the QA config only to this Player.
"""
import argparse,functools,http.server,ipaddress,json,re,socket,threading,urllib.request,urllib.parse,winreg
from pathlib import Path
import devialet

ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--integration',action='store_true')
    parser.add_argument('--direct',action='store_true',help='Exercise direct playback and its stall recovery in the full application')
    parser.add_argument('--sample',help='Key from .local/codec-samples.json, e.g. video:hevc')
    args=parser.parse_args()
    if args.direct and not args.integration:parser.error('--direct requires --integration')
    player=json.loads((ROOT/'.local/players.json').read_text(encoding='utf8'))[0]
    assert ipaddress.ip_address(player).is_private
    with socket.create_connection((player,80),timeout=4) as connection:local=connection.getsockname()[0]
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER,r'Software\Plex, Inc.\Plex Media Server') as key:token=winreg.QueryValueEx(key,'PlexOnlineToken')[0]
    def request(path,method='GET'):
        req=urllib.request.Request('http://127.0.0.1:32400'+path,method=method,headers={'Accept':'application/json','X-Plex-Token':token})
        with urllib.request.urlopen(req,timeout=15) as response:
            data=response.read();return json.loads(data) if data else {}
    libs=request('/library/sections')['MediaContainer']['Directory']
    libs=[x for x in libs if x['type'] in ('movie','show') and not re.fullmatch(r'(18\+|\+18|18)',re.sub(r'\s','',x['title']))]
    sample=json.loads((ROOT/'.local/codec-samples.json').read_text(encoding='utf8'))[args.sample] if args.sample else None
    seed=sample['media'] if sample else json.loads((ROOT/'.local/playback-probe-media.json').read_text(encoding='utf8'))
    media=request('/library/metadata/'+str(int(seed['ratingKey'])))['MediaContainer']['Metadata'][0]
    assert str(media['librarySectionID']) in {str(x['key']) for x in libs}
    originals=[]
    for m in media['Media']:
        for p in m['Part']:
            streams=p.get('Stream',[])
            originals.append((p['id'],next((x['id'] for x in streams if x['streamType']==2 and x.get('selected')),0),next((x['id'] for x in streams if x['streamType']==3 and x.get('selected')),0)))
    version=0
    if sample:
        for index,variant in enumerate(media['Media']):
            if any(s.get('id')==sample['streamId'] for p in variant['Part'] for s in p.get('Stream',[])):version=index;break
        kind=3 if args.sample.startswith('sub:') else 2 if args.sample.startswith('audio:') else 0
        for stream in media['Media'][version]['Part'][0].get('Stream',[]):
            if stream['streamType']==kind:stream['selected']=stream['id']==sample['streamId']
        print('Sample:',args.sample,'media version:',version,flush=True)
    if args.direct:
        tracks=media['Media'][0]['Part'][0].get('Stream',[])
        audio=[s for s in tracks if s['streamType']==2]
        native=next((s for s in audio if s.get('default')),audio[0])
        for stream in tracks:
            if stream['streamType'] in (2,3):stream['selected']=stream['id']==native['id']
    config=json.dumps({'serverUrl':f'http://{local}:32400','token':token,'libraries':libs,'media':media,'quick':bool(sample),'direct':args.direct,'versionIndex':version,'requireBurn':bool(sample and args.sample.startswith('sub:'))}).encode()
    class Handler(devialet.AppHandler):
        def do_GET(self):
            if self.client_address[0]!=player:self.send_error(403);return
            data=None
            if self.path=='/qa-config.json':data=config
            elif self.path=='/PlaybackCheck.qml':data=(ROOT/'tests/PlaybackCheck.qml').read_bytes()
            elif self.path=='/manifest.json':
                manifest=json.loads((ROOT/'app/manifest.json').read_text(encoding='utf8'))
                if not args.integration:manifest['entryPoints']['main']['file']='PlaybackCheck.qml'
                data=json.dumps(manifest).encode()
            elif self.path=='/main.qml' and args.integration:
                main=(ROOT/'app/main.qml').read_text(encoding='utf8').replace('plex.timeline(','qaTimeline(')
                data=(main[:main.rfind('}')]+(ROOT/'tests/MainPlaybackCheck.inc').read_text(encoding='utf8')+'\n}').encode()
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
                    buffer+=data.decode('utf8',errors='replace')
                    while '\n' in buffer:
                        line,buffer=buffer.split('\n',1)
                        marker=re.search(r'QA_[A-Z_]+[^\r\n]*',line)
                        if marker:
                            clean=re.sub(r'\x1b\[[0-9;]*m','',marker.group());report.append(clean);print(clean,flush=True)
                            if clean.startswith('QA_DONE'):completed.set()
                        elif any(x in line for x in ('TypeError','ReferenceError','is not a type','Cannot assign')):
                            print(re.sub(r'https?://\S+','[URL]',line),flush=True)
                    buffer=buffer[-16384:]
        except OSError:pass
    try:
        with http.server.ThreadingHTTPServer((local,0),functools.partial(Handler,directory=str(ROOT/'app'))) as server:
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            body=devialet.payload(local,server.server_port)
            req=urllib.request.Request(f'http://{player}/pub/devel',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
            with urllib.request.urlopen(req,timeout=12) as response:result=json.load(response)
            assert not result.get('error'),'Player refused QA launch'
            for key in ('stdout_port','stderr_port'):
                if result.get('result',{}).get(key):threading.Thread(target=output,args=(result['result'][key],),daemon=True).start()
            print('Native playback check launched; no history updates.',flush=True)
            completed.wait(260);server.shutdown();thread.join(timeout=3)
    finally:
        for part,audio,subtitle in originals:
            values={'subtitleStreamID':subtitle}
            if audio:values['audioStreamID']=audio
            request('/library/parts/'+str(part)+'?'+urllib.parse.urlencode(values),'PUT')
        suffix='direct' if args.direct else 'integration' if args.integration else args.sample.replace(':','-') if sample else 'session'
        (ROOT/('.local/playback-native-'+suffix+'.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
        print('Original track choices restored.',flush=True)
    assert any('QA_DONE failures=0' in s for s in report), 'Native playback verification incomplete or failed'
if __name__=='__main__':main()
