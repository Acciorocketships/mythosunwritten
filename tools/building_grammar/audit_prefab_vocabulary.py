#!/usr/bin/env python3
"""Measure prefab mesh coverage by native modular assets; never infer compatibility from names.

This is the reconstruction benchmark's inventory step, not a placement grammar.
Geometry/material variants must be distinguished before learning connection rules.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import struct

COMPONENT_BYTES = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
COMPONENTS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def read_glb(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from('<III', data)
    if magic != 0x46546C67 or version != 2 or total != len(data):
        raise ValueError(f'Invalid GLB: {path}')
    chunks = {}
    cursor = 12
    while cursor < total:
        size, kind = struct.unpack_from('<II', data, cursor)
        chunks[kind] = data[cursor + 8:cursor + 8 + size]
        cursor += 8 + size
    return json.loads(chunks[0x4E4F534A]), chunks.get(0x004E4942, b'')


def accessor_bytes(doc, binary, index):
    a = doc['accessors'][index]
    if 'sparse' in a:
        raise ValueError('Sparse accessors require explicit decoding')
    view = doc['bufferViews'][a['bufferView']]
    if view.get('buffer', 0) != 0:
        raise ValueError('External buffers are not supported')
    width = COMPONENT_BYTES[a['componentType']] * COMPONENTS[a['type']]
    stride = view.get('byteStride', width)
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    packed = b''.join(binary[offset + i * stride:offset + i * stride + width]
                      for i in range(a['count']))
    return json.dumps([a['componentType'], a['type'], a['count'],
                       a.get('normalized', False)]).encode() + packed


def mesh_signature(doc, binary, mesh):
    h = hashlib.sha256()
    for primitive in mesh['primitives']:
        if 'targets' in primitive or 'extensions' in primitive:
            raise ValueError('Morph/compressed primitives require explicit decoding')
        h.update(str(primitive.get('mode', 4)).encode())
        for name, index in sorted(primitive['attributes'].items()):
            h.update(name.encode())
            h.update(accessor_bytes(doc, binary, index))
        if 'indices' in primitive:
            h.update(b'indices')
            h.update(accessor_bytes(doc, binary, primitive['indices']))
    return h.hexdigest()


def mesh_nodes(doc):
    def visit(index, ancestors):
        node = doc['nodes'][index]
        path = ancestors + [node.get('name', str(index))]
        if 'mesh' in node:
            yield index, path, node['mesh']
        for child in node.get('children', []):
            yield from visit(child, path)
    scene = doc['scenes'][doc.get('scene', 0)]
    for root in scene['nodes']:
        yield from visit(root, [])


def audit(modules, houses):
    vocabulary = collections.defaultdict(list)
    for path in sorted({p for root in modules for p in root.rglob('*.glb')}):
        doc, binary = read_glb(path)
        signatures = [mesh_signature(doc, binary, mesh) for mesh in doc.get('meshes', [])]
        for index, node_path, mesh in mesh_nodes(doc):
            vocabulary[signatures[mesh]].append({'source': str(path), 'node': index,
                                                'path': node_path})
    records = []
    missing = collections.Counter()
    for path in sorted(houses.glob('*.glb')):
        doc, binary = read_glb(path)
        signatures = [mesh_signature(doc, binary, mesh) for mesh in doc.get('meshes', [])]
        parts = []
        for index, node_path, mesh in mesh_nodes(doc):
            signature = signatures[mesh]
            candidates = vocabulary.get(signature, [])
            name = doc['meshes'][mesh].get('name', str(mesh))
            if not candidates:
                missing[name] += 1
            parts.append({'node': index, 'path': node_path, 'mesh': name,
                          'geometry_signature': signature,
                          'module_candidates': candidates})
        records.append({'source': str(path), 'parts': parts,
                        'matched': sum(bool(p['module_candidates']) for p in parts),
                        'total': len(parts)})
    return {'schema': 1, 'comparison': 'exact vertex attributes and topology; materials not yet compared',
            'module_geometry_count': len(vocabulary), 'houses': records,
            'unmatched_meshes': dict(missing.most_common()),
            'summary': {'houses': len(records), 'parts': sum(r['total'] for r in records),
                        'matched': sum(r['matched'] for r in records),
                        'fully_matched_houses': sum(r['matched'] == r['total'] for r in records)}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modules', type=Path, nargs='+', required=True)
    parser.add_argument('--houses', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.modules, args.houses)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result['summary'], indent=2))
