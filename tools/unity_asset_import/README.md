# Unity Asset Store → Godot conversion

Converts purchased Unity packages (prefabs, `.mat`, FBX, Unity mesh assets) into
self-contained `.glb` models plus shared PNG textures under `assets/<Pack>/`.
Used on 2026-09-23 for Raygeas Suntail Village, Polyart Farmlands/Dreamscape Castle and
ANGRY MESH Meadow Environment. See each pack's `assets/<Pack>/README.md`.

Unity itself resolves prefabs, nested prefabs, material overrides and FBX import
settings, so the conversion runs inside Unity batch mode on an APFS clone of the
Unity project (the original project may stay open):

```bash
cp -Rc "<unity project>" "$SCRATCH/unity_clone" && rm -rf "$SCRATCH/unity_clone/Temp"
# Vendor editor scripts may not compile without their packages; they are not needed.
find "$SCRATCH/unity_clone/Assets/<packs>" -name '*.cs*' -delete
mkdir -p "$SCRATCH/unity_clone/Assets/Editor" && cp GodotExport.cs "$SCRATCH/unity_clone/Assets/Editor/"
GODOT_EXPORT_OUT="$SCRATCH/stage" /Applications/Unity/Hub/Editor/<ver>/Unity.app/Contents/MacOS/Unity \
  -batchmode -nographics -quit -projectPath "$SCRATCH/unity_clone" -executeMethod GodotExport.Run -logFile export.log
python3 process_textures.py "$SCRATCH/unity_clone" "$SCRATCH/stage"   # needs Pillow + numpy; uses macOS sips for TIF/PSD
python3 finalize.py "$SCRATCH/unity_clone" "$SCRATCH/stage"            # audio, vendor docs, READMEs (pack-specific)
```

`GodotExport.Packs`, its `Excluded` folder list and `finalize.PACKS` name the packs;
edit them for a new purchase. `GODOT_EXPORT_ONLY=a,b` limits export to matching paths.

Conversion rules:
- Unity is left-handed; positions/normals negate X, rotations become (x,-y,-z,w),
  winding flips and UV V flips. Godot imports the result like any glTF.
- LOD0 only (Godot builds LODs). Colliders, lights, particles, scripts are dropped.
- Skinned models keep the skeleton; animation clips found in the prefab's Animator or
  in the pack whose transform paths match the rig are sampled at ≤30 fps.
- Materials become glTF PBR approximating each vendor shader: albedo × tint, normal,
  alpha cut-out, ORM (Polyart), repacked metallic-smoothness (Suntail `ms`/`aa`,
  ANGRY MESH `smae`), and emission only when a map or emission keyword enables it.
  Textures are referenced by relative URI, not embedded.
