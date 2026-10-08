# Unity Asset Store → Godot conversion

Converts purchased Unity packages (prefabs, `.mat`, FBX, Unity mesh assets) into
self-contained `.glb` models plus shared PNG textures under `assets/<Pack>/`.
Used on 2026-09-23 for Raygeas Suntail Village, Polyart Farmlands/Dreamscape Castle and
ANGRY MESH Meadow Environment, on 2026-09-26 for BK Pure Village (`assets/PureVillage`), and on 2026-10-07 for BK Pure Nature 2
(`assets/PureNatureMeadows`, `assets/PureNatureMountains`, `assets/PureNatureRedwood`; trunks read
`BK/Vegetation Trunk`'s `_MetallicROcclusionGSmoothnessA` MOS map). See each pack's `assets/<Pack>/README.md`.

Unity itself resolves prefabs, nested prefabs, material overrides and FBX import
settings, so the conversion runs inside Unity batch mode on an APFS clone of the
Unity project (the original project may stay open):

```bash
cp -Rc "<unity project>" "$SCRATCH/unity_clone" && rm -rf "$SCRATCH/unity_clone/Temp"
# Vendor scripts may not compile without their packages; they are not needed. Delete them
# BEFORE copying GodotExport.cs (Pure Village run: every Assets/**/*.cs and *.asmdef).
find "$SCRATCH/unity_clone/Assets/<packs>" -name '*.cs*' -delete
mkdir -p "$SCRATCH/unity_clone/Assets/Editor" && cp GodotExport.cs "$SCRATCH/unity_clone/Assets/Editor/"
GODOT_EXPORT_OUT="$SCRATCH/stage" /Applications/Unity/Hub/Editor/<ver>/Unity.app/Contents/MacOS/Unity \
  -batchmode -nographics -quit -projectPath "$SCRATCH/unity_clone" -executeMethod GodotExport.Run -logFile export.log
python3 process_textures.py "$SCRATCH/unity_clone" "$SCRATCH/stage"   # needs Pillow + numpy; uses macOS sips for TIF/PSD
python3 finalize.py "$SCRATCH/unity_clone" "$SCRATCH/stage"            # audio, vendor docs, READMEs (pack-specific)
```

`GodotExport.Packs`, its `Excluded` folder list and `finalize.PACKS` name the packs;
edit them for a new purchase. `GODOT_EXPORT_PACKS=PureVillage` limits a run to those pack
outNames (`finalize.py` then only writes READMEs for packs present in the staging tree);
`GODOT_EXPORT_ONLY=a,b` limits export to matching paths. The first batch run on a fresh clone
reimports the whole project (about 45 minutes for this project); later runs take minutes.

Conversion rules:
- Unity is left-handed; positions/normals negate X, rotations become (x,-y,-z,w),
  winding flips and UV V flips. Godot imports the result like any glTF.
- LOD0 only (Godot builds LODs). Colliders, lights, particles, scripts are dropped.
- Skinned models keep the skeleton; animation clips found in the prefab's Animator or
  in the pack whose transform paths match the rig are sampled at ≤30 fps.
- Materials become glTF PBR approximating each vendor shader: albedo × tint, normal,
  alpha cut-out, ORM (Polyart), repacked metallic-smoothness (Suntail `ms`/`aa`,
  ANGRY MESH `smae`, URP Lit / BK Standard Layered `mos` = metallic R, occlusion G, smoothness A), and emission only when a map or emission keyword enables it.
  Textures are referenced by relative URI, not embedded.

Large packs: cap textures at 2048 px and drop duplicate model sets before copying into
`assets/`, then run one headless `--import` before opening the editor. Pure Village at 4096 px
(3.8 GB) ran the 16 GB editor out of memory; at 2048 px it imports with a 2.6 GB peak.
