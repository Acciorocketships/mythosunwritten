"""Add audio, vendor docs and a README per pack to the staging tree."""
import collections, json, os, shutil, sys

UNITY = sys.argv[1]
STAGE = sys.argv[2]
A = os.path.join(UNITY, "Assets")

PACKS = {
    "Raygeas": ("Raygeas/Suntail Village", "Raygeas — Suntail Village (stylized village: buildings, modules, props, nature, audio)"),
    "Polyart": ("Polyart/PolyartStudio", "Polyart Studio — Farmlands + Dreamscape Castle (props, building modules, crops, animals/Gobold characters)"),
    "ANGRY MESH": ("ANGRY MESH", "ANGRY MESH — Stylized Pack: Meadow Environment (trees, grass, flowers, rocks, props in summer/autumn/winter)"),
    "PureVillage": ("BK/Pure_Village", "BK — Pure Village (realistic European village: modular architecture, whole houses, props, furniture, garden, plants, trees)"),
    "PureNatureMeadows": ("BK/PureNature_Meadows", "BK — Pure Nature 2: Meadows (oak, elm, birch, cypress, willow, bushes, plants, mushrooms, rocks, barriers, mountains)"),
    "PureNatureMountains": ("BK/PureNature_Mountains", "BK — Pure Nature 2: Mountains (fir, spruce, pine, bushes, alpine plants, rocks, mountains)"),
    "PureNatureRedwood": ("BK/PureNature_Redwood", "BK — Pure Nature 2: Redwood (sequoia, red fir, red pine, hollow logs, plants, rocks)"),
}
# PACKS limited to the outNames present in this staging run (GODOT_EXPORT_PACKS).
PACKS = {k: v for k, v in PACKS.items() if os.path.isdir(os.path.join(STAGE, k))}
DOCS = [
    "Polyart/PolyartStudio/README.txt",
    "Polyart/PolyartStudio/Farmlands/FarmReadme.pdf",
    "ANGRY MESH/Stylized Pack - Common/Readme.txt",
    "ANGRY MESH/Stylized Pack - Meadow Environment/Documentation - Meadow Environment.txt",
]

manifest = json.load(open(os.path.join(STAGE, "export_manifest.json")))

# Audio (Raygeas only ships sound).
audio_root = os.path.join(A, "Raygeas/Suntail Village/Assets/Audio")
for dp, _, fs in (os.walk(audio_root) if "Raygeas" in PACKS else []):
    for f in fs:
        if f.lower().endswith((".wav", ".ogg", ".mp3")):
            rel = os.path.relpath(os.path.join(dp, f), audio_root)
            dst = os.path.join(STAGE, "Raygeas", "Audio", rel.replace(" ", "_"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(os.path.join(dp, f), dst)

for d in DOCS:
    pack = next((k for k, v in PACKS.items() if d.startswith(v[0])), None)
    if pack is None:
        continue
    dst = os.path.join(STAGE, pack, "Docs", os.path.basename(d).replace(" ", "_"))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(os.path.join(A, d), dst)

for pack, (src_root, title) in PACKS.items():
    models = [m for m in manifest["models"] if m["out"].startswith(pack + "/")]
    mats = [m for m in manifest["materials"] if m["material"].startswith("Assets/" + src_root)]
    shaders = collections.Counter(m["shader"] for m in mats)
    kinds = collections.Counter(m["kind"] for m in models)
    animated = [m for m in models if m["animations"]]
    lines = [
        f"# {title}",
        "",
        "Converted from the Unity Asset Store package for Godot 4 (" + ("October 2026" if pack.startswith("PureNature") else "September 2026") + ").",
        "Source: `~/Setup Guide In-Editor Tutorial/Assets/" + src_root + "`.",
        "",
        "## Layout",
        "",
        f"- `Models/` — {len(models)} `.glb` files: {kinds.get('prefab', 0)} from Unity prefabs, "
        f"{kinds.get('model', 0)} standalone FBX meshes no prefab used, {kinds.get('mesh_asset', 0)} Unity mesh assets.",
        "  Folder structure mirrors the Unity `Prefabs/` / `Meshes/` folders (spaces → `_`).",
        "- `Textures/` — every source texture as PNG/JPG (TIF/TGA/PSD converted). Models reference these by",
        "  relative path, so keep `Models/` and `Textures/` side by side.",
    ]
    if pack == "PureVillage":
        lines += [
            "",
            "Pure Village model groups: `Architecture/` modular wall/roof/window/door/balcony pieces",
            "(names carry their size in cm, e.g. `_60x30`), `BigModules/` large roof and tower modules,",
            "`Houses/` whole houses assembled from those modules, `HousesMerge/` the same houses as merged",
            "meshes, `HouseWarp/` hand-warped (crooked) house variants, `Doors/` separate door/shutter/lid",
            "leaves, plus `Props/`, `Furniture/`, `Garden/`, `Plants/`, `Trees/`, `Structures/`, `Rocks/`,",
            "`Mountains/`. The pack's BK Standard Layered shader adds a world-space moss/dirt layer",
            "(`Stone_*` vs `Stone_*_nomoss`); only its base maps are converted.",
        ]
    if pack == "Raygeas":
        lines.append("- `Audio/` — the pack's WAV sound effects (doors, items, fire, footsteps, forest, water).")
    if os.path.isdir(os.path.join(STAGE, pack, "Docs")):
        lines.append("- `Docs/` — vendor readme/licence files.")
    lines += [
        "",
        "## What the conversion does",
        "",
        "- Each prefab is exported by Unity itself (batch mode), so nested prefabs, material overrides and",
        "  mesh import settings are resolved exactly as in Unity. Axes are converted to glTF (Godot imports",
        "  them normally; models face +Z like other glTF assets).",
        "- Only LOD0 is kept; Godot generates its own mesh LODs on import. Colliders, lights, particle systems,",
        "  scripts and audio sources are not exported.",
        "- Materials are Godot `StandardMaterial3D` approximations of the vendor's custom shaders: albedo +",
        "  tint, normal map, alpha cut-out (foliage), roughness/metallic/AO (repacked into glTF channel order",
        "  where the source used Unity's metallic-smoothness layout), emission. Shader-only effects are",
        "  not reproduced: wind sway, world-space top moss/snow coverage, colour gradients/noise tint,",
        "  subsurface/translucency, detail maps.",
    ]
    if animated:
        lines += [
            "",
            "## Animated models",
            "",
            "Skinned characters carry their skeleton and every matching animation clip (sampled at ≤30 fps) in",
            "an `AnimationPlayer`:",
            "",
        ]
        for m in sorted(animated, key=lambda m: m["out"]):
            lines.append(f"- `{m['out'][len(pack) + 1:]}` — {m['animations']} animations")
    lines += ["", "## Source shaders", ""]
    lines += [f"- `{s}` — {n} materials" for s, n in shaders.most_common()]
    lines += [
        "",
        "## Licence",
        "",
        "Unity Asset Store Standard EULA (single-entity licence). Do not redistribute the raw files;",
        "`assets/` is git-ignored in this repository.",
        "",
    ]
    with open(os.path.join(STAGE, pack, "README.md"), "w") as f:
        f.write("\n".join(lines))

print("finalized")
