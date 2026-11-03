import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

HELPERS = Path(__file__).resolve().parents[1]/'packaging/integrations'
sys.path.insert(0, str(HELPERS))
import steam_library as steam
import steam_session as session


def appcache(apps, version=0x07564429):
    names = ['appinfo','common','type','steam_release_date','extended','developer']; indices = {s:i for i,s in enumerate(names)}
    def key(kind, name):
        return bytes([kind])+(struct.pack('<I',indices[name]) if version==0x07564429 else name.encode()+b'\0')
    entries = b''
    for app, kind in apps.items():
        data = (key(0,'appinfo')+key(0,'common')+key(1,'type')+kind.encode()+b'\0'
                +key(2,'steam_release_date')+struct.pack('<I',1577836800)+b'\x08'
                +key(0,'extended')+key(1,'developer')+b'Original studio\0'+b'\x08'*3)
        data = bytes(40 if version==0x07564427 else 60)+data
        entries += struct.pack('<II', int(app),len(data))+data
    entries += bytes(4)
    header=struct.pack('<II',version,1)
    if version!=0x07564429:return header+entries
    return header+struct.pack('<Q',16+len(entries))+entries+struct.pack('<I',len(names))+b'\0'.join(n.encode() for n in names)+b'\0'


class LibraryTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name);self.root=self.home/'.local/share/Steam'
        (self.root/'steamapps/common').mkdir(parents=True);(self.root/'appcache').mkdir()
        self.cache=self.root/'appcache/appinfo.vdf'
        self.cache.write_bytes(appcache({'100':'Game','200':'Tool'}))
    def manifest(self, app='100', library=None, flags='4', directory='A game'):
        library=library or self.root
        (library/'steamapps/common'/directory).mkdir(parents=True,exist_ok=True)
        path=library/'steamapps'/f'appmanifest_{app}.acf'
        path.write_text('"AppState" { "appid" "'+app+'" "name" "A game" "StateFlags" "'+flags+'" "installdir" "'+directory+'" }')
        return path
    def test_versions_tools_and_no_steam_writes(self):
        self.manifest();self.manifest('200')
        for version in (0x07564427,0x07564428,0x07564429):
            with self.subTest(version=version):
                self.cache.write_bytes(appcache({'100':'Game','200':'Tool'},version));before=self.cache.read_bytes()
                found=steam.discover(self.home)
                self.assertEqual([g['appId'] for g in found['games']],['100']);self.assertEqual(found['warnings'],[])
                self.assertEqual(found['games'][0]['media']['developer'],'Original studio')
                self.assertEqual(found['games'][0]['media']['releasedate'],'20200101')
                self.assertEqual(before,self.cache.read_bytes())
    def test_move_reconnect_and_duplicate_are_not_enumeration_choices(self):
        original=self.manifest();other=self.home/'second library'
        (self.root/'steamapps/libraryfolders.vdf').write_text('"libraryfolders" { "0" { "path" "'+self.root.as_posix()+'" "contentid" "111" } "1" { "path" "'+other.as_posix()+'" "contentid" "222" } }')
        moved=self.manifest(library=other)
        found=steam.discover(self.home)['games'];self.assertEqual(len(found),1);self.assertFalse(found[0]['available'])
        original.unlink();found=steam.discover(self.home)['games'];self.assertTrue(found[0]['available'])
        self.assertEqual(found[0]['appId'],'100');self.assertEqual(found[0]['libraryId'],'222')
        moved.unlink();self.assertEqual(steam.discover(self.home)['games'],[])
    def test_unfinished_and_missing_content_remain_unavailable(self):
        self.manifest(flags='2');self.assertFalse(steam.discover(self.home)['games'][0]['available'])
        self.manifest();(self.root/'steamapps/common/A game').rmdir()
        self.assertFalse(steam.discover(self.home)['games'][0]['available'])
    def test_bad_metadata_cannot_become_a_launch_target(self):
        path=self.manifest();path.write_text('"AppState" { "appid" "200" }')
        self.assertFalse(steam.discover(self.home)['games']);self.assertTrue(steam.discover(self.home)['warnings'])
        for data in (b'"a" {',b'"a" "x" "a" "y"',b'"a" "unterminated',b'"a" }'):
            with self.assertRaises(ValueError):steam.text_vdf(data)
        self.manifest();self.cache.write_bytes(appcache({'100':'Game'})[:-1])
        self.assertFalse(steam.discover(self.home)['games']);self.assertTrue(steam.discover(self.home)['warnings'])
    def test_path_traversal_and_art_escape(self):
        path=self.manifest();path.write_text(path.read_text().replace('"A game" }','"../outside" }'))
        self.assertFalse(steam.discover(self.home)['games'])

    @unittest.skipUnless(sys.platform.startswith('linux'),'Linux directory links')
    def test_game_moved_to_external_disk_and_disconnected(self):
        manifest=self.manifest();before=manifest.read_bytes()
        original=self.root/'steamapps/common/A game'
        target=self.home/'external-disk/game';target.mkdir(parents=True)
        original.rmdir();original.symlink_to(target,target_is_directory=True)
        found=steam.discover(self.home)
        self.assertEqual(found['warnings'],[])
        self.assertTrue(found['games'][0]['available'])
        self.assertEqual(found['games'][0]['installRoot'],str(target.resolve()))
        target.rmdir()
        found=steam.discover(self.home)
        self.assertEqual(found['warnings'],[])
        self.assertFalse(found['games'][0]['available'])
        self.assertEqual(manifest.read_bytes(),before)


@unittest.skipUnless(sys.platform.startswith('linux'),'Linux process identity')
class SessionTests(unittest.TestCase):
    def test_pid_reuse_preexisting_game_and_descendant_reparenting(self):
        with tempfile.TemporaryDirectory() as temporary:
            proc=Path(temporary)
            def create(pid, token, parent=1, app=None):
                path=proc/str(pid);path.mkdir(exist_ok=True)
                fields=['S',str(parent)]+['0']*17+[str(token)]
                (path/'stat').write_text(f'{pid} (game) '+' '.join(fields))
                (path/'environ').write_bytes(f'SteamAppId={app}\0'.encode() if app else b'')
            create(10,1,app='100');create(11,2,10);create(12,3,app='200');create(13,4,app='100')
            self.assertEqual(session.snapshot('100',{13:'4'},{},proc),{10:'1',11:'2'})
            create(11,2,1);self.assertIn(11,session.snapshot('100',{13:'4'},{11:'2'},proc))
            create(11,5,1);self.assertNotIn(11,session.snapshot('100',{13:'4'},{11:'2'},proc))
    def test_owned_window_requires_live_start_time(self):
        with patch.object(session,'process',side_effect=lambda pid: ('old',1) if pid==10 else ('child',10)):
            self.assertTrue(session.owns_pid(11,{10:'old'}))
            self.assertFalse(session.owns_pid(11,{10:'reused'}))


if __name__=='__main__':unittest.main()
