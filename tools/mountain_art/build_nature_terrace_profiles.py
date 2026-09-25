"""Sample three broad sections of the original CC0 Ultimate Nature moss rocks.

Only numeric front profiles are emitted. Runtime terrain workers need no OBJ,
scene imports, ray intersections, or mutable resource access.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SECTIONS = (0.22, 0.48, 0.72)
SAMPLES = 97


def read_obj(path):
    vertices, faces = [], []
    for line in path.read_text().splitlines():
        words = line.split()
        if not words:
            continue
        if words[0] == 'v':
            vertices.append(tuple(map(float, words[1:4])))
        elif words[0] == 'f':
            indices = [int(word.split('/')[0]) - 1 for word in words[1:]]
            faces.extend((indices[0], indices[i], indices[i + 1])
                         for i in range(1, len(indices) - 1))
    lo = [min(v[i] for v in vertices) for i in range(3)]
    hi = [max(v[i] for v in vertices) for i in range(3)]
    vertices = [tuple((v[i] - lo[i]) / (hi[i] - lo[i]) for i in range(3))
                for v in vertices]
    return vertices, faces


def front(vertices, faces, x, y, hand):
    depth = -1.0
    for triangle in faces:
        a, b, c = [vertices[i] for i in triangle]
        denominator = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denominator) < 1e-9:
            continue
        wa = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/denominator
        wb = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/denominator
        wc = 1-wa-wb
        if min(wa, wb, wc) < -1e-6:
            continue
        z = wa*a[2]+wb*b[2]+wc*c[2]
        depth = max(depth, z if hand == 1 else 1-z)
    return round(depth, 6)


def build(body=False):
    sources = []
    for variant in (1, 2, 4, 7):
        relative = f'assets/UltimateNaturePack/OBJ/Rock_Moss_{variant}.obj'
        path = ROOT / relative
        vertices, faces = read_obj(path)
        for hand in (1, -1):
            record = dict(source='res://' + relative, hand=hand,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                sections=[[front(vertices, faces, i/(SAMPLES-1), y, hand)
                           for i in range(SAMPLES)] for y in SECTIONS])
            if body:
                record['body'] = [[max(0.0, front(vertices, faces, i/48, y/32, hand))
                                   for i in range(49)] for y in range(33)]
            sources.append(record)
    return dict(license='Quaternius Ultimate Nature Pack, CC0',
                section_heights=SECTIONS, samples=SAMPLES, sources=sources)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'terrain/cliff/nature_terrace_profiles.json')
    parser.add_argument('--body', action='store_true', help='Include detached whole-rock front samples for art studies')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(build(args.body), separators=(',', ':')) + '\n')
    print(args.output)
