import functools
import http.server
import importlib.util
import json
from pathlib import Path
import threading
import unittest
import urllib.error
import urllib.request

spec = importlib.util.spec_from_file_location('devialet', Path(__file__).resolve().parents[1] / 'tools/devialet.py')
devialet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(devialet)

class LauncherTests(unittest.TestCase):
    def test_rpc_contract(self):
        request = devialet.payload('192.168.1.2', 8080)
        self.assertEqual(request['method'], 'debug_qml_app')
        self.assertFalse(request['params']['wait'])
        self.assertEqual(request['params']['manifest_url'], 'http://192.168.1.2:8080/manifest.json')

    def test_server_boundaries(self):
        handler = functools.partial(devialet.AppHandler, directory=str(devialet.ROOT / 'app'))
        with http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler) as server:
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f'http://127.0.0.1:{server.server_port}'
            try:
                with urllib.request.urlopen(base + '/manifest.json') as response:
                    manifest = json.load(response)
                with urllib.request.urlopen(base + '/' + manifest['entryPoints']['main']['file']) as response:
                    self.assertIn(b'Application {', response.read())
                with urllib.request.urlopen(base + '/qmldir') as response:
                    components = [line.split()[-1] for line in response.read().decode('utf-8-sig').splitlines() if line.strip()]
                for component in components:
                    with urllib.request.urlopen(base + '/' + component) as response:
                        self.assertTrue(response.read())
                with urllib.request.urlopen(base + '/Plex.js') as response:
                    self.assertTrue(response.read())
                for path in ('/', '/../README.md', '/.local/players.json', '/%2e%2e/.env'):
                    with self.assertRaises(urllib.error.HTTPError) as error:
                        urllib.request.urlopen(base + path)
                    self.assertEqual(error.exception.code, 404)
            finally:
                server.shutdown()
                thread.join()

    def test_remote_launch_rejected(self):
        with self.assertRaises(ValueError):
            devialet.launch('8.8.8.8')

if __name__ == '__main__':
    unittest.main()
