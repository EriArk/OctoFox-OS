import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import avatar_resources


class AvatarPackagingTests(unittest.TestCase):
    def test_staged_pack_shape_and_manifest_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'manifest.json').write_text(json.dumps({'patches': [{'file': 'eyes.bin'}]}))
            # Structural fixture only. Authentic bytes/equivalence are checked by the C++ packer.
            resource = b'TAV1' + struct.pack('<I', 3) + b'x' * 64
            for name in ['template.glb.tav', 'eyes.bin.tav']:
                (root / name).write_bytes(resource)
            self.assertEqual(avatar_resources.validate(root), 2)
            (root / 'template.glb').write_bytes(b'glTF')
            with self.assertRaisesRegex(ValueError, 'Loose'):
                avatar_resources.validate(root)
            (root / 'template.glb').unlink()
            (root / 'eyes.bin.tav').unlink()
            with self.assertRaisesRegex(ValueError, 'Missing'):
                avatar_resources.validate(root)

    def test_empty_corrupt_and_oversize_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(ValueError):
                avatar_resources.validate(root)
            (root / 'manifest.json').write_text('{}')
            for resource in [b'glTF', b'TAV1' + struct.pack('<I', 2**32-1) + b'x'*64,
                             b'TAV1' + struct.pack('<I', 16) + b'x'*64]:
                (root / 'template.glb.tav').write_bytes(resource)
                with self.assertRaises(ValueError):
                    avatar_resources.validate(root)


if __name__ == '__main__':
    unittest.main()
