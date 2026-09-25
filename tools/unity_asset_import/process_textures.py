"""Materialize texture jobs from export_manifest.json into the staging tree.

ops: copy (convert non png/jpg to png), ms (Unity metallic R + smoothness A * s),
aa (smoothness = albedo A * s), smae (ANGRY MESH: R smooth, G metal, B AO; smoothness remapped
lerp(min,max,R)). Derived textures follow glTF: R = occlusion, G = roughness, B = metallic.
"""
import json, os, shutil, subprocess, sys, tempfile
from concurrent.futures import ProcessPoolExecutor
from PIL import Image
import numpy as np

Image.MAX_IMAGE_PIXELS = None
UNITY = sys.argv[1]      # unity project root (source files)
STAGE = sys.argv[2]

SIPS_EXT = (".tif", ".tiff", ".psd")

def sips_png(path, dst):
    # PIL drops extra alpha samples from Photoshop TIFFs; macOS sips reads them correctly.
    subprocess.run(["sips", "-s", "format", "png", path, "--out", dst], check=True, capture_output=True)

def load(src):
    path = os.path.join(UNITY, src)
    if os.path.splitext(src)[1].lower() in SIPS_EXT:
        fd, tmp = tempfile.mkstemp(suffix=".png"); os.close(fd)
        try:
            sips_png(path, tmp)
            im = Image.open(tmp); im.load()
        finally:
            os.remove(tmp)
    else:
        im = Image.open(path)
        im.load()
    if im.mode in ("I;16", "I;16B", "I", "F"):
        a = np.asarray(im).astype(np.float64)
        a = (a / (65535.0 if a.max() > 255 else 255.0) * 255).clip(0, 255).astype(np.uint8)
        im = Image.fromarray(a, "L")
    if im.mode not in ("RGB", "RGBA", "L", "LA"):
        im = im.convert("RGBA" if "A" in im.getbands() or "transparency" in im.info else "RGB")
    return im

def job(j):
    src, out, op = j["src"], j["out"], j["op"]
    dst = os.path.join(STAGE, out)
    if os.path.exists(dst):
        return None
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    try:
        ext = os.path.splitext(src)[1].lower()
        if op == "copy":
            if ext in (".png", ".jpg", ".jpeg") and os.path.splitext(out)[1].lower() == ext:
                shutil.copyfile(os.path.join(UNITY, src), dst)
            elif ext in SIPS_EXT:
                sips_png(os.path.join(UNITY, src), dst)
            else:
                load(src).save(dst, optimize=False)
            return None
        rgba = np.asarray(load(src).convert("RGBA")).astype(np.float32) / 255.0
        args = j.get("args", [])
        h, w = rgba.shape[:2]
        o = np.ones((h, w, 3), np.float32)
        if op == "ms":
            s = args[0]
            o[..., 1] = 1.0 - rgba[..., 3] * s
            o[..., 2] = rgba[..., 0]
        elif op == "aa":
            s = args[0]
            o[..., 1] = 1.0 - rgba[..., 3] * s
            o[..., 2] = 1.0
        elif op == "smae":
            lo, hi = args
            smooth = np.clip(lo + (hi - lo) * rgba[..., 0], 0, 1)
            o[..., 0] = rgba[..., 2]
            o[..., 1] = 1.0 - smooth
            o[..., 2] = rgba[..., 1]
        else:
            return f"{src}: unknown op {op}"
        Image.fromarray((o * 255 + 0.5).clip(0, 255).astype(np.uint8), "RGB").save(dst)
        return None
    except Exception as e:
        if os.path.exists(dst):
            os.remove(dst)
        return f"{src} -> {out}: {e}"

if __name__ == "__main__":
    m = json.load(open(os.path.join(STAGE, "export_manifest.json")))
    with ProcessPoolExecutor(max_workers=8) as ex:
        errs = [e for e in ex.map(job, m["textures"], chunksize=4) if e]
    print(f"{len(m['textures'])} texture jobs, {len(errs)} errors")
    for e in errs:
        print("  ", e)
