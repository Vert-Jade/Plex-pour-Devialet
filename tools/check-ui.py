"""Exercise real UI components on the Player with fictional data and no credentials."""
import functools
import http.server
import ipaddress
import json
import re
import socket
import threading
import urllib.request
import devialet

ROOT = devialet.ROOT


def main():
    player = json.loads((ROOT/'.local/players.json').read_text(encoding='utf8'))[0]
    assert ipaddress.ip_address(player).is_private
    with socket.create_connection((player, 80), timeout=4) as connection:
        local = connection.getsockname()[0]
    fixture = (ROOT/'tests/preview/Scene.qml').read_text(encoding='utf8').replace('"../../app"', '"."').replace('../../app/', '')
    manifest = json.loads((ROOT/'app/manifest.json').read_text(encoding='utf8'))
    manifest['identifier'] = 'fr.local.plexdevialet.uicheck'
    manifest['entryPoints']['main']['file'] = 'NavigationCheck.qml'
    resources = {'/manifest.json':json.dumps(manifest).encode(), '/NavigationFixture.qml':fixture.encode(), '/NavigationCheck.qml':(ROOT/'tests/NavigationCheck.qml').read_bytes()}
    resources['/qmldir']=(ROOT/'app/qmldir').read_bytes()+b'\nNavigationFixture 1.0 NavigationFixture.qml\n'

    class Handler(devialet.AppHandler):
        def do_GET(self):
            if self.client_address[0] != player:
                self.send_error(403);return
            if self.path in resources:
                data = resources[self.path]
                self.send_response(200);self.send_header('Content-Length', str(len(data)));self.send_header('Cache-Control', 'no-store');self.end_headers();self.wfile.write(data)
            else:
                super().do_GET()

    completed = threading.Event()
    report = []
    def output(port):
        try:
            with socket.create_connection((player, port), timeout=5) as conn:
                conn.settimeout(None)
                buffer = ''
                while not completed.is_set():
                    data = conn.recv(4096)
                    if not data:break
                    buffer += data.decode('utf8', 'replace')
                    while '\n' in buffer:
                        line, buffer = buffer.split('\n', 1)
                        marker = re.search(r'QA_(?:PASS|FAIL|DONE) [A-Za-z0-9_=]+', line)
                        if marker:
                            clean = marker.group();report.append(clean);print(clean, flush=True)
                            if clean.startswith('QA_DONE'):completed.set()
                        elif any(s in line for s in ('Error', 'Cannot assign', 'is not a type', 'Binding loop')):
                            report.append('QA_FAIL native_qml_error')
                            print(re.sub(r'https?://\S+', '[URL]', line), flush=True)
                    buffer = buffer[-16384:]
        except OSError:
            pass

    with http.server.ThreadingHTTPServer((local, 0), functools.partial(Handler, directory=str(ROOT/'app'))) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True);thread.start()
        request = urllib.request.Request(f'http://{player}/pub/devel', data=json.dumps(devialet.payload(local, server.server_port)).encode(), headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(request, timeout=12) as response:
            result = json.load(response)
        assert not result.get('error'), 'Player refused UI checks'
        for key in ('stdout_port', 'stderr_port'):
            if result.get('result', {}).get(key):
                threading.Thread(target=output, args=(result['result'][key],), daemon=True).start()
        print('Native UI checks launched with fictional data.', flush=True)
        completed.wait(45);server.shutdown();thread.join(timeout=3)
    (ROOT/'.local/ui-native.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    assert 'QA_DONE failures=0' in report and not any(s.startswith('QA_FAIL') for s in report), 'Native UI checks failed or incomplete'


if __name__ == '__main__':
    main()
