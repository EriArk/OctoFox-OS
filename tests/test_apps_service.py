"""Application lifecycle checks without a real user's windows or controller."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import types

# These tests fake X11, /proc and leases. Importing their definitions on the
# Windows build host does not claim Linux input/process acceptance.
if sys.platform == 'win32':
    sys.modules.setdefault('fcntl', types.ModuleType('fcntl'))

source=Path(__file__).resolve().parents[1]/'packaging/integrations'
sys.path.insert(0,str(source))
spec=importlib.util.spec_from_file_location('apps_service',source/'apps-service.py')
apps=importlib.util.module_from_spec(spec);spec.loader.exec_module(apps)


class X:
    def active(self):return 11
    def atom(self,name):return 1
    def prop(self,*_):return [1]
    def owns(self,w,pid,start):return w==12 and pid==80 and start=='root'
class Windows:
    def __init__(self):self.x=X();self.live={};self.mapped=[];self.closed=[]
    def all(self):return self.live
    def map(self,rows,visible):self.mapped.append((list(rows),visible))
    def close(self,window,row):self.closed.append(window);return True

def window(pid=90,start='100',transient=0,mapped=True):
    return dict(pid=pid,start=start,transient=transient,mapped=mapped,classes=['test'])


class Lifecycle(unittest.TestCase):
    def test_steam_shortcuts_identify_game_without_executing_desktop_text(self):
        for command,expected in [('steam steam://rungameid/588650','steam:588650'),
            ('/usr/bin/flatpak run com.valvesoftware.Steam steam://run/42','steam:42'),
            ('firefox steam://run/42',''),('sh -c "steam steam://run/42"',''),
            ('steam steam://rungameid/0',''),('steam steam://run/42;anything',''),('steam "','')]:
            self.assertEqual(apps.steam_game_id(types.SimpleNamespace(get_commandline=lambda:command)),expected)

    @patch.object(apps,'emit')
    def test_native_minimize_returns_to_shell_and_remains_resumable(self,emit):
        s=self.service();s.windows.live={11:window(mapped=False)}
        with patch.object(apps.time,'monotonic',return_value=10) as clock:
            s.scan();self.assertEqual(s.current,'a')
            clock.return_value=10.4;s.scan();self.assertEqual(s.current,'')
        emit.assert_any_call('shell');self.assertTrue(s.sessions['a']['windows'][11]['restore'])
        s.command({'command':'launch','id':'a'});self.assertEqual(s.current,'a')
        self.assertEqual(s.windows.mapped[-1],([11],True))

    @patch.object(apps,'emit')
    def test_minimize_preserves_app_hidden_windows_and_captures_new_dialog(self,emit):
        s=self.service();s.windows.live={11:window(mapped=False),12:window(transient=11)}
        s.command({'command':'minimize'})
        self.assertFalse(s.sessions['a']['windows'][11]['restore'])
        self.assertTrue(s.sessions['a']['windows'][12]['restore'])
        self.assertEqual(set(s.windows.mapped[-1][0]),{11,12})

    @patch.object(apps,'emit')
    def test_replacement_window_is_journaled_without_app_state_change(self,emit):
        s=self.service();s.windows.live={11:window()}
        with patch.object(s,'save_sessions') as save:
            s.scan();save.reset_mock();emit.reset_mock()
            s.windows.live={12:window()};s.scan()
            save.assert_called_once();emit.assert_not_called()
            self.assertEqual(set(s.sessions['a']['windows']),{12})

    def test_restore_maps_parent_then_dialog_without_unhiding_app_windows(self):
        calls=[];windows=apps.Windows.__new__(apps.Windows)
        windows.valid=lambda *args:True
        windows.x=types.SimpleNamespace(display=None,x=types.SimpleNamespace(
            XMapWindow=lambda d,w:calls.append(('map',w)),XRaiseWindow=lambda d,w:calls.append(('raise',w)),
            XUnmapWindow=lambda d,w:calls.append(('hide',w)),XFlush=lambda d:None))
        windows.map({12:window(transient=11),13:dict(window(),restore=False),11:window()},True)
        self.assertEqual(calls,[('map',11),('raise',11),('map',12),('raise',12)])

    @patch.object(apps,'emit')
    def test_explicit_url_reuses_only_observed_browser_identity(self,emit):
        for reuse,changed,expected in [(True,False,True),(False,False,False),(True,True,False)]:
            s=self.service();s.sessions={};s.current='';s.apps={'browser':(None,{'id':'browser','startupClass':'test'})}
            s.windows.live={11:window(start='200' if changed else '100')}
            s.pending=('browser',{11:window()},[],apps.time.monotonic()+20,reuse)
            s.scan();self.assertEqual('browser' in s.sessions,expected)
            if expected:
                self.assertEqual(s.current,'browser');s.command({'command':'minimize'})
                self.assertEqual(s.current,'');self.assertEqual(s.windows.mapped[-1],([11],False))
    @patch.object(apps,'emit')
    @patch.object(apps,'identity',return_value='root')
    def test_setup_accepts_shell_child_but_rejects_unrelated_native_process(self,identity,emit):
        for parent,accepted in [(123,True),(999,False)]:
            s=self.service();s.apps={};s.sessions={};s.current=''
            with patch.object(apps.os,'getppid',return_value=123), \
                 patch.object(apps.Path,'stat',return_value=types.SimpleNamespace(st_uid=apps.os.getuid())), \
                 patch.object(apps.Path,'read_bytes',return_value=b'/usr/bin/env\0APPDIR=/runtime\0'), \
                 patch.object(apps.Path,'read_text',return_value=f'80 (setup ) title) S {parent} 0 0'):
                if not accepted:
                    with self.assertRaises(ValueError):s.command({'command':'watch-installer','pid':80})
                    self.assertFalse(s.sessions)
                else:
                    s.command({'command':'watch-installer','pid':80,'title':'Vita setup'})
                    self.assertEqual(s.sessions['traineros-pc-installer']['root'],(80,'root'))
                    self.assertEqual(s.current,'traineros-pc-installer')
                    s.command({'command':'finish-installer'})
                    self.assertFalse(s.sessions);self.assertEqual(s.current,'')

    def test_composite_sources_ignore_non_evdev_and_disconnected_members(self):
        from overlay_support import gamepad_sources
        def name(path):
            names={'event3':'gpio-keys-paddles', 'event4':'AYN Odin2 Gamepad', 'event5':'Retroid Pocket Gamepad'}
            if path.parts[-3] not in names:raise FileNotFoundError
            return names[path.parts[-3]]
        with patch.object(apps.Path,'read_text',name):
            self.assertEqual(gamepad_sources(['/dev/fastrpc-adsp','/dev/input/event3','/dev/input/event4','/dev/input/event99']),['/dev/input/event4'])
            self.assertEqual(gamepad_sources(['/dev/input/event4','/dev/input/event5']),['/dev/input/event4','/dev/input/event5'])
            self.assertEqual(gamepad_sources(['/tmp/event4','/dev/input/mouse0']),[])

    def test_browser_identity_uses_desktop_class_or_flatpak_application_id(self):
        self.assertTrue(apps.browser_identity('org.mozilla.firefox.desktop',dict(pid=90,classes=['Navigator','Org.mozilla.firefox'])))
        with patch.object(apps.Path,'read_text',return_value='[Application]\nname=org.mozilla.firefox\n'):
            self.assertTrue(apps.browser_identity('org.mozilla.firefox.desktop',dict(pid=90,classes=['Navigator','firefox'])))
            self.assertFalse(apps.browser_identity('another.desktop',dict(pid=90,classes=['Navigator','firefox'])))
        with patch.object(apps.Path,'read_text',side_effect=OSError):
            self.assertFalse(apps.browser_identity('org.mozilla.firefox.desktop',dict(pid=90,classes=['Other'])))
    def test_browser_url_rejects_file_plain_http_and_credentials(self):
        s=self.service()
        for uri in ['file:///tmp/app.desktop','http://example.com','https://user:secret@example.com','https:///missing']:
            with self.assertRaises(ValueError):s.command({'command':'open-url','url':uri})
    @patch.object(apps,'emit')
    def test_open_file_restores_owned_single_instance_window(self,emit):
        for mapped in (False,True):
            s=self.service();s.current='';s.windows.live={11:window(mapped=mapped)}
            class Context:
                def setenv(self,*args):pass
                def unsetenv(self,*args):pass
            class Handler:
                uris=[]
                def get_id(self):return 'a'
                def launch_uris_as_manager(self,uris,*args):self.uris=uris
            handler=Handler()
            s.apps={'a':(handler,dict(id='a',name='Test',startupClass='test'))}
            s.Gio=types.SimpleNamespace(content_type_guess=lambda *args:('text/plain',False),
                AppInfo=types.SimpleNamespace(get_default_for_type=lambda *args:handler),AppLaunchContext=Context)
            s.GLib=types.SimpleNamespace(SpawnFlags=types.SimpleNamespace(SEARCH_PATH=1))
            s.command({'command':'open-file','url':'file:///tmp/example.txt'})
            self.assertEqual(handler.uris,['file:///tmp/example.txt'])
            self.assertIsNone(s.pending);self.assertEqual(s.current,'a')
            self.assertEqual(s.windows.mapped[-1],([11],True))
            self.assertEqual(set(s.sessions['a']['windows']),{11})

    def test_native_home_chord_opens_keyboard_without_controls_or_first_key(self):
        import apps_input
        from keyboard_input import HomeChord,KeyboardNavigation
        lease=apps_input.Lease.__new__(apps_input.Lease)
        class Device:
            value=1
            def mode(self,value=None):
                if value is not None:self.value=value
                return self.value
        sample=dict(neutral=True,home=False,keyboardX=False,confirm=False,back=False,left=False,right=False,up=False,down=False)
        lease.device=Device();lease.pad=types.SimpleNamespace(sample=lambda:sample)
        lease.guard=types.SimpleNamespace(poll=lambda:None);lease.mapper=None;lease.keyboard=False
        lease.menu=False;lease.armed=False;lease.held='';lease.last=0;lease.resume_pending=False
        lease.chord=HomeChord();lease.navigation=KeyboardNavigation();events=[]
        def emit(event,**data):events.append((event,data))
        sample.update(home=True,neutral=False);lease.device.mode(2);lease.poll(emit)
        self.assertEqual(events,[])
        sample['keyboardX']=True;lease.poll(emit);lease.poll(emit)
        self.assertEqual(events,[('keyboard',{})])
        sample.update(home=False,keyboardX=False,neutral=True);lease.poll(emit)
        sample.update(confirm=True,neutral=False);lease.poll(emit);lease.poll(emit)
        self.assertEqual(events[-1],('keyboard-action',{'action':'confirm'}));self.assertEqual(len(events),2)
        sample.update(confirm=False,neutral=True);lease.poll(emit)
        sample.update(home=True,neutral=False);lease.poll(emit)
        sample.update(home=False,neutral=True);lease.poll(emit)
        self.assertEqual(events[-2:],[('keyboard-closed',{}),('controls',{})]);self.assertTrue(lease.menu);self.assertFalse(lease.keyboard)
    def test_installer_mapping_uses_shared_neutral_and_home_release(self):
        import apps_input
        mapper=apps_input.Mapper(apps_input.installer_profile())
        sample=dict(connected=True,neutral=True,buttons=[],sticks=[0,0,0,0],home=False)
        self.assertFalse(mapper.frame(sample,True,0)['held'])
        sample.update(neutral=False,buttons=['south'],sticks=[0,0,1,0])
        frame=mapper.frame(sample,True,.02)
        self.assertEqual(frame['held'],['MouseLeft']);self.assertGreater(frame['motion'][0],0)
        sample['home']=True
        self.assertFalse(mapper.frame(sample,True,.04)['held'])
        sample['home']=False
        self.assertFalse(mapper.frame(sample,True,.06)['held']) # Release/neutral required after Home.
    @patch.object(apps,'emit')
    def test_idle_does_not_enumerate_unowned_desktop_windows(self,emit):
        s=self.service();s.sessions={};s.current=''
        with patch.object(s.windows,'all',side_effect=AssertionError('Unnecessary X11 scan')):
            s.scan();s.scan()
        emit.assert_called_once_with('state',current='',running=[],launching='')
    def service(self):
        s=apps.Service.__new__(apps.Service);s.windows=Windows();s.current='a';s.pending=None;s.last=None;s.lease=None
        s.sessions={'a':dict(windows={11:window()},owners={(90,'100')},row={'id':'a','name':'Test'})}
        s.save_sessions=lambda:None;s.acquire=lambda *args:None
        return s
    @patch.object(apps,'emit')
    def test_close_is_request_dialog_and_cancel_remain_live(self,emit):
        s=self.service();s.windows.live={11:window()}
        s.command({'command':'close','id':'a'})
        self.assertEqual(s.windows.closed,[11]);self.assertEqual(s.current,'a')
        s.windows.live[12]=window(transient=11);s.scan()
        self.assertEqual(set(s.sessions['a']['windows']),{11,12})
        del s.windows.live[12];s.scan() # Cancel dialog, original window remains.
        self.assertEqual(set(s.sessions['a']['windows']),{11})
        s.windows.live={};s.scan();self.assertFalse(s.sessions);self.assertEqual(s.current,'')
        emit.assert_any_call('shell')
    @patch.object(apps,'emit')
    def test_minimize_restore_keeps_identity(self,emit):
        s=self.service();s.windows.live={11:window()}
        s.command({'command':'minimize'});self.assertEqual(s.current,'')
        self.assertEqual(s.windows.mapped[-1],([11],False));self.assertFalse(s.windows.closed)
        s.command({'command':'launch','id':'a'});self.assertEqual(s.current,'a')
        self.assertEqual(s.windows.mapped[-1],([11],True))
    @patch.object(apps,'emit')
    def test_reused_pid_does_not_inherit_ownership(self,emit):
        s=self.service();s.windows.live={11:window(start='200')};s.scan()
        self.assertFalse(s.sessions);self.assertFalse(s.windows.closed)
    @patch.object(apps,'emit')
    def test_background_dialog_does_not_steal_foreground(self,emit):
        s=self.service();s.current='';s.windows.live={11:window(mapped=False),12:window(transient=11)};s.scan()
        self.assertIn(([12],False),s.windows.mapped)
    @patch.object(apps,'emit')
    @patch.object(apps,'identity',return_value='root')
    def test_installer_waits_between_windows_and_tracks_new_child(self,identity,emit):
        s=self.service();s.sessions['a']['root']=(80,'root');s.windows.live={}
        s.scan();self.assertIn('a',s.sessions) # Parent setup can disappear between phases.
        s.windows.live={12:window(pid=81),13:window(pid=91)};s.scan()
        self.assertEqual(set(s.sessions['a']['windows']),{12})
        s.command({'command':'minimize'});s.windows.live[14]=window(pid=81,transient=12);s.scan()
        self.assertIn(([14],False),s.windows.mapped)
        identity.return_value='reused';s.windows.live={};s.scan();self.assertFalse(s.sessions)


if __name__=='__main__':unittest.main()
