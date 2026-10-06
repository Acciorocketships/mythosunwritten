"""Read converted glTF assembly transforms and bounds without importing assets.

Usage: python3 tools/environment_bake/survey_modular_pack.py PACK/Models OUT.json
Bounds enclose transformed accessor bounds; they are broad-phase measurements,
not proofs of mesh contact or a substitute for visual/collision inspection.
"""
import argparse
import itertools
import json
from pathlib import Path
import struct


def identity():
    return [[float(i == j) for j in range(4)] for i in range(4)]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4))
             for j in range(4)] for i in range(4)]


def transform(node):
    if "matrix" in node:
        return [[node["matrix"][j * 4 + i] for j in range(4)] for i in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    r = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0],
         [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w), 0],
         [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y), 0],
         [0, 0, 0, 1]]
    scale = node.get("scale", [1, 1, 1])
    offset = node.get("translation", [0, 0, 0])
    for i in range(3):
        for j in range(3):
            r[i][j] *= scale[j]
        r[i][3] = offset[i]
    return r


def read_glb(path):
    with path.open("rb") as f:
        magic, version, _ = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67 or version != 2:
            raise ValueError(f"Not glTF 2: {path}")
        length, kind = struct.unpack("<II", f.read(8))
        if kind != 0x4E4F534A:
            raise ValueError(f"Missing JSON chunk: {path}")
        return json.loads(f.read(length))


def measure(path):
    data = read_glb(path)
    points, pieces = [], []
    triangle_count = 0

    def visit(index, parent):
        nonlocal triangle_count
        node = data["nodes"][index]
        matrix = multiply(parent, transform(node))
        if "mesh" in node:
            mesh = data["meshes"][node["mesh"]]
            pieces.append({"node": node.get("name", str(index)),
                           "mesh": mesh.get("name", ""), "transform": matrix})
            for primitive in mesh["primitives"]:
                a = data["accessors"][primitive["attributes"]["POSITION"]]
                for corner in itertools.product(*zip(a["min"], a["max"])):
                    points.append([sum(matrix[i][j] * corner[j] for j in range(3))
                                   + matrix[i][3] for i in range(3)])
                if primitive.get("mode", 4) == 4:
                    triangle_count += (data["accessors"][primitive["indices"]]["count"]
                                       if "indices" in primitive else a["count"]) // 3
        for child in node.get("children", []):
            visit(child, matrix)

    for root in data["scenes"][data.get("scene", 0)]["nodes"]:
        visit(root, identity())
    if not points:
        return {"pieces": [], "triangles": 0}
    low = [min(p[i] for p in points) for i in range(3)]
    high = [max(p[i] for p in points) for i in range(3)]
    return {"min": low, "max": high, "size": [high[i]-low[i] for i in range(3)],
            "triangles": triangle_count, "pieces": pieces,
            "materials": [m.get("name", "") for m in data.get("materials", [])]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("models", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assets = {str(p.relative_to(args.models)): measure(p)
              for p in sorted(args.models.rglob("*.glb"))}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"source": str(args.models), "assets": assets}, indent=2)+"\n")
    groups = {}
    for name in assets:
        group = name.split("/")[0]
        groups[group] = groups.get(group, 0)+1
    print(json.dumps({"assets": len(assets), "groups": groups}, indent=2))


if __name__ == "__main__":
    main()
