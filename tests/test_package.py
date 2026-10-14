import gzip
import importlib.util
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import package_freestore as package


class FreeStorePackageTests(unittest.TestCase):
    def test_public_package_is_complete_reproducible_and_private_data_free(self):
        with tempfile.TemporaryDirectory() as temp:
            first=Path(temp)/'one.fbxqml';second=Path(temp)/'two.fbxqml'
            a=package.write_package(first,'fr.example.cinema')
            b=package.write_package(second,'fr.example.cinema')
            self.assertEqual(a['sha256'],b['sha256'])
            self.assertEqual(gzip.decompress(first.read_bytes())[257:263],b'ustar\0')
            with tarfile.open(first,'r:gz') as archive:
                names=archive.getnames()
                manifest=json.load(archive.extractfile('manifest.json'))
                self.assertEqual(manifest['identifier'],'fr.example.cinema')
                self.assertIn(manifest['entryPoints']['main']['file'],names)
                self.assertIn(manifest['icon'],names)
                self.assertFalse(any('.local' in n or '.tools' in n or n.startswith('tests/') for n in names))
                for m in archive.getmembers():
                    self.assertFalse(m.issym() or m.islnk())
                    if m.isfile() and m.name.endswith(('.js','.qml','.json')):
                        data=archive.extractfile(m).read()
                        self.assertNotIn(b'PlexOnlineToken',data)

    def test_invalid_public_identifiers_are_rejected(self):
        for name in ('../private','fr.example/other','single','fr.example?token=oops',''):
            with self.subTest(name=name),self.assertRaises(ValueError):
                package.public_files(name)

    def test_local_greeting_is_never_part_of_default_http_resources(self):
        text=(ROOT/'app/AppConfig.js').read_text(encoding='utf8')
        self.assertIn('var welcomeName = "";',text)


if __name__=='__main__':unittest.main()
