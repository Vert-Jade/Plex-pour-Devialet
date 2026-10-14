import sys
from pathlib import Path
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from check_public import issues


class PublicIndexTests(unittest.TestCase):
    def test_private_files_are_never_publishable(self):
        for name in ('.local/session.json','.tools/sdk/file.cpp','.env','dist/app.fbxqml','AGENTS.md'):
            self.assertIn('local-only file',issues(name,b''))

    def test_private_values_and_credentials_are_detected_without_output(self):
        self.assertIn('private local value',issues('README.md',b'Synthetic private fixture',['Synthetic private fixture']))
        self.assertIn('GitHub credential',issues('app/file.js',('gh'+'p_'+'x'*36).encode()))
        self.assertIn('literal Plex token',issues('app/file.js',('X-Plex-'+'Token='+'x'*24).encode()))
        self.assertEqual(issues('app/main.qml',b'property string token: ""'),[])
