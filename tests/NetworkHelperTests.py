"""Content-free checks of Wi-Fi activation/rollback and bounded requests."""
import importlib.util
from pathlib import Path
import types
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('network', Path(__file__).resolve().parents[1]/'packaging/integrations/network-control.py')
n = importlib.util.module_from_spec(spec); spec.loader.exec_module(n)

class NetworkTests(unittest.TestCase):
    def test_linux_executable_shebang(self):
        self.assertEqual(Path(spec.origin).read_bytes().split(b'\n', 1)[0], b'#!/usr/bin/python3 -I')

    def test_protocol_and_security(self):
        self.assertEqual(n.wifi_security({'RsnFlags': 0x100}), 'wpa-psk')
        self.assertEqual(n.wifi_security({'RsnFlags': 0x400}), 'sae')
        self.assertEqual(n.wifi_security({'RsnFlags': 0x200}), 'unsupported')
        self.assertEqual(n.wifi_security({'Flags': 1}), 'unsupported')
        self.assertEqual(n.wifi_security({}), 'open')
        for value in ({'op':'shell','kind':'wifi'}, {'op':'pair','kind':'wifi'},
                      {'op':'connect','kind':'wifi','password':'x'*65},
                      {'op':'connect','kind':'wifi','id':[]},
                      {'op':'list','kind':'wifi','command':'bad'}):
            with self.assertRaises(ValueError): n.validate(value)

    def activation(self, *, saved=False, state=2, cancel=False, stale=False, password=None, hidden=False, reason=0, connected=False, dbus_types=False):
        events=[]
        if dbus_types:
            import dbus
            from dbus.lowlevel import MethodCallMessage
        class Manager:
            def CheckpointCreate(self,*args,**kw):events.append('protect');return '/checkpoint'
            def ActivateConnection(self,*args,**kw):events.append('activate-saved');return '/active'
            def DeactivateConnection(self,*args,**kw):events.append('disconnect-old')
            def AddAndActivateConnection2(self,config,device,ap,options,**kw):
                self.options=options;self.config=config;events.append('activate-memory');return '/new','/active',{}
            def CheckpointRollback(self,*args,**kw):events.append('rollback')
            def CheckpointDestroy(self,*args,**kw):events.append('unprotect')
            def Save(self,**kw):events.append('save')
            def Delete(self,**kw):events.append('delete-new')
            def GetSettings(self,**kw):
                config={'connection':{'uuid':'same-uuid','id':'Home'},'802-11-wireless-security':{'key-mgmt':'wpa-psk'}}
                if dbus_types:
                    config['ipv4']={'address-data':dbus.Array([],signature='a{sv}'),'routes':dbus.Array([],signature='au')}
                    config=dbus.Dictionary({k:dbus.Dictionary(v,signature='sv') for k,v in config.items()},signature='sa{sv}')
                self.original=config;return config
            def GetSecrets(self,*args,**kw):return {'802-11-wireless-security':{'psk':'old-password'}}
            def UpdateUnsaved(self,config,**kw):
                if dbus_types:
                    MethodCallMessage('org.fixture','/fixture','org.fixture.Connection','UpdateUnsaved').append(config,signature='a{sa{sv}}')
                events.append('restore-password' if config['802-11-wireless-security']['psk']=='old-password' else 'try-password');self.config=config
        class Monitor(n.WifiStateMonitor):
            def __init__(self,*args):self.reason=0;self.needs_auth=False
            def drain(self):pass
            def close(self):pass
        manager=Manager();p=object.__new__(n.Platform);p.bus=None
        p.d=types.SimpleNamespace(Array=lambda v,**kw:v,ObjectPath=str,UInt32=int,Boolean=bool,
                                  ByteArray=bytes,Dictionary=lambda v,**kw:dict(v),DBusException=RuntimeError)
        if dbus_types:p.d=dbus
        row={'id':'target','title':'Fixture network','connected':connected,'available':True,
             'security':'wpa-psk','_profile':'/saved' if saved else None,'_ap':'/ap','_ssid':b'Fixture'}
        p.wifi=lambda:(manager,'/device','/old',[] if stale else [row])
        p.iface=lambda *args:manager
        p.props=lambda *args:{'State':state,'StateReason':(120,reason)}
        request={'op':'connect','id':'target'}
        if password is not None or not saved:request['password']=password or 'fixture-password'
        if hidden:request={'op':'connect','ssid':'Hidden','security':'wpa-psk','password':'fixture-password'}
        with patch.object(n,'WifiStateMonitor',Monitor), patch.object(n,'check_cancel',side_effect=n.Cancelled() if cancel else None), patch.object(n,'emit') as output:
            if state!=2 or cancel or stale:
                with self.assertRaises((n.UserError,n.Cancelled)):
                    p.wifi_action(request)
            else:p.wifi_action(request)
            self.assertNotIn('fixture-password',repr(output.call_args_list))
            self.assertNotIn('old-password',repr(output.call_args_list))
        return events,manager

    def test_new_profile_persists_only_after_connection(self):
        events,manager=self.activation()
        self.assertEqual(manager.options,{'persist':'memory'})
        self.assertEqual(events,['protect','activate-memory','save','unprotect'])

    def test_failure_and_cancel_restore_old_connection_and_discard_new_profile(self):
        for kwargs in ({'state':4},{'cancel':True}):
            events,_=self.activation(**kwargs)
            self.assertEqual(events,['protect','activate-memory','rollback','unprotect','delete-new'])
        events,_=self.activation(saved=True,state=4)
        self.assertEqual(events,['protect','activate-saved','rollback','unprotect'])

    def test_stale_selection_never_mutates(self):
        self.assertEqual(self.activation(stale=True)[0],[])

    def test_password_replacement_is_transactional(self):
        events,manager=self.activation(saved=True,password='new-password')
        self.assertEqual(events,['protect','try-password','activate-saved','save','unprotect'])
        self.assertEqual(manager.config['connection']['uuid'],'same-uuid')
        self.assertEqual(manager.original['802-11-wireless-security']['psk'],'old-password')
        for kwargs in ({'state':4},{'cancel':True}):
            events,manager=self.activation(saved=True,password='new-password',**kwargs)
            self.assertEqual(events,['protect','try-password','activate-saved','restore-password','rollback','unprotect'])
            self.assertEqual(manager.config['802-11-wireless-security']['psk'],'old-password')
        events,_=self.activation(saved=True,connected=True,password='new-password',state=4)
        self.assertEqual(events,['protect','try-password','disconnect-old','activate-saved','restore-password','rollback','unprotect'])

    @unittest.skipUnless(importlib.util.find_spec('dbus'), 'Requires Linux dbus-python')
    def test_password_update_preserves_dbus_empty_array_signatures(self):
        for state in (2,4):
            _,manager=self.activation(saved=True,password='new-password',state=state,dbus_types=True)
            self.assertEqual(manager.original['802-11-wireless-security']['psk'],'old-password')

    def test_hidden_network_uses_explicit_ssid_and_security(self):
        _,manager=self.activation(hidden=True)
        self.assertTrue(manager.config['802-11-wireless']['hidden'])
        self.assertEqual(manager.config['802-11-wireless']['ssid'],b'Hidden')
        for extra in ({'ssid':''},{'ssid':'x'*33},{'ssid':'test','security':'shell'},{'ssid':'test','security':'open','id':'other'},
                      {'enabled':'yes'}, {'ssid':'test','security':'open','op':'forget'}):
            with self.assertRaises(ValueError):n.validate({'op':'connect','kind':'wifi',**extra})
        n.validate({'op':'autojoin','kind':'wifi','id':'saved:one','enabled':False})
        with self.assertRaises(ValueError):n.validate({'op':'autojoin','kind':'bluetooth','enabled':True})

    def test_authentication_and_network_errors_are_distinct(self):
        self.assertIn('password may be incorrect',n.wifi_failure(7))
        self.assertIn('authentication did not complete',n.wifi_failure(11))
        self.assertIn('network address',n.wifi_failure(5))
        self.assertIn('no longer found',n.wifi_failure(53))
        self.assertNotIn('password',n.wifi_failure(53))
        self.assertNotIn('password',n.wifi_failure(53,True))
        self.assertIn('network address',n.wifi_failure(5,True))

    def test_transient_failure_survives_disconnected_snapshot(self):
        monitor=object.__new__(n.WifiStateMonitor);monitor.reason=0;monitor.needs_auth=False
        monitor.observe(60,50,0)
        monitor.observe(120,60,7)
        monitor.observe(30,120,0)
        self.assertEqual(monitor.reason,7)
        self.assertIn('password may be incorrect',n.wifi_failure(monitor.reason,monitor.needs_auth))

if __name__ == '__main__':unittest.main()
