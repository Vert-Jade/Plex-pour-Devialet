"""Temporary native Player check. Credentials stay in RAM; no timeline writes.

Uses a visible library sample from .local/playback-probe-media.json. Restores
Plex's selected tracks afterwards and serves the QA config only to this Player.
An isolated application identifier preserves the normal app's account/settings.
"""
import argparse,functools,http.server,ipaddress,json,re,socket,threading,time,urllib.request,urllib.parse,winreg
from pathlib import Path
import devialet

ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--integration',action='store_true')
    parser.add_argument('--direct',action='store_true',help='Exercise direct playback and its stall recovery in the full application')
    parser.add_argument('--sample',help='Key from .local/codec-samples.json, e.g. video:hevc')
    parser.add_argument('--audio-language',help='Select an available audio language code for the conversion integration scenario, e.g. eng')
    parser.add_argument('--subtitle-language',help='Select available full subtitles for the conversion integration scenario, e.g. fra')
    parser.add_argument('--soak-seconds',type=int,default=0,help='Observe uninterrupted playback before the integration transitions (0 to 1800 seconds)')
    args=parser.parse_args()
    if args.direct and not args.integration:parser.error('--direct requires --integration')
    if not 0<=args.soak_seconds<=1800:parser.error('--soak-seconds must be between 0 and 1800')
    if args.soak_seconds and not args.integration:parser.error('--soak-seconds requires --integration')
    if args.sample and args.integration:parser.error('--sample cannot be combined with --integration')
    if (args.audio_language or args.subtitle_language) and (not args.integration or args.direct):parser.error('Language selections require --integration without --direct')
    for language in (args.audio_language,args.subtitle_language):
        if language and not re.fullmatch(r'[a-z]{3}',language):parser.error('Use a three-letter Plex language code')
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
    originals=[];history={}
    def remember(item):
        assert str(item['librarySectionID']) in {str(x['key']) for x in libs}
        history[str(item['ratingKey'])]=[item.get(k) for k in ('viewOffset','viewCount','lastViewedAt')]
        for variant in item.get('Media',[]):
            for part in variant.get('Part',[]):
                streams=part.get('Stream',[])
                originals.append((part['id'],next((x['id'] for x in streams if x['streamType']==2 and x.get('selected')),0),next((x['id'] for x in streams if x['streamType']==3 and x.get('selected')),0)))
    remember(media)
    # The full scenario also plays the next episode. Preserve its track choices
    # before any native playback, not just those of the initial sample.
    if args.integration and media.get('type')=='episode':
        offset=0;found=False;following=None
        while following is None:
            path='/library/metadata/'+str(int(media['grandparentRatingKey']))+'/allLeaves?'+urllib.parse.urlencode({'X-Plex-Container-Start':offset,'X-Plex-Container-Size':100})
            container=request(path)['MediaContainer'];rows=container.get('Metadata',[])
            for row in rows:
                if found and row.get('type')=='episode':following=row;break
                if str(row['ratingKey'])==str(media['ratingKey']):found=True
            offset+=len(rows)
            if not rows or offset>=int(container.get('totalSize',0)):break
        assert following is not None,'Integration sample must have a following episode'
        remember(request('/library/metadata/'+str(int(following['ratingKey'])))['MediaContainer']['Metadata'][0])
    def transcodes():
        return {str(row.get('key','')).rsplit('/',1)[-1] for row in request('/transcode/sessions')['MediaContainer'].get('TranscodeSession',[])}
    baseline_sessions=transcodes()
    version=0
    if sample:
        matched=False
        for index,variant in enumerate(media['Media']):
            if any(s.get('id')==sample['streamId'] for p in variant['Part'] for s in p.get('Stream',[])):version=index;matched=True;break
        assert matched,'Codec sample is stale: selected stream no longer exists'
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
    for kind,language in ((2,args.audio_language),(3,args.subtitle_language)):
        if not language:continue
        tracks=media['Media'][0]['Part'][0].get('Stream',[])
        matches=[s for s in tracks if s['streamType']==kind and s.get('languageCode')==language]
        if kind==3:matches=[s for s in matches if not s.get('forced')]
        assert matches,'Requested language is unavailable in this integration sample'
        for stream in tracks:
            if stream['streamType']==kind:stream['selected']=stream['id']==matches[0]['id']
        print('Selected audio' if kind==2 else 'Selected full subtitles',language,flush=True)
    config=json.dumps({'serverUrl':f'http://{local}:32400','token':token,'libraries':libs,'media':media,'quick':bool(sample),'sampleLabel':args.sample or '', 'direct':args.direct,'versionIndex':version,'requireBurn':bool(sample and args.sample.startswith('sub:')),'soakSeconds':args.soak_seconds}).encode()
    class Handler(devialet.AppHandler):
        def do_GET(self):
            if self.client_address[0]!=player:self.send_error(403);return
            data=None
            if self.path=='/qa-config.json':data=config
            elif self.path=='/PlaybackCheck.qml':data=(ROOT/'tests/PlaybackCheck.qml').read_bytes()
            elif self.path=='/manifest.json':
                manifest=json.loads((ROOT/'app/manifest.json').read_text(encoding='utf8'))
                manifest['identifier']='fr.local.plexdevialet.playbackcheck'
                if not args.integration:manifest['entryPoints']['main']['file']='PlaybackCheck.qml'
                data=json.dumps(manifest).encode()
            elif self.path=='/main.qml' and args.integration:
                main=(ROOT/'app/main.qml').read_text(encoding='utf8').replace('plex.timeline(','qaTimeline(')
                main=main.replace('onSourceStopping: {','onSourceStopping: { console.log("QA_DIAG source_stopping");')
                main=main.replace('onSourceReady: {','onSourceReady: { console.log("QA_DIAG source_ready");')
                data=(main[:main.rfind('}')]+(ROOT/'tests/MainPlaybackCheck.inc').read_text(encoding='utf8')+'\n}').encode()
            if data is not None:
                self.send_response(200);self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data);return
            super().do_GET()
    completed=threading.Event();report=[];closed_streams=[]
    def output(port):
        try:
            with socket.create_connection((player,port),timeout=5) as conn:
                conn.settimeout(None);buffer=''
                while not completed.is_set():
                    data=conn.recv(4096)
                    if not data:
                        print('QA_DIAG diagnostic_stream_closed',flush=True);closed_streams.append(port)
                        if len(closed_streams)==2 and not completed.is_set():
                            report.append('QA_FAIL diagnostic_connection_lost');completed.set()
                        break
                    buffer+=data.decode('utf8',errors='replace')
                    while '\n' in buffer:
                        line,buffer=buffer.split('\n',1)
                        marker=re.search(r'QA_[A-Z_]+[^\r\n]*',line)
                        if marker:
                            clean=re.sub(r'\x1b\[[0-9;]*m','',marker.group());report.append(clean);print(clean,flush=True)
                            if clean.startswith('QA_DONE'):completed.set()
                        elif 'DEVIALET_' in line:
                            marker=re.search(r'DEVIALET_[A-Z_]+(?: -?\d+)?',line)
                            if marker:print(marker.group(),flush=True)
                        elif any(x in line for x in ('TypeError','ReferenceError','is not a type','Cannot assign')):
                            print(re.sub(r'https?://\S+','[URL]',line),flush=True)
                    buffer=buffer[-16384:]
        except OSError:
            if not completed.is_set():
                report.append('QA_FAIL diagnostic_transport_error');completed.set()
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
            if not completed.wait(300+args.soak_seconds):report.append('QA_FAIL driver_timeout')
            server.shutdown();thread.join(timeout=3)
    finally:
        cleanup_ok=True
        for part,audio,subtitle in originals:
            values={'subtitleStreamID':subtitle}
            if audio:values['audioStreamID']=audio
            try:request('/library/parts/'+str(part)+'?'+urllib.parse.urlencode(values),'PUT')
            except (OSError,ValueError):cleanup_ok=False
        try:
            unchanged=True
            expected={str(part):(str(audio),str(subtitle)) for part,audio,subtitle in originals}
            for rating_key,before in history.items():
                after=request('/library/metadata/'+rating_key)['MediaContainer']['Metadata'][0]
                unchanged=unchanged and before==[after.get(k) for k in ('viewOffset','viewCount','lastViewedAt')]
                for variant in after.get('Media',[]):
                    for part in variant.get('Part',[]):
                        streams=part.get('Stream',[])
                        selected=tuple(str(next((s['id'] for s in streams if s['streamType']==kind and s.get('selected')),0)) for kind in (2,3))
                        cleanup_ok=cleanup_ok and selected==expected.get(str(part['id']))
            report.append('QA_PASS track_choices_restored' if cleanup_ok else 'QA_FAIL track_restore')
            report.append('QA_PASS playback_history_unchanged' if unchanged else 'QA_FAIL playback_history_changed')
            # Give the app's independent stop transports their bounded lifetime.
            remaining=set()
            for attempt in range(7):
                remaining={s for s in transcodes()-baseline_sessions if s.startswith('devialet-')}
                if not remaining:break
                time.sleep(1)
            report.append('QA_FAIL encoder_session_remaining' if remaining else 'QA_PASS encoder_sessions_released')
        except (OSError,ValueError,KeyError):report.append('QA_FAIL postcheck_unavailable')
        suffix='direct' if args.direct else 'integration' if args.integration else args.sample.replace(':','-') if sample else 'session'
        if args.soak_seconds:suffix+='-soak-'+str(args.soak_seconds)
        if args.audio_language:suffix+='-audio-'+args.audio_language
        if args.subtitle_language:suffix+='-sub-'+args.subtitle_language
        (ROOT/('.local/playback-native-'+suffix+'.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
        for line in report:
            if any(label in line for label in ('track_restore','track_choices_restored','playback_history','encoder_session','postcheck','driver_timeout','diagnostic_transport_error')):print(line,flush=True)
    assert any('QA_DONE failures=0' in s for s in report) and not any(s.startswith('QA_FAIL') for s in report), 'Native playback verification incomplete or failed'
if __name__=='__main__':main()
