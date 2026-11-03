import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import screenscraper_client as client


class ClientPackagingTests(unittest.TestCase):
    def test_only_application_identity_enters_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'client.json'
            identity = {'version': 1, 'developerId': 'fixture', 'developerPassword': 'fixture-only'}
            source.write_text(json.dumps(identity), encoding='utf-8')
            client.stage(source, root / 'payload')
            self.assertEqual(client.read(root / 'payload' / client.RELATIVE_PATH), identity)
            with self.assertRaises(ValueError): client.stage(source, root / 'payload')

    def test_personal_fields_and_invalid_keys_fail_before_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'client.json'
            good = {'version': 1, 'developerId': 'fixture', 'developerPassword': 'fixture-only'}
            invalid = [dict(good, username='player', password='personal'), dict(good, username=''),
                       dict(good, version=True), dict(good, developerId=''),
                       dict(good, developerPassword='\0'), dict(good, developerId=3), []]
            for record in invalid:
                source.write_text(json.dumps(record), encoding='utf-8')
                with self.subTest(record=record), self.assertRaises(ValueError):
                    client.stage(source, root / 'payload')
                self.assertFalse((root / 'payload').exists())
            source.write_text('{"version":1,"version":1}', encoding='utf-8')
            with self.assertRaises(ValueError): client.read(source)
            source.write_text('x' * 8193, encoding='utf-8')
            with self.assertRaises(ValueError): client.read(source)


if __name__ == '__main__': unittest.main()
