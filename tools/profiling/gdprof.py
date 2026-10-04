#!/usr/bin/env python3
"""Minimal Godot 4 remote-debugger server that enables the script profiler
and accumulates per-function self/total time across all frames.

Usage: gdprof.py PORT OUT.json [dump_every_s]
Run the game with --remote-debug tcp://127.0.0.1:PORT (start this first).
Covers every thread, including the terrain worker. Calls/self/total are
cumulative; copy OUT.json at two moments and diff them to isolate a phase.
Read it with tools/profiling/show_profile.py OUT.json [N] [self_ms|total_ms].
Profiler overhead inflates call-heavy GDScript ~2-4x; compare ratios.
"""
import socket, struct, sys, json, time, threading

PORT = int(sys.argv[1]); OUT = sys.argv[2]
DUMP_EVERY = float(sys.argv[3]) if len(sys.argv) > 3 else 10.0

def dec(b, o):
    hdr = struct.unpack_from('<I', b, o)[0]; o += 4
    t = hdr & 0xFF; f64 = bool(hdr & (1 << 16))
    if t == 0: return None, o
    if t == 1: return bool(struct.unpack_from('<I', b, o)[0]), o + 4
    if t == 2:
        if f64: return struct.unpack_from('<q', b, o)[0], o + 8
        return struct.unpack_from('<i', b, o)[0], o + 4
    if t == 3:
        if f64: return struct.unpack_from('<d', b, o)[0], o + 8
        return struct.unpack_from('<f', b, o)[0], o + 4
    if t in (4, 21, 22):
        if t == 22:
            raise ValueError('nodepath')
        n = struct.unpack_from('<I', b, o)[0]; o += 4
        s = b[o:o + n].decode('utf-8', 'replace'); o += n
        o += (4 - n % 4) % 4
        return s, o
    if t in (5, 6):  # vec2
        fmt = '<2d' if (f64 and t == 5) else ('<2f' if t == 5 else '<2i')
        sz = struct.calcsize(fmt); return struct.unpack_from(fmt, b, o), o + sz
    if t in (9, 10):
        fmt = '<3d' if (f64 and t == 9) else ('<3f' if t == 9 else '<3i')
        sz = struct.calcsize(fmt); return struct.unpack_from(fmt, b, o), o + sz
    if t == 20: return struct.unpack_from('<4f', b, o), o + 16
    if t == 24:  # object: id only (flag) or full
        if hdr & (1 << 16):
            return ('obj', struct.unpack_from('<Q', b, o)[0]), o + 8
        n = struct.unpack_from('<I', b, o)[0]; o += 4
        if n == 0: return None, o
        raise ValueError('full object')
    if t == 27:
        n = struct.unpack_from('<I', b, o)[0] & 0x7FFFFFFF; o += 4
        d = {}
        for _ in range(n):
            k, o = dec(b, o); v, o = dec(b, o)
            d[k if not isinstance(k, (list, dict)) else str(k)] = v
        return d, o
    if t == 28:
        if hdr & (0b11 << 16):
            raise ValueError('typed array')
        n = struct.unpack_from('<I', b, o)[0] & 0x7FFFFFFF; o += 4
        a = []
        for _ in range(n):
            v, o = dec(b, o); a.append(v)
        return a, o
    if t == 29:
        n = struct.unpack_from('<I', b, o)[0]; o += 4
        v = b[o:o + n]; o += n; o += (4 - n % 4) % 4; return v, o
    if t in (30, 31, 32, 33):
        n = struct.unpack_from('<I', b, o)[0]; o += 4
        fmt = {30: 'i', 31: 'q', 32: 'f', 33: 'd'}[t]
        sz = struct.calcsize(fmt)
        return list(struct.unpack_from('<%d%s' % (n, fmt), b, o)), o + n * sz
    if t == 34:
        n = struct.unpack_from('<I', b, o)[0]; o += 4
        a = []
        for _ in range(n):
            m = struct.unpack_from('<I', b, o)[0]; o += 4
            a.append(b[o:o + m].decode('utf-8', 'replace')); o += m; o += (4 - m % 4) % 4
        return a, o
    raise ValueError('type %d' % t)

def enc(v):
    if v is None: return struct.pack('<I', 0)
    if isinstance(v, bool): return struct.pack('<II', 1, int(v))
    if isinstance(v, int): return struct.pack('<Iq', 2 | (1 << 16), v)
    if isinstance(v, float): return struct.pack('<Id', 3 | (1 << 16), v)
    if isinstance(v, str):
        e = v.encode(); return struct.pack('<II', 4, len(e)) + e + b'\0' * ((4 - len(e) % 4) % 4)
    if isinstance(v, list):
        return struct.pack('<II', 28, len(v)) + b''.join(enc(x) for x in v)
    raise TypeError(v)

def send(conn, msg, data):
    payload = enc([msg, 1, data])
    conn.sendall(struct.pack('<I', len(payload)) + payload)

sig = {}          # id -> name
acc = {}          # name -> [calls, self_ms, total_ms]
frames = [0]
other = {}
lock = threading.Lock()

def dump():
    with lock:
        rows = sorted(acc.items(), key=lambda kv: -kv[1][1])
        json.dump({'frames': frames[0], 'functions': [
            {'name': k, 'calls': v[0], 'self_ms': round(v[1], 3), 'total_ms': round(v[2], 3)} for k, v in rows],
            'other_messages': other}, open(OUT, 'w'), indent=1)

def handle(msg, data):
    if msg == 'servers:function_signature':
        other['sig_sample'] = str(data)[:600]
        if len(data) % 2 == 0 and all(isinstance(x, str) for x in data[0::2]):
            for k in range(0, len(data), 2): sig[data[k + 1]] = data[k]
        elif data and isinstance(data[0], dict):
            for k, v in data[0].items(): sig[v] = k
        return
    if msg == 'servers:profile_frame':
        frames[0] += 1
        a = data
        # Find script function block: the tail of the array is groups of 4
        # [sig_id, calls, self_time, total_time] preceded by a count.
        try:
            i = 6
            nservers = a[i]; i += 1
            for _ in range(nservers):
                i += 1  # name
                nf = a[i]; i += 1
                i += nf  # name,time pairs flattened (count already *2)
            nscript = a[i]; i += 1
            with lock:
                for k in range(0, nscript, 5):
                    sid, calls, st, tt = a[i + k:i + k + 4]
                    name = sig.get(sid, str(sid))
                    r = acc.setdefault(name, [0, 0.0, 0.0])
                    r[0] += calls; r[1] += st * 1000.0; r[2] += tt * 1000.0
        except Exception as e:
            other.setdefault('parse_error', str(e)); other.setdefault('sample', str(a)[-1500:])
        return
    if msg == 'debug_enter':
        other.setdefault('debug_enter', 0); other['debug_enter'] += 1
        return 'continue'
    other[msg] = other.get(msg, 0) + 1

srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', PORT)); srv.listen(1)
print('listening', PORT, flush=True)
conn, _ = srv.accept()
print('connected', flush=True)
send(conn, 'profiler:servers', [True, [512, False]])
buf = b''; last = time.time()
while True:
    try:
        chunk = conn.recv(1 << 20)
    except Exception:
        break
    if not chunk: break
    buf += chunk
    while len(buf) >= 4:
        n = struct.unpack_from('<I', buf, 0)[0]
        if len(buf) < 4 + n: break
        pkt = buf[4:4 + n]; buf = buf[4 + n:]
        try:
            m, _ = dec(pkt, 0)
        except Exception as e:
            other['decode_error'] = other.get('decode_error', 0) + 1
            other['decode_error_msg'] = str(e)
            continue
        if isinstance(m, list) and len(m) >= 3:
            r = handle(m[0], m[2])
            if r == 'continue':
                send(conn, 'continue', [])
    if time.time() - last > DUMP_EVERY:
        dump(); last = time.time()
dump()
print('done', frames[0], flush=True)
