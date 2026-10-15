"""Freebox developer launcher. Standard library only; no Plex credentials."""
import argparse
import functools
import http.server
import ipaddress
import json
import re
from pathlib import Path
import socket
import subprocess
import threading
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
APP_FILES = {'/manifest.json', '/main.qml', '/qmldir', '/Shell.qml', '/TvButton.qml', '/PlexService.qml', '/Request.qml', '/Plex.js', '/fonts/NotoSans-Regular.ttf', '/fonts/NotoSans-SemiBold.ttf', '/fonts/OFL.txt'}
APP_FILES.add('/assets/plex-logo.svg')
APP_FILES.add('/AppConfig.js')
APP_FILES.update({'/AppInfo.js', '/Brand.qml'})
APP_FILES.add('/RemoteHints.qml')
APP_FILES.update({'/IconButton.qml', '/DetailView.qml'})
APP_FILES.add('/ProfileScreen.qml')
APP_FILES.add('/LibraryScreen.qml')
APP_FILES.add('/assets/app-icon.png')
APP_FILES.add('/PosterCard.qml')
APP_FILES.add('/SettingsPanel.qml')
APP_FILES.add('/assets/login-lounge.png')
APP_FILES.update({'/GlowFrame.qml','/HomeCard.qml','/HomeView.qml','/assets/home-shade.svg'})
APP_FILES.add('/BackdropBlur.qml')
APP_FILES.update({'/Playback.js','/PlaybackSession.qml','/PlaybackOptions.qml'})
APP_FILES.update({'/AuthScreen.qml', '/TvIcon.qml', '/FilterButton.qml', '/DropdownMenu.qml', '/assets/cinema-shade.svg'})


def network_addresses():
    command = "Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | ForEach-Object { $_.IPv4Address.IPAddress }"
    result = subprocess.run(['powershell', '-NoProfile', '-Command', command], capture_output=True, text=True, check=True)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def discover(seconds=4):
    found = set()
    for address in network_addresses():
        found.update(discover_interface(address, seconds))
    return sorted(found)


def discover_interface(address, seconds=4):
    found = set()
    packet = ('M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n'
              'MAN: "ssdp:discover"\r\nMX: 2\r\nST: fbx:devel\r\n\r\n').encode()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind((address, 0))
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(address))
        sock.settimeout(0.5)
        sock.sendto(packet, ('239.255.255.250', 1900))
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                data, peer = sock.recvfrom(65535)
                if b'fbx:devel' in data.lower():
                    found.add(peer[0])
            except socket.timeout:
                pass
    return sorted(found)


def payload(host, port):
    return {'jsonrpc': '2.0', 'id': '1', 'method': 'debug_qml_app',
            'params': {'manifest_url': f'http://{host}:{port}/manifest.json',
                       'entry_point': 'main', 'wait': False}}


class AppHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Serve an explicit list only, never the workspace or local credentials.
        if self.path not in APP_FILES:
            self.send_error(404)
            return
        super().do_GET()

    def do_HEAD(self):
        if self.path not in APP_FILES:
            self.send_error(404)
            return
        super().do_HEAD()

    def log_message(self, *_):
        pass


def launch(player, app_directory=None):
    ip = ipaddress.ip_address(player)
    if ip.version != 4 or not ip.is_private or ip.is_loopback:
        raise ValueError('Le lancement développeur exige une IPv4 du réseau local.')
    with socket.create_connection((str(ip), 80), timeout=4) as connection:
        local = connection.getsockname()[0]
    handler = functools.partial(AppHandler, directory=str(app_directory or ROOT / 'app'))
    with http.server.ThreadingHTTPServer((local, 0), handler) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            body = payload(local, server.server_port)
            request = urllib.request.Request(f'http://{ip}/pub/devel',
                       data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
            with urllib.request.urlopen(request, timeout=12) as response:
                result = json.load(response)
            if result.get('error') or result.get('id') != '1' or result.get('jsonrpc') != '2.0':
                raise RuntimeError('Le Player a refusé le lancement développeur.')
            (ROOT / '.local').mkdir(exist_ok=True)
            (ROOT / '.local' / 'launch.json').write_text(json.dumps(result), encoding='utf-8')
            for stream in ('stdout_port', 'stderr_port'):
                port = result.get('result', {}).get(stream)
                if port:
                    threading.Thread(target=read_player_output, args=(str(ip), port, stream), daemon=True).start()
            print('Lancement accepté par le Player. Vérifiez la télévision. Ctrl+C pour arrêter le serveur de fichiers.', flush=True)
            while True:
                time.sleep(1)
        finally:
            server.shutdown()
            thread.join(timeout=3)


def read_player_output(address, port, stream):
    # Only our explicit diagnostic markers are retained: no URLs or tokens.
    try:
        with socket.create_connection((address, port), timeout=5) as connection:
            connection.settimeout(None)
            buffer = ''
            while True:
                data = connection.recv(4096)
                if not data:
                    print('Flux diagnostic du Player fermé : ' + stream, flush=True)
                    return
                buffer += data.decode('utf-8', errors='replace')
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if 'DEVIALET_APP_READY' in line:
                        print('Application QML chargée sur le Devialet.', flush=True)
                    elif 'DEVIALET_AUTH_READY' in line:
                        print('Code de connexion Plex reçu sur le Devialet.', flush=True)
                    elif 'DEVIALET_AUTH_OK' in line:
                        print('Association Plex réussie sur le Devialet.', flush=True)
                    elif re.search(r'DEVIALET_(SESSION_RESTORED|LIBRARIES_OK|ITEMS_OK|REQUEST_FAILED|PLAYBACK_STARTED|PLAYBACK_ERROR|THEME_STARTED|THEME_UNAVAILABLE|TRANSCODE_READY|DIRECT_READY)', line):
                        print(re.search(r'DEVIALET_[A-Z_]+(?: -?\d+)?', line).group(0), flush=True)
                    elif stream == 'stderr_port':
                        safe = re.sub(r'https?://[^\s]+', '[URL]', line)
                        safe = re.sub(r'(?i)(token|authorization|code)\s*[:=]\s*[^\s,]+', r'\1=[masqué]', safe)
                        print('QML : ' + safe, flush=True)
                buffer = buffer[-16384:]
    except OSError:
        print('Flux diagnostic du Player indisponible : ' + stream, flush=True)


def main():
    parser = argparse.ArgumentParser(description='Détection et lancement du prototype Devialet')
    parser.add_argument('--launch', metavar='IP_PLAYER')
    parser.add_argument('--app-directory',type=Path,help='Serve a previously extracted application package for verification')
    args = parser.parse_args()
    if args.launch:
        launch(args.launch,args.app_directory)
    else:
        players = discover()
        target = ROOT / '.local'
        target.mkdir(exist_ok=True)
        (target / 'players.json').write_text(json.dumps(players), encoding='utf-8')
        print(f'{len(players)} Player(s) développeur détecté(s). Adresses conservées dans .local/players.json.')
        if not players:
            print('Vérifier que le Devialet est allumé et que son mode développeur est actif.')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, ValueError, RuntimeError) as error:
        print(f'Échec : {error}')
        raise SystemExit(1)
