# Tree Imposters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw distant trees as baked camera-facing imposters (a few triangles each) instead of 4-17k-triangle meshes, crossfading at a measured distance, with every tree (including future manifest additions) getting one automatically at bake time.

**Architecture:**
- **Bake:** the environment bake tool gains an imposter pass. For every asset tagged `tree`, it renders the baked visual from 8 azimuths in a windowed SubViewport. Each view writes an albedo+alpha frame, a normal frame, and a tint-response mask (two captures at different instance tints). The frames are packed into atlases saved as `PortableCompressedTexture2D`, and an `EnvironmentImposter` resource is referenced from the asset's `EnvironmentVisual` (so the orphan prune keeps it).
- **Runtime:** `EnvironmentCommitQueue` gives each 48 m tree tile batch a child imposter `MultiMeshInstance3D` sharing its transforms and colours. The near batch ends and the imposter begins at `IMPOSTER_DISTANCE`, with `VISIBILITY_RANGE_FADE_SELF` margins.
- **Shader:** `tree_imposter.gdshader` billboards a quad around the vertical axis, picks and blends the two nearest azimuth frames from the camera direction in instance space, and applies instance tint through the baked mask.

**Tech Stack:** Godot 4.5.1 .NET, typed GDScript, the bake tool (`tools/environment_bake/environment_bake.gd`, `extends SceneTree`), GUT.

**Spec:** the owner's question (2026-10-07): "if we add a cheap imposter for trees at a distance, will it work with new trees when we add them?". The answer and design are in this plan's Architecture section. The tree rendering constraints come from `AGENTS.md` ("October 5 nature style", the leaf LOD and shadow notes).

## Global Constraints

- Every asset tagged `tree` in any manifest gets an imposter from the same bake run. No per-asset authoring, and no manifest flag needed.
- Imposter resources live under `res://terrain/environment/` and must be reachable from the visual, or `_prune_generated_orphans` (environment_bake.gd:2648) deletes them. Nothing may depend on `res://assets/` (test_environment_catalog.gd:52-80).
- Descriptors stay lightweight. No Mesh, Material or Texture goes on `EnvironmentAssetDescriptor` (test_environment_catalog.gd:25-37); imposter data goes on `EnvironmentVisual`.
- The leaf LOD system, the leaf shadow proxy and `painted_leaf.gdshader` keep their current behaviour near the camera. Imposters only replace drawing beyond `IMPOSTER_DISTANCE`.
- Imposters cast no shadow (sun shadows end at 60 m, `AtmosphereDirector.SUN_SHADOW_DISTANCE`).
- The bake's imposter pass needs a real renderer. It refuses to run under `--headless` with a clear error. The existing headless bake of meshes, collisions and LODs keeps working with the pass off.
- Seasons are separate assets (`meadow.<kind>.<nn>.<season>`), so each gets its own imposter. Biome tint is applied at runtime from instance colour, as for meshes.
- New first-use materials go through `RenderWarmup` so the first imposter does not stall on pipeline compilation.
- Profile under the .NET binary. Do not push or move `main`.

## Review Focus

- **Capturing the painted leaf shader:**
  - An orthographic camera trips the shader's shadow-pass branch (`PROJECTION_MATRIX[3][3] > 0.5`), which thins the cards or kills them all (`cascade_kill` when the width is over 30 m).
  - A low `leaf_lod_camera` thins cards.
  - Task 2 tests that a capture keeps ≥ 98% of the full-detail alpha coverage.
- **Crossfade pop at the switch distance.** Task 5 captures a dolly through the switch and compares silhouette coverage (within 10%, the same bar as the leaf LOD dolly).
- **Tinted autumn and winter trees.** The runtime tint must reproduce the mesh's tinted colour at the switch. Task 5 compares mean colour of the crown region near and far side of the crossfade (ΔE under a set bound).
- **The tactical camera.** It looks down steeply, so a vertical-axis billboard seen from above is a thin card. Task 4 adds a top-down fallback: blend to a crown-disc frame by camera elevation.
- **Re-baking without imposters (headless).** The visual must keep a previously baked imposter, not drop it. Otherwise a headless re-bake silently removes every imposter. Task 1 tests this.

---

## File Structure

- Create `scripts/terrain/environment/model/EnvironmentImposter.gd`: a `Resource` with `albedo: Texture2D`, `normal: Texture2D`, `frames: int`, `size: Vector2` (world width and height of a frame), `pivot_height: float`, `crown_centre: Vector3`.
- Modify `scripts/terrain/environment/model/EnvironmentVisual.gd`: add `@export var imposter: EnvironmentImposter`.
- Create `tools/environment_bake/imposter_capture.gd`: a `RefCounted` that renders one visual's frames in a SubViewport and returns an `EnvironmentImposter`.
- Modify `tools/environment_bake/environment_bake.gd`:
  - `_run` becomes a coroutine (awaits frames);
  - `--imposters` flag;
  - the per-asset imposter step after the visual is saved;
  - keep the existing imposter when the pass is off.
- Create `terrain/environment/materials/tree_imposter.gdshader`.
- Modify `scripts/terrain/environment/EnvironmentCommitQueue.gd`: `IMPOSTER_DISTANCE`, `IMPOSTER_FADE`; `_attach_imposter()` beside `_attach_shadow_proxy()`; ranges on the near batch.
- Modify `scripts/terrain/environment/RenderWarmup.gd`: warm the imposter material.
- Tests: create `tests/test_tree_imposters.gd`; extend `tests/test_dressing_commit_queue.gd`.
- Harness: create `tests/harness/imposter_review.gd` (windowed) for dolly captures and colour checks.

---

### Task 1: The imposter resource, kept across re-bakes

**Files:**
- Create: `scripts/terrain/environment/model/EnvironmentImposter.gd`
- Modify: `scripts/terrain/environment/model/EnvironmentVisual.gd`
- Modify: `tools/environment_bake/environment_bake.gd:637-641` (where the visual is saved)
- Test: `tests/test_tree_imposters.gd`

**Interfaces:**
- Produces:

```gdscript
class_name EnvironmentImposter
extends Resource
## Baked distant-tree card set: `frames` azimuth views side by side in each atlas.
@export var albedo: Texture2D            # RGB albedo under white instance tint, A coverage
@export var normal: Texture2D            # RGB view-space normal * 0.5 + 0.5, A tint response
@export var frames: int = 8
@export var size: Vector2 = Vector2.ONE  # world metres covered by one frame (width, height)
@export var pivot_height: float = 0.0    # metres from the asset origin to the frame's bottom edge
@export var crown_centre: Vector3 = Vector3.ZERO
```

- `EnvironmentVisual.imposter: EnvironmentImposter` (null for non-trees).
- `environment_bake.gd`: `static func _carry_imposter(path: String, visual: EnvironmentVisual) -> void` copies `imposter` from the visual already on disk at `path` when the new visual has none.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

const BAKE := preload("res://tools/environment_bake/environment_bake.gd")

func test_visual_carries_an_optional_imposter() -> void:
	var visual := EnvironmentVisual.new()
	assert_null(visual.imposter)
	visual.imposter = EnvironmentImposter.new()
	assert_eq(visual.imposter.frames, 8)

func test_a_rebake_without_the_pass_keeps_the_baked_imposter() -> void:
	var dir := "user://imposter_carry_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/visual.tres"
	var old := EnvironmentVisual.new()
	old.imposter = EnvironmentImposter.new()
	old.imposter.frames = 6
	ResourceSaver.save(old, path)
	var fresh := EnvironmentVisual.new()
	BAKE._carry_imposter(path, fresh)
	assert_not_null(fresh.imposter, "a headless re-bake must not drop every imposter")
	assert_eq(fresh.imposter.frames, 6)
```

- [ ] **Step 2: Run to verify it fails**

Run: `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_tree_imposters.gd -gexit`
Expected: FAIL (`EnvironmentImposter` is unknown). After creating the `class_name` script, run `godot --headless --path . --import` once (AGENTS.md: class cache).

- [ ] **Step 3: Implement**

- Create the resource above.
- Add `@export var imposter: EnvironmentImposter` to `EnvironmentVisual.gd`.
- In `environment_bake.gd`, add:

```gdscript
static func _carry_imposter(path: String, visual: EnvironmentVisual) -> void:
	if visual.imposter != null or not ResourceLoader.exists(path):
		return
	var previous := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EnvironmentVisual
	if previous != null:
		visual.imposter = previous.imposter
```

  Call `_carry_imposter(visual_path, visual)` right before the visual is saved (line ~637).

- [ ] **Step 4: Run** the Step 2 command, plus `tests/test_environment_catalog.gd`. Expect PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/environment/model/EnvironmentImposter.gd scripts/terrain/environment/model/EnvironmentVisual.gd tools/environment_bake/environment_bake.gd tests/test_tree_imposters.gd
git commit -m "EnvironmentImposter resource on the visual, kept across re-bakes"
```

---

### Task 2: Capture a visual's frames (windowed)

**Files:**
- Create: `tools/environment_bake/imposter_capture.gd`
- Test: `tests/test_tree_imposters.gd` (GPU tests skip under headless, like `tests/test_september27_rock_substrate_gpu.gd:144`)

**Interfaces:**
- Consumes: `EnvironmentVisual`, `EnvironmentImposter` (Task 1).
- Produces:

```gdscript
## Renders `visual` from FRAMES azimuths and returns the imposter (textures in
## memory; the caller saves them). Main thread; needs a real renderer.
static func capture(tree: SceneTree, visual: EnvironmentVisual, frame_px: int = 256) -> EnvironmentImposter
const FRAMES := 8
```

- Capture rules (each one prevents a known shader trap):
  - **Perspective camera.** Use a narrow FOV (`fov = 4.0`), placed at `distance = 0.5 * max(size) / tan(deg_to_rad(2.0))` along each azimuth at elevation 0, aimed at the AABB centre. The painted-leaf shader treats any orthographic projection as the sun shadow pass and thins or kills the cards (painted_leaf.gdshader:55-58).
  - **Full-detail leaves.** `RenderingServer.global_shader_parameter_set(&"leaf_lod_camera", Vector4(eye.x, eye.y, eye.z, 0.0001))` (a tiny metres-per-pixel keeps every card), and `viewport.mesh_lod_threshold = 0.0`. Restore the previous `leaf_lod_camera` value afterwards.
  - **Unlit albedo.** `viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED`, `transparent_bg = true`.
  - **Normals.** A second render with `viewport.debug_draw = Viewport.DEBUG_DRAW_NORMAL_BUFFER`. Its RGB goes into the normal atlas.
  - **Tint response.** Draw the visual with a MultiMesh of one instance (the runtime path, `use_colors = piece.use_instance_color`). Capture albedo once with instance colour `Color.WHITE` and once with `Color(0.5, 0.5, 0.5)`. Per pixel, `response = clamp((white - grey) / max(white, 1e-3) * 2.0, 0, 1)` (luminance), stored in the normal atlas alpha. 1 means the texel scales fully with tint (leaves), 0 means it ignores tint (bark).
  - **Frame size.** `size = Vector2(max(aabb.size.x, aabb.size.z) * 1.05, aabb.size.y * 1.05)`, `pivot_height = aabb.position.y`.
  - **Readback.** Await 5 `process_frame`s and then `RenderingServer.frame_post_draw` per render, then `viewport.get_texture().get_image()`. This is the pattern in `tests/test_september27_rock_substrate_gpu.gd:40-58`.
  - **Atlases.** Two `Image`s, `frame_px * FRAMES` × `frame_px`, `FORMAT_RGBA8`, filled with `blit_rect`. Then `fix_alpha_edges()` on the albedo to prevent dark halos when mipmapped, `generate_mipmaps()`, and wrap each in `ImageTexture` (saving is the caller's job).

- [ ] **Step 1: Write the failing GPU test**

```gdscript
func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

func test_capture_keeps_full_crowns_and_tints_only_leaves() -> void:
	if _headless():
		pass_test("needs a renderer")
		return
	const CAPTURE := preload("res://tools/environment_bake/imposter_capture.gd")
	var visual := load("res://terrain/environment/visuals/angry_mesh_meadow/meadow_oak_01_summer.tres") as EnvironmentVisual
	var imposter: EnvironmentImposter = await CAPTURE.capture(get_tree(), visual, 128)
	assert_eq(imposter.frames, 8)
	var albedo := imposter.albedo.get_image()
	var normal := imposter.normal.get_image()
	assert_eq(albedo.get_width(), 128 * 8)
	# Coverage in every frame: a thinned or killed crown shows up here.
	for f in 8:
		var covered := 0
		for y in range(0, 128, 2):
			for x in range(0, 128, 2):
				if albedo.get_pixel(f * 128 + x, y).a > 0.5: covered += 1
		assert_gt(covered, 600, "frame %d keeps its crown (no shadow-pass thinning)" % f)
	# Leaves respond to tint, the trunk base does not.
	var leaf := normal.get_pixel(64, 30).a      # upper crown
	var trunk := normal.get_pixel(64, 124).a    # bottom centre
	assert_gt(leaf, 0.6)
	assert_lt(trunk, 0.3)
```

- [ ] **Step 2: Run windowed to verify it fails**

Run: `/Applications/Godot_mono.app/Contents/MacOS/Godot -d --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_tree_imposters.gd -gexit` (no `--headless`).
Expected: FAIL (`imposter_capture.gd` is missing).

- [ ] **Step 3: Implement `imposter_capture.gd`** following the rules above. Skeleton:

```gdscript
extends RefCounted
const FRAMES := 8

static func capture(tree: SceneTree, visual: EnvironmentVisual, frame_px: int = 256) -> EnvironmentImposter:
	assert(DisplayServer.get_name() != "headless", "imposter capture needs a renderer (run the bake without --headless)")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(frame_px, frame_px)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.mesh_lod_threshold = 0.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var holder := Node3D.new()
	viewport.add_child(holder)
	var instance := _instance(visual)              # MultiMeshInstance3D, 1 instance, every piece as a child
	holder.add_child(instance)
	var aabb := _aabb(visual)
	var camera := Camera3D.new()
	camera.fov = 4.0
	viewport.add_child(camera)
	camera.current = true
	var albedo := Image.create(frame_px * FRAMES, frame_px, false, Image.FORMAT_RGBA8)
	var normal := Image.create(frame_px * FRAMES, frame_px, false, Image.FORMAT_RGBA8)
	var saved_lod: Variant = RenderingServer.global_shader_parameter_get(&"leaf_lod_camera")
	var size := Vector2(maxf(aabb.size.x, aabb.size.z), aabb.size.y) * 1.05
	var distance := 0.5 * maxf(size.x, size.y) / tan(deg_to_rad(2.0))
	for f in FRAMES:
		var azimuth := TAU * float(f) / float(FRAMES)
		var centre := aabb.get_center()
		camera.position = centre + Vector3(sin(azimuth), 0.0, cos(azimuth)) * distance
		camera.look_at(centre, Vector3.UP)
		camera.far = distance * 2.0
		RenderingServer.global_shader_parameter_set(&"leaf_lod_camera",
			Vector4(camera.position.x, camera.position.y, camera.position.z, 0.0001))
		var white: Image = await _render(tree, viewport, instance, Color.WHITE, Viewport.DEBUG_DRAW_UNSHADED)
		var grey: Image = await _render(tree, viewport, instance, Color(0.5, 0.5, 0.5), Viewport.DEBUG_DRAW_UNSHADED)
		var normals: Image = await _render(tree, viewport, instance, Color.WHITE, Viewport.DEBUG_DRAW_NORMAL_BUFFER)
		for y in frame_px:
			for x in frame_px:
				var w := white.get_pixel(x, y)
				var g := grey.get_pixel(x, y)
				var lw := w.get_luminance()
				var response := clampf((lw - g.get_luminance()) / maxf(lw, 0.001) * 2.0, 0.0, 1.0)
				albedo.set_pixel(f * frame_px + x, y, w)
				var n := normals.get_pixel(x, y)
				normal.set_pixel(f * frame_px + x, y, Color(n.r, n.g, n.b, response))
	RenderingServer.global_shader_parameter_set(&"leaf_lod_camera", saved_lod)
	viewport.queue_free()
	albedo.fix_alpha_edges()
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	var out := EnvironmentImposter.new()
	out.albedo = ImageTexture.create_from_image(albedo)
	out.normal = ImageTexture.create_from_image(normal)
	out.frames = FRAMES
	out.size = size
	out.pivot_height = aabb.position.y
	out.crown_centre = aabb.get_center()
	return out
```

  Implement `_instance` by mirroring `EnvironmentCommitQueue._commit_batch`: one `MultiMeshInstance3D` per piece, with `mesh = piece.mesh`, `use_colors = piece.use_instance_color`, `material_override = piece.material_override`, and instance transform `piece.local_transform`.
  Implement `_aabb` as the union of `piece.local_transform * piece.mesh.get_aabb()`.
  Implement `_render`: set the instance colour on every child MultiMesh, set `viewport.debug_draw`, await 5 `process_frame`s plus `RenderingServer.frame_post_draw`, then return `viewport.get_texture().get_image()`.

- [ ] **Step 4: Run the Step 2 command.** Expect PASS. Save the atlas PNGs to `/private/tmp/imposter-oak/` and look at them: all 8 frames should show full crowns with no thinning and no dark rims.

- [ ] **Step 5: Commit**

```bash
git add tools/environment_bake/imposter_capture.gd tests/test_tree_imposters.gd
git commit -m "Imposter capture: 8 azimuth frames, normals, tint response from the real tree material"
```

---

### Task 3: Bake imposters for every tree

**Files:**
- Modify: `tools/environment_bake/environment_bake.gd` (`_run` 39-62 becomes async; `_requested_manifests` parses `--imposters`; the per-asset step after the visual save; texture saving through the `_bake_texture` pattern 2524-2565)
- Test: `tests/test_tree_imposters.gd`

**Interfaces:**
- Consumes: `imposter_capture.capture` (Task 2), `_carry_imposter` (Task 1).
- Produces:
  - Texture paths `res://terrain/environment/textures/<pack>/imposter_<asset_slug>_albedo.res` and `_normal.res` (`PortableCompressedTexture2D`, lossless, `keep_compressed_buffer`).
  - `visual.imposter` saved inside the visual `.tres`, which keeps the textures reachable for the prune.
  - Command: `/Applications/Godot_mono.app/Contents/MacOS/Godot --path . -s res://tools/environment_bake/environment_bake.gd -- --manifest res://tools/environment_bake/manifests/angry_mesh_meadow_nature.json --imposters`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_every_baked_tree_has_an_imposter_inside_the_environment_tree() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var missing: Array[String] = []
	for id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(id)
		if not descriptor.tags.has(&"tree"):
			continue
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		if visual.imposter == null or visual.imposter.albedo == null:
			missing.append(String(id))
			continue
		assert_true(visual.imposter.albedo.resource_path.begins_with("res://terrain/environment/"))
	assert_eq(missing, [], "trees without an imposter (run the bake with --imposters)")
```

  Check the `EnvironmentCatalog` accessor names in `scripts/terrain/environment/EnvironmentCatalog.gd` and use the real ones.

- [ ] **Step 2: Run to verify it fails.** Expected: every tree is listed as missing.

- [ ] **Step 3: Implement**

- `_run`: `await` each `_bake_manifest`, and make `_bake_manifest` / `_bake_asset` coroutines. Under `--imposters`, `_bake_asset` (after the visual is built and before it is saved) does:

```gdscript
	if _imposters and (entry.tags as Array).has("tree"):
		var imposter: EnvironmentImposter = await IMPOSTER.capture(self, visual)
		imposter.albedo = _save_imposter_texture(pack, asset_slug + "_albedo", imposter.albedo.get_image())
		imposter.normal = _save_imposter_texture(pack, asset_slug + "_normal", imposter.normal.get_image())
		visual.imposter = imposter
```

- `_save_imposter_texture` follows `_bake_texture`'s save: `PortableCompressedTexture2D.create_from_image(image, COMPRESSION_MODE_LOSSLESS)`, `keep_compressed_buffer = true`, `ResourceSaver.save` to the path above, then `load` it back (`CACHE_MODE_REPLACE`).
- Under `--headless` with `--imposters`, print an error and `quit(1)` before baking anything.
- Without `--imposters`, `_carry_imposter` keeps the existing one.
- Bump `TOOL_VERSION`.
- Run the bake for every manifest that has trees: `angry_mesh_meadow_nature.json`, `polyart_farmlands_nature.json`, `kaykit.json`, `low_poly_fantasy_village_nature.json`.

- [ ] **Step 4: Run** `test_tree_imposters.gd` (headless; the catalog test does not need a renderer) and `test_environment_catalog.gd`. Expect PASS. Check that `git status` shows the new textures under `terrain/environment/textures/` and no deletions of existing outputs.

- [ ] **Step 5: Commit**

```bash
git add tools/environment_bake/environment_bake.gd terrain/environment tests/test_tree_imposters.gd tools/environment_bake/provenance
git commit -m "Bake: every tree gets an imposter (--imposters, windowed); re-bakes keep them"
```

---

### Task 4: The imposter shader

**Files:**
- Create: `terrain/environment/materials/tree_imposter.gdshader`
- Test: `tests/test_tree_imposters.gd`

**Interfaces:**
- Uniforms: `albedo_atlas`, `normal_atlas`, `frames: int`, `frame_size: vec2`, `pivot_height: float`, `alpha_cut: float = 0.5`.
- Mesh: a unit quad (`QuadMesh`, size 1×1, centred) supplied by the commit queue (Task 5).
- Instance data:
  - `COLOR.rgb` is the biome tint, as the leaf shader reads it;
  - `INSTANCE_CUSTOM` keeps the tactical owner footprint (EnvironmentCommitQueue.gd:152-154), so the shader must not use it.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_imposter_shader_billboards_blends_frames_and_tints_by_response() -> void:
	var code := (load("res://terrain/environment/materials/tree_imposter.gdshader") as Shader).code
	for needle in ["render_mode", "cull_disabled", "ALPHA_SCISSOR_THRESHOLD", "MODEL_MATRIX",
			"frames", "normal_atlas", "COLOR.rgb", "mix(vec3(1.0), COLOR.rgb"]:
		assert_true(code.contains(needle), "imposter shader: " + needle)
	assert_false(code.contains("INSTANCE_CUSTOM"), "custom data carries the tactical footprint")
```

- [ ] **Step 2: Run to verify it fails** (the file is missing).

- [ ] **Step 3: Implement**

```glsl
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap;
uniform sampler2D normal_atlas : filter_linear_mipmap;
uniform int frames = 8;
uniform vec2 frame_size = vec2(1.0);
uniform float pivot_height = 0.0;
uniform float alpha_cut = 0.5;

varying vec2 frame_uv;
varying float frame_a;
varying float frame_b;
varying float blend;
varying vec3 tint;

void vertex() {
	// Billboard about the instance's vertical axis, sized to the baked frame.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 to_camera = CAMERA_POSITION_WORLD - origin;
	vec2 flat_dir = normalize(to_camera.xz + vec2(1e-5, 0.0));
	vec3 right = vec3(flat_dir.y, 0.0, -flat_dir.x);
	vec3 world = origin + right * VERTEX.x * frame_size.x * scale
		+ vec3(0.0, (VERTEX.y + 0.5) * frame_size.y * scale + pivot_height * scale, 0.0);
	// Azimuth of the camera in the instance's own frame picks two frames.
	vec3 local_dir = normalize((inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz);
	float az = atan(local_dir.x, local_dir.z);
	float f = fract(az / TAU) * float(frames);
	frame_a = floor(f);
	frame_b = mod(frame_a + 1.0, float(frames));
	blend = f - frame_a;
	frame_uv = vec2(VERTEX.x + 0.5, 0.5 - VERTEX.y);
	tint = COLOR.rgb;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	NORMAL = (VIEW_MATRIX * vec4(flat_dir.x, 0.0, flat_dir.y, 0.0)).xyz;
}

vec4 sample_frame(sampler2D atlas, float frame) {
	return texture(atlas, vec2((frame + frame_uv.x) / float(frames), frame_uv.y));
}

void fragment() {
	vec4 a = mix(sample_frame(albedo_atlas, frame_a), sample_frame(albedo_atlas, frame_b), blend);
	vec4 n = mix(sample_frame(normal_atlas, frame_a), sample_frame(normal_atlas, frame_b), blend);
	ALBEDO = a.rgb * mix(vec3(1.0), COLOR.rgb, n.a);
	NORMAL = normalize(n.rgb * 2.0 - 1.0);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
```

  Notes:
  - `COLOR` in `fragment()` is the interpolated instance colour. The `tint` varying is kept for clarity, but the test pins `COLOR.rgb`.
  - **Top-down fallback (Review Focus).** When the camera elevation above the instance exceeds 60°, fade alpha to 0 over 60-75°. Fill in the parameters in Task 5 after the dolly capture shows whether it is needed.

- [ ] **Step 4: Run.** Expect PASS.

- [ ] **Step 5: Commit**

```bash
git add terrain/environment/materials/tree_imposter.gdshader tests/test_tree_imposters.gd
git commit -m "Tree imposter shader: vertical billboard, two-frame blend, tint by baked response"
```

---

### Task 5: Draw imposters beyond the switch distance

**Files:**
- Modify: `scripts/terrain/environment/EnvironmentCommitQueue.gd:111-125` (ranges) and `127-206` (`_commit_batch`; add `_attach_imposter` next to `_attach_shadow_proxy`)
- Modify: `scripts/terrain/environment/RenderWarmup.gd:1-30`
- Test: `tests/test_dressing_commit_queue.gd`
- Create: `tests/harness/imposter_review.gd`

**Interfaces:**
- Consumes: `EnvironmentVisual.imposter` (Task 1), `tree_imposter.gdshader` (Task 4).
- Produces: `const IMPOSTER_DISTANCE := 140.0` (initial; tuned in Step 4) and `const IMPOSTER_FADE := 12.0` in `EnvironmentCommitQueue`. The imposter is a child `MultiMeshInstance3D` named `Imposter` of the tile batch instance, so child order under `Dressing` is unchanged (test_dressing_commit_queue.gd:144).

- [ ] **Step 1: Write the failing test**

```gdscript
func test_tree_batches_hand_over_to_an_imposter_child() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := EnvironmentCommitQueue.new(cache, &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"meadow.oak.01.summer", Transform3D(Basis(), Vector3(5, 0, 5)), Color(0.9, 0.8, 0.6))
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	queue.drain(64)
	var near := parent.get_node("Dressing").get_child(0) as MultiMeshInstance3D
	var imposter := near.get_node("Imposter") as MultiMeshInstance3D
	assert_not_null(imposter)
	assert_eq(near.visibility_range_end, EnvironmentCommitQueue.IMPOSTER_DISTANCE)
	assert_eq(imposter.visibility_range_begin, EnvironmentCommitQueue.IMPOSTER_DISTANCE)
	assert_eq(near.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
	assert_eq(imposter.multimesh.instance_count, near.multimesh.instance_count)
	assert_eq(imposter.multimesh.get_instance_transform(0), near.multimesh.get_instance_transform(0))
	assert_eq(imposter.multimesh.get_instance_color(0), near.multimesh.get_instance_color(0))
	assert_eq(imposter.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
```

  Match the `drain` / `register_chunk` call shapes to the existing tests in this file.

- [ ] **Step 2: Run to verify it fails** (no Imposter child).

- [ ] **Step 3: Implement**

In `_commit_batch`, after the near instance is built and only when `visual.imposter != null`:
- Set on the near instance: `visibility_range_end = IMPOSTER_DISTANCE`, `visibility_range_end_margin = IMPOSTER_FADE`, `visibility_range_fade_mode = VISIBILITY_RANGE_FADE_SELF`.
- Call `_attach_imposter(instance, visual.imposter)`. It builds a MultiMesh with:
  - `mesh = _imposter_quad` (one shared `QuadMesh`, `size = Vector2.ONE`);
  - the same `instance_count`, transforms, colours and custom data as the near batch;
  - `use_colors = true`, `use_custom_data = true`;
  - `material_override` = one `ShaderMaterial` per imposter, cached in a Dictionary keyed by the imposter resource;
  - `cast_shadow = OFF`, `visibility_range_begin = IMPOSTER_DISTANCE`, `visibility_range_begin_margin = IMPOSTER_FADE`, `visibility_range_fade_mode = FADE_SELF`, plus the same `tactical_owner_footprints` meta and group `tactical_preserve_surface`.
- Add a `custom_aabb` grown by `imposter.size` so the culling bounds cover the billboard.
- The `LeafShadow` child needs no range: shadows end at 60 m.

In `RenderWarmup`, for every prepared visual with an imposter, warm one MultiMesh using the imposter quad and material.

- [ ] **Step 4: Tune the switch distance by measurement**

Create `tests/harness/imposter_review.gd`, a windowed `SceneTree` script. It:
- streams a fixed forest site through the real world pipeline (copy the setup of `tests/harness/profile_chunk_commit.gd`);
- dollies the camera from 60 m to 300 m away from a tree line in 10 m steps;
- saves a PNG per step;
- reports per step the crown-region alpha coverage and mean RGB with imposters on vs off (`EnvironmentCommitQueue.IMPOSTER_DISTANCE` as a static var set to 1e6 for "off").

Pass bars:
- coverage within 10% at every step;
- mean crown colour ΔE < 6 at the switch;
- the feel harness `run_turn` dt p95 in a forest (`--x/--z` at a deep_forest site) improves, with prims reported.

Try 100, 140 and 180 m and keep the smallest distance that passes. Record the results in `docs/qa/2026-10-07-tree-imposters/result.md` with the images.

- [ ] **Step 5: Run** `test_dressing_commit_queue.gd`, `test_canopy_shadows.gd` and `test_environment_catalog.gd`. Expect PASS. Then commit:

```bash
git add scripts/terrain/environment/EnvironmentCommitQueue.gd scripts/terrain/environment/RenderWarmup.gd tests/test_dressing_commit_queue.gd tests/harness/imposter_review.gd docs/qa/2026-10-07-tree-imposters/result.md
git commit -m "Trees hand over to baked imposters beyond <D> m (crossfade, warmed, measured)"
```

---

### Task 6: Document

- [ ] Add to `AGENTS.md`, under the nature paragraph:
  - imposters are baked for every `tree` asset by `environment_bake.gd --imposters` (windowed);
  - a headless re-bake keeps them;
  - the runtime switch is at `EnvironmentCommitQueue.IMPOSTER_DISTANCE` with `FADE_SELF`;
  - the capture rules (perspective, full leaf LOD, unshaded, tint response).
- [ ] Commit: `git commit -am "AGENTS: tree imposters"`.
