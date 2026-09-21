"""SYNTHETIC ephemeral loopback WebSocket endpoint, never a game server."""
import base64
import hashlib
import json
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from test_death_respawn import fixture
from death_respawn import analyze

ROOT = Path(__file__).parent

class RecordingTests(unittest.TestCase):
    def run_mock(self, mode):
        with tempfile.TemporaryDirectory() as tmp, socket.socket() as listener:
            listener.bind(('127.0.0.1', 0)); listener.listen(); listener.settimeout(3)
            stopped = threading.Event()
            def serve():
                try:
                    conn, _ = listener.accept()
                    with conn:
                        conn.settimeout(2)
                        request = b''
                        while b'\r\n\r\n' not in request:
                            request += conn.recv(4096)
                        if mode == 'connection':
                            stopped.wait(1); return
                        key = next(line.split(b':', 1)[1].strip() for line in request.split(b'\r\n') if line.lower().startswith(b'sec-websocket-key:'))
                        accept = base64.b64encode(hashlib.sha1(key+b'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest())
                        conn.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: '+accept+b'\r\n\r\n')
                        conn.recv(4096)  # join, no game inputs
                        messages = [json.dumps(r['frame']).encode() for r in fixture()['frames']]
                        if mode == 'malformed': messages = [b'{']
                        if mode == 'size': messages = [b'x'*2000]
                        if mode == 'setup': messages = []
                        for msg in messages:
                            header = bytes([0x81,len(msg)]) if len(msg)<126 else b'\x81\x7e'+struct.pack('!H',len(msg))
                            conn.sendall(header+msg)
                        if mode == 'disconnect': return
                        stopped.wait(2)
                except (OSError, StopIteration): pass
            thread = threading.Thread(target=serve); thread.start()
            path = Path(tmp)/'synthetic.json'
            cmd = ['node',str(ROOT/'record.mjs'),'--url',f'ws://127.0.0.1:{listener.getsockname()[1]}','--room','SYNTHETIC','--name','mock','--output',str(path),'--classification','synthetic','--seconds','0.7','--connect-seconds','0.2','--setup-seconds','0.4','--max-bytes','1000' if mode=='size' else '100000','--max-frames','2' if mode=='frames' else '100']
            try:
                p = subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                if mode == 'interrupt':
                    # Wait for handshake/messages, then signal this child only.
                    threading.Event().wait(0.35); p.send_signal(signal.SIGINT)
                out, err = p.communicate(timeout=4)
                self.assertEqual(p.returncode,0 if mode=='valid' else 1,(out,err))
                data = json.loads(path.read_text())
                self.assertEqual(data['classification'],'synthetic')
                result = analyze(data)
                self.assertEqual(result['status'],'established' if mode=='valid' else 'incomplete',result)
                cli = subprocess.run([sys.executable,'-B',str(ROOT/'death_respawn.py'),str(path),'--json'],capture_output=True)
                self.assertEqual(cli.returncode,0 if mode=='valid' else 1,cli.stdout)
                if mode=='valid':
                    data['frames'].pop()
                    self.assertEqual(analyze(data)['status'],'incomplete')
                again = subprocess.run(cmd,capture_output=True,timeout=3)
                self.assertNotEqual(again.returncode,0) # exclusive output, no overwrite
            finally:
                if p.poll() is None: p.kill(); p.wait()
                stopped.set(); thread.join(3)
                self.assertFalse(thread.is_alive())

    def test_envelope_boundaries(self):
        d = fixture(); d['format'] = 'cocs-recording-v1'
        d['frames'].insert(0, {'client': 1, 'direction': 'lifecycle', 'kind': 'open'})
        d['frames'].extend([{'client': 1, 'direction': 'lifecycle', 'kind': 'close'}, {'client': 1, 'direction': 'lifecycle', 'kind': 'completion', 'complete': True, 'reason': 'recording_window_elapsed'}])
        for i, r in enumerate(d['frames']): r['at_ms'] = i
        self.assertEqual(analyze(d)['status'], 'established')
        d['frames'][0]['kind'] = 'close'
        self.assertEqual(analyze(d)['status'], 'invalid')
        d['frames'][0]['kind'] = 'open'
        d['frames'][2]['at_ms'] = -1
        self.assertEqual(analyze(d)['status'], 'invalid')

    def test_cli_mock_matrix(self):
        for mode in ('valid','setup','connection','disconnect','malformed','size','frames','interrupt'):
            with self.subTest(mode=mode): self.run_mock(mode)

if __name__ == '__main__': unittest.main()
