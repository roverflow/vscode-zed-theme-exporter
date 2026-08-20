"""Run a command on a pseudo-terminal and feed it answers.

The interactive picker refuses to run without a terminal, which is the right
behaviour and also means a plain pipe cannot test it.

    DRIVE_INPUT='1|all|n' python3 tests/drive_tty.py ./vsc2zed --interactive
"""

import os
import pty
import select
import sys
import time

cmd = sys.argv[1:]
answers = [a for a in os.environ.get("DRIVE_INPUT", "").split("|")]

pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)

output = b""
sent = 0
deadline = time.time() + 60
while time.time() < deadline:
    ready, _, _ = select.select([fd], [], [], 0.35)
    if ready:
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        output += chunk
    elif sent < len(answers):
        # Quiet on the pty means the command is waiting for an answer.
        os.write(fd, (answers[sent] + "\n").encode())
        sent += 1
    elif output:
        break

os.close(fd)
_, status = os.waitpid(pid, 0)
sys.stdout.write(output.decode(errors="replace").replace("\r\n", "\n"))
sys.exit(status >> 8)
