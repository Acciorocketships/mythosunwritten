#!/usr/bin/env python3
"""Extract measured modular derivations, refusing mismatched geometry or local poses.

This exports examples for the building grammar, not arbitrary prefab instancing.
A complete example must reproduce every mesh through independently loaded stock.
"""
import argparse
import copy
import json
import re
from pathlib import Path
import numpy as np
from audit_prefab_vocabulary import read_glb, mesh_signature


def matrix(node):
    if 'matrix' in node:
        return np.array(node['matrix']).reshape(4, 4, order='F')
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    # Unity/glTF roundoff can leave quaternions just off unit length.
    norm = (x*x+y*y+z*z+w*w)**.5
    x, y, z, w = x/norm, y/norm, z/norm, w/norm
    r = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    out = np.eye(4)
    out[:3, :3] = r @ np.diag(node.get('scale', [1, 1, 1]))
    out[:3, 3] = node.get('translation', [0, 0, 0])
    return out


def meshes(doc, binary, index, parent=None):
    pose = (np.eye(4) if parent is None else parent) @ matrix(doc['nodes'][index])
    node = doc['nodes'][index]
    out = []
    if 'mesh' in node:
        mesh = doc['meshes'][node['mesh']]
        materials = tuple(doc.get('materials', [])[p['material']].get('name', '')
                          if 'material' in p else '' for p in mesh['primitives'])
        out.append((mesh_signature(doc, binary, mesh), materials, pose))
    for child in node.get('children', []):
        out.extend(meshes(doc, binary, child, pose))
    return out


def material_bindings(expected, actual):
    if len(expected) != len(actual):
        return None
    remaining = list(expected)
    bindings = []
    for signature, materials, pose in actual:
        found = next((i for i, (s, m, p) in enumerate(remaining)
                      if s == signature and np.allclose(p, pose, atol=2e-4, rtol=0)), None)
        if found is None:
            return None
        bindings.append(list(remaining.pop(found)[1]))
    return bindings


def stock_match(expected, candidates):
    """Recover renamed stock by geometry, proving every child after alignment.

    The author may rename a module or move its pivot. A name is only a lookup
    hint: the complete mesh collection and its relative poses remain the proof.
    Never accept a matching subset, which could silently add a second frame.
    """
    for name, actual in candidates:
        if not expected or len(expected) != len(actual):
            continue
        for signature, _, pose in expected:
            if signature != actual[0][0]:
                continue
            alignment = pose @ np.linalg.inv(actual[0][2])
            aligned = [(s, m, alignment @ p) for s, m, p in actual]
            bindings = material_bindings(expected, aligned)
            if bindings is not None:
                return name, alignment, bindings
    return None



def drawer_displacement(original, candidate, depth):
    """Only a forward local-Z slide, retaining at least half the drawer depth."""
    if not np.allclose(original[:3, :3], candidate[:3, :3], atol=2e-4, rtol=0):
        return None
    delta = candidate[:3, 3] - original[:3, 3]
    if not np.allclose(delta[:2], 0, atol=2e-4, rtol=0):
        return None
    if not np.isfinite(depth) or depth <= 0 or not 0 <= delta[2] <= depth * .5:
        return None
    return float(delta[2])


def articulated_match(doc, binary, index, stock, stock_binary):
    """Suntail's authored cupboard has one sliding drawer, not free child poses.

    The named socket selects the rule; complete geometry and all relative poses
    still have to match after applying that single bounded degree of freedom.
    """
    node = doc['nodes'][index]
    roots = stock['scenes'][stock.get('scene', 0)]['nodes']
    if node.get('name') != 'Cupboard_1' or len(roots) != 1:
        return None
    original = stock['nodes'][roots[0]]
    if original.get('name') != 'Cupboard_1':
        return None
    children = node.get('children', [])
    stock_children = original.get('children', [])
    if len(children) != 1 or len(stock_children) != 1:
        return None
    child, stock_child = doc['nodes'][children[0]], stock['nodes'][stock_children[0]]
    if child.get('name') != 'Cupboard_1_Box' or stock_child.get('name') != 'Cupboard_1_Box':
        return None
    if child.get('children') or stock_child.get('children') or 'mesh' not in stock_child:
        return None
    bounds = [stock['accessors'][p['attributes']['POSITION']]
              for p in stock['meshes'][stock_child['mesh']]['primitives']]
    if not bounds or any('min' not in a or 'max' not in a for a in bounds):
        return None
    depth = max(a['max'][2] for a in bounds) - min(a['min'][2] for a in bounds)
    displacement = drawer_displacement(matrix(stock_child), matrix(child), depth)
    if displacement is None:
        return None
    posed = copy.deepcopy(stock)
    moved = matrix(stock_child)
    moved[2, 3] += displacement
    posed['nodes'][stock_children[0]] = dict(stock_child, matrix=moved.flatten(order='F').tolist())
    expected = meshes(doc, binary, index, np.linalg.inv(matrix(node)))
    actual = meshes(posed, stock_binary, roots[0])
    bindings = material_bindings(expected, actual)
    if bindings is None:
        return None
    return bindings, {'rule': 'suntail.cupboard.drawer_slide',
                      'node': 'Cupboard_1_Box', 'displacement': displacement}


def derive(house, modules):
    roots = [modules] if isinstance(modules, Path) else list(modules)
    doc, binary = read_glb(house)
    parts, missing = [], []
    stock_by_signature = None

    def fallback(expected):
        nonlocal stock_by_signature
        if stock_by_signature is None:
            stock_by_signature = {}
            for path in sorted({p for root in roots for p in root.glob('*.glb')}):
                stock, data = read_glb(path)
                actual = []
                for root in stock['scenes'][stock.get('scene', 0)]['nodes']:
                    actual.extend(meshes(stock, data, root))
                key = tuple(sorted(s for s, _, _ in actual))
                stock_by_signature.setdefault(key, []).append((path, actual))
        key = tuple(sorted(s for s, _, _ in expected))
        return stock_match(expected, stock_by_signature.get(key, []))

    def visit(index, parent):
        node = doc['nodes'][index]
        pose = parent @ matrix(node)
        name = re.sub(r' \(\d+\)$', '', node.get('name', ''))
        named = [root / (name + '.glb') for root in roots
                 if (root / (name + '.glb')).exists()]
        for path in named:
            stock, stock_binary = read_glb(path)
            expected = meshes(doc, binary, index, np.linalg.inv(matrix(node)))
            actual = []
            for root in stock['scenes'][stock.get('scene', 0)]['nodes']:
                actual.extend(meshes(stock, stock_binary, root))
            bindings = material_bindings(expected, actual)
            if bindings is not None:
                parts.append({'module': name, 'module_source': path.as_posix(),
                              'matrix': pose.flatten(order='F').tolist(),
                              'source_node': index, 'materials': bindings})
                return
            articulated = articulated_match(doc, binary, index, stock, stock_binary)
            if articulated is not None:
                bindings, joint = articulated
                parts.append({'module': name, 'module_source': path.as_posix(),
                              'matrix': pose.flatten(order='F').tolist(),
                              'source_node': index, 'materials': bindings,
                              'joints': [joint]})
                return
        # An authored structure may be a modified assembly of ordinary stock
        # (for example HouseStairs3 with different flights). Reject replacing
        # that whole assembly, then prove its children independently instead.
        # A mesh-bearing mismatch is still recorded below if no stock fits it.
        if 'mesh' in node:
            expected = meshes(doc, binary, index, np.linalg.inv(matrix(node)))
            match = fallback(expected)
            if match is not None:
                module, alignment, bindings = match
                parts.append({'module': module.stem, 'module_source': module.as_posix(),
                              'matrix': (pose @ alignment).flatten(order='F').tolist(),
                              'source_node': index, 'materials': bindings})
                return
            missing.append({'node': index, 'name': name,
                            'reason': 'module_geometry_or_pose_mismatch' if named
                            else 'no_modular_stock'})
        for child in node.get('children', []):
            visit(child, pose)
    for root in doc['scenes'][doc.get('scene', 0)]['nodes']:
        visit(root, np.eye(4))
    return {'source': house.as_posix(), 'complete': not missing, 'parts': parts, 'unmatched': missing}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('house', type=Path, help='One prefab GLB or a directory of prefab GLBs')
    parser.add_argument('--modules', type=Path, nargs='+', default=[
        Path('assets/PureVillage/Models') / folder
        for folder in ('Architecture', 'Doors', 'Structures')],
        help='Stock module directories; defaults to Pure Village architecture, doors and structures')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    results = [derive(path, args.modules) for path in sorted(args.house.glob('*.glb'))] \
        if args.house.is_dir() else [derive(args.house, args.modules)]
    if not results:
        parser.error('No prefab GLBs found')
    result = results if args.house.is_dir() else results[0]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    for example in results:
        print(f"{example['source']}: {len(example['parts'])} modules; "
              f"{len(example['unmatched'])} unmatched; complete={example['complete']}")
    raise SystemExit(0 if all(example['complete'] for example in results) else 1)
