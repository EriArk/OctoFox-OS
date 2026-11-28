"""A shell that stays open after its desktop launcher double-forks."""
import os
from pathlib import Path
import time

if 'TRAINEROS_READY_FD' in os.environ:
    os.write(int(os.environ['TRAINEROS_READY_FD']), b'R')

reader, writer = os.pipe()
launcher = os.fork()
if launcher == 0:
    os.close(reader)
    game = os.fork()
    if game == 0:
        os._exit(17)
    os.write(writer, str(game).encode())
    os._exit(0)

os.close(writer)
game = int(os.read(reader, 32))
os.close(reader)
os.waitpid(launcher, 0)
deadline = time.monotonic() + 3
while Path(f'/proc/{game}').exists():
    if time.monotonic() >= deadline:
        raise SystemExit('Game still in the process table while shell is running')
    time.sleep(0.02)
