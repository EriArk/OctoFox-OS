# SPDX-License-Identifier: GPL-3.0-or-later
"""ROM-free native preparation/reopen check. Requires libretro.py==0.12.0."""
from pathlib import Path
import argparse,gc,json,logging,os,struct,tempfile

def cartridge():
    data=bytearray(0x10000);data[:12]=b'TRAINER TEST '.ljust(12,b' ');data[12:16]=b'TST0'
    struct.pack_into('<IIII',data,0x20,0x200,0x02000000,0x02000000,4)
    struct.pack_into('<IIII',data,0x30,0x204,0x03800000,0x03800000,4)
    struct.pack_into('<II',data,0x80,len(data),0x200)
    struct.pack_into('<II',data,0x200,0xeafffffe,0xeafffffe)
    return bytes(data)

def crc(data):
    value=0
    for byte in data:
        value^=byte
        for _ in range(8):value=(value>>1)^0xa001 if value&1 else value>>1
    return value

def run(core, directory, dll_directory):
    # Production also starts a fresh RetroArch process for each game session.
    dll=os.add_dll_directory(dll_directory) if dll_directory and os.name=='nt' else None
    from libretro import Session,ExplicitPathDriver,UnformattedLogDriver
    directory=Path(directory)
    path=ExplicitPathDriver(core,system=directory/'system',save=directory/'saves')
    mac='10:21:32:43:54:65'
    options={'melonds_console_mode':'ds','melonds_sysfile_mode':'builtin','melonds_boot_mode':'direct','melonds_network_mode':'indirect','melonds_firmware_wfc_dns':'178.62.43.212','melonds_render_mode':'software','melonds_jit_enable':'enabled','melonds_firmware_username':'melonDS DS','melonds_mac_address_mode':mac,'melonds_homebrew_sdcard':'disabled'}
    logs=[]
    class Capture(logging.Handler):
        def emit(self,record):logs.append(record.getMessage())
    logger=logging.getLogger('ds-wfc');logger.setLevel(logging.DEBUG);logger.addHandler(Capture())
    with Session(core,directory/'game.nds',path=path,options=options,log=UnformattedLogDriver(logger)) as emulator:
        for _ in range(300):emulator.run()
    assert any('Initialized indirect-mode' in message for message in logs),logs[-12:]
    assert any(mac.upper() in message.upper() for message in logs),[m for m in logs if 'mac' in m.lower()]
    # Release the frontend's mapped content before the parent removes its fixture.
    del emulator
    gc.collect()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('core');ap.add_argument('--dll-directory');ap.add_argument('--worker')
    ap.add_argument('--worker-python',help='Python executable or QEMU wrapper for the target architecture');args=ap.parse_args()
    if args.worker:
        run(str(Path(args.core).resolve()),args.worker,args.dll_directory)
        return
    import subprocess,sys
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);rom=root/'game.nds';rom.write_bytes(cartridge())
        system=root/'system'/'melonDS DS';system.mkdir(parents=True)
        (system/'console.txt').write_text('10:21:32:43:54:65\n')
        command=[args.worker_python or sys.executable,str(Path(__file__).resolve()),args.core,'--worker',directory]
        if args.dll_directory:command+=['--dll-directory',args.dll_directory]
        subprocess.run(command,check=True,timeout=90)
        target=system/'wfcsettings.bin';raw=target.read_bytes();assert len(raw)==2304
        access=raw[1536:1792];assert access[64:71]==b'melonAP'
        assert access[200:208]==bytes([178,62,43,212])*2
        assert access[231]==0
        assert crc(access[:254])==struct.unpack_from('<H',access,254)[0]
        patched=bytearray(raw);patched[1536+240:1536+246]=b'OWNID!'
        struct.pack_into('<H',patched,1536+254,crc(patched[1536:1536+254]));target.write_bytes(patched)
        subprocess.run(command,check=True,timeout=90)
        after=target.read_bytes();assert after[1536+240:1536+246]==b'OWNID!'
        assert rom.read_bytes()==cartridge()
    print(json.dumps(dict(frames=600,builtin_firmware=True,indirect_network_initialized=True,automatic_ap_dns=True,stable_mac=True,own_wfc_id_reopened=True,rom_unchanged=True)))
if __name__=='__main__':main()
