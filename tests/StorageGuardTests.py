"""Exact hardware scope and failed-storage boundaries for the Alpha workaround."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
spec=importlib.util.spec_from_file_location('guard',Path(__file__).resolve().parents[1]/'packaging/session/storage-guard.py')
guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard)
HOST={'kernel':'7.2.6','machine':'aarch64'}
class StorageGuardTests(unittest.TestCase):
    def fixture(self, root):
        for name,data in [('etc/os-release',b'ID=armada\n'),('proc/device-tree/compatible',b'retroidpocket,rpflip2\0qcom,sm8250\0'),('proc/pressure/io',b'some avg10=0.00 avg60=0.00\nfull avg10=0.00 avg60=0.00\n'),(guard.NODE,b'1\n')]:
            p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    def test_exact_host_and_idempotence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);self.fixture(root)
            self.assertTrue(guard.apply(root,**HOST));self.assertFalse(guard.apply(root,**HOST))
            self.assertEqual((root/guard.NODE).read_text(),'0\n')
    def test_other_kernel_device_architecture_and_os_unchanged(self):
        for name,value,host in [('kernel',None,{**HOST,'kernel':'7.2.7'}),('arch',None,{**HOST,'machine':'x86_64'}),('proc/device-tree/compatible',b'ayn,odin2\0',HOST),('etc/os-release',b'ID=other\n',HOST)]:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp);self.fixture(root)
                if value is not None:(root/name).write_bytes(value)
                self.assertFalse(guard.apply(root,**host));self.assertEqual((root/guard.NODE).read_text(),'1\n')
    def test_stalled_storage_refuses_before_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);self.fixture(root);(root/'proc/pressure/io').write_text('some avg10=50.0 avg60=0\n')
            with self.assertRaisesRegex(RuntimeError,'busy or stalled'):guard.apply(root,**HOST)
            self.assertEqual((root/guard.NODE).read_text(),'1\n')
    def test_missing_or_unexpected_control_refuses(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);self.fixture(root);(root/guard.NODE).unlink()
            with self.assertRaisesRegex(RuntimeError,'Cannot verify'):guard.apply(root,**HOST)
            (root/guard.NODE).write_text('unknown')
            with self.assertRaises(RuntimeError):guard.apply(root,**HOST)
if __name__=='__main__':unittest.main()
