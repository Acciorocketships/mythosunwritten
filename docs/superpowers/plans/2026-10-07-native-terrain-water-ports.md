# Native (C#) Terrain, River, Water-Fill and Cliff-Sheet Ports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut cold world generation (the freezes when the player outruns streaming, startup, grass fill-in) by porting the four hottest GDScript workloads to C#:
1. the terrain tile kernel;
2. river tracing and carving;
3. the water fill solver;
4. the cliff sheet builder.

Each port is bit-identical to the GDScript it replaces.

**Architecture:** Every port follows the pattern `NativeHeightField` / `NativeGridKernels` already established (`scripts/native/`):
- **The GDScript stays the reference.** A `scripts/native/NativeX.gd` loader (no `class_name`; callers `preload` it) loads `NativeX.cs` only when `ClassDB.class_exists(&"CSharpScript")`.
- **Parity gate.** The loader runs a deterministic parity check on first use. It sets `enabled = true` only when every compared value is bit-identical (`!=` on packed arrays). Otherwise it `push_warning`s naming the files to re-sync.
- **Dispatch.** Call sites branch on `enabled`.
- **Batch calls.** Calls marshal whole packed arrays per batch, never per sample: GDScript→C# calls cost microseconds and copy arrays.
- **Purity.** C# code is stateless or uses `[ThreadStatic]` scratch, because chunk tails run on the thread pool.

**Tech Stack:** Godot 4.5.1 .NET (`/Applications/Godot_mono.app/Contents/MacOS/Godot`), C# net8.0 (`Story.csproj` compiles `scripts/native/**/*.cs`; build with `dotnet build Story.csproj`), typed GDScript, GUT.

**Spec:** the owner's request (2026-10-07): "lets do all of them" for the C# list:
1. the tile kernel;
2. river tracing;
3. the water fill solver;
4. the cliff sheet builder.

Profiles in `AGENTS.md` (October 7 entry). Cold water block (-4,-5): 59 s under .NET. Its breakdown:
- seeds/profiles 16-19 s;
- terrain region 10-15 s, mostly river walks and `carve_at`;
- fine rescue 9 s;
- spill 6 s;
- ground 4-5 s;
- cap 4 s.

A cliffy chunk spends ~31 s in cliff dressing (slope_init 11.5, add_skirts 6.7, solid 4.4). `TerrainTileField.surface_y_on_side` was the most-called function in a profile (1.7M calls).

## Global Constraints

- **Bit-identical or off.** A native path is enabled only after its parity gate passes, compared exactly (`!=`, never `almost_eq`). GDScript remains the reference and the fallback under the standard (non-.NET) editor.
- **Mirror GDScript numerics.** Follow `scripts/native/GdMath.cs` rules:
  - GDScript `float` is double, `int` is int64 with wrapping arithmetic;
  - `Vector2`/`Vector3` arithmetic is float32 without FMA (use `V2`);
  - `PackedFloat32Array` stores round to float32;
  - `lerpf` / `clampf` / `minf` / `maxf` / `smoothstep` / `SlopeProfile.smootherstep` exactly as `GdMath.Lerp` / `Clamp` / `Min` / `Max` / `Smoothstep` / `Smootherstep`;
  - `roundf` rounds half away from zero.
- **No per-sample marshalling.** Native entry points take and return whole arrays (`double[]`, `float[]`, `int[]`, `byte[]`, `Vector2[]`).
- **Thread safety.** No shared mutable statics in C# except `ConcurrentDictionary` caches keyed by immutable inputs. Scratch is `[ThreadStatic]`.
- **No scene work off the main thread** (AGENTS.md purity boundary). C# here is pure computation.
- **Cold planning cache.** Every `.cs`/`.gd` under `scripts/native/` and the edited terrain/water files are `PlanningDiskCache.KEY_SOURCES`, so each commit forces one cold planning run per seed. Budget for it; use `tests/harness/water_block_cost.gd --no-disk`.
- **Identity harnesses must stay identical before and after each dispatch switch:**
  - `profile_mesh_phases.gd --hash-out/--hash-check` (chunk payloads);
  - `water_block_cost.gd --no-disk` (digest);
  - `parallel_tail_check.gd` (thread safety).
- Profile under `Godot_mono`. One heavy Godot process at a time. Do not push or move `main`.
- After any `class_name` change, run `godot --headless --path . --import`.

## Review Focus

- **`TerrainTileField.cliff_end` is a mutable static (E1/E2/E3).** Tests switch it, so a native path must take it per call, never cache it. Task 1's parity gate covers all three modes.
- **Regions with grades.** `sample_baked`/`surface_y_on_side` apply `graded_height` when `region.terrain_grades` is non-empty. The native path must leave grading to GDScript afterwards. Task 2 covers a graded region.
- **Priority queue ties.** `scripts/core/PriorityQueue.gd` is a binary heap whose tie order depends on its sift sequence. .NET's `PriorityQueue` is 4-ary and settles ties differently. Task 6 ports the exact heap and tests tie-heavy inputs.
- **Float32 storage of locals.** River beds are a double local stored into `PackedFloat32Array`; the next step uses the unrounded local. Task 4's parity compares entire walks, which exposes any drift within a few steps.
- **Dictionary insertion order in the cliff sheet.** Face emission order follows `field` / `cols` / `points` insertion order, and the payload hash includes it. Tasks 10-11 compare the full payload hash, not just geometry.

---

## File Structure

- `scripts/native/NativeTileKernel.gd` / `.cs`: tile evaluation over a dense point window (Tasks 1-3).
- `scripts/terrain/field/TerrainTileField.gd`: `dense_window()` and `sample_window()` (reference plus dispatch).
- `scripts/native/NativeRiverWalk.gd` / `.cs`: source search and raw contour walks (Task 4).
- `scripts/native/NativeCarve.gd` / `.cs`: per-region carve index and batched `carve_at` (Task 5).
- `scripts/native/NativeWaterFill.gd` / `.cs` (plus `GdPriorityQueue.cs`): coarse fill kernels (Tasks 6-8).
- `scripts/native/NativeCliffEnvelope.gd` / `.cs`: envelope build from presampled grids (Task 10).
- `scripts/native/NativeCliffSolid.gd` / `.cs`: column surface nets (Task 11).
- Tests, one per loader, mirroring `tests/test_native_grid_kernels.gd`:
  - `tests/test_native_tile_kernel.gd`
  - `tests/test_native_river_walk.gd`
  - `tests/test_native_carve.gd`
  - `tests/test_native_water_fill.gd`
  - `tests/test_native_cliff_envelope.gd`
  - `tests/test_native_cliff_solid.gd`

Measure after each phase. Record numbers in `docs/qa/2026-10-07-native-ports/result.md`:
- `water_block_cost.gd --no-disk --chunk=-4,-5`
- `profile_mesh_phases.gd --detail --chunks "0,-2"`
- the 240 s `travel_profile.tscn` walk

---

## Phase 1: Terrain tile kernel

### Task 1: Native tile evaluation over a dense window, with parity gate

**Files:**
- Create: `scripts/native/NativeTileKernel.cs`, `scripts/native/NativeTileKernel.gd`
- Modify: `scripts/terrain/field/TerrainTileField.gd` (add `dense_window`, `sample_window` after `sample_baked`, ~line 369)
- Test: `tests/test_native_tile_kernel.gd`

**Interfaces:**
- Produces (GDScript, `TerrainTileField`):

```gdscript
## Corner data for every lattice point in [lo, lo + size): what tile_params
## reads, gathered once. heights are float32 exactly as tile_params stores them.
static func dense_window(region, lo: Vector2i, size: Vector2i) -> Dictionary
	# {"lo": Vector2i, "w": int, "h": int, "heights": PackedFloat32Array, "storeys": PackedInt32Array, "spacing": float}

## Ungraded surface height of each sample (x[k], z[k]) on the side of lattice
## point (owner_i[k], owner_j[k]); == surface_y_on_side without grading. The
## window must hold every corner of the owners' four quadrant tiles.
static func sample_window(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> PackedFloat64Array
```

- Produces (C#, `Story.Native.NativeTileKernel : RefCounted`):

```csharp
public double[] SampleOwned(float[] heights, int[] storeys, int w, int h, int i0, int j0,
    double spacing, double[] xs, double[] zs, int[] ownerI, int[] ownerJ, int cliffEnd)
```

- Produces (loader `NativeTileKernel.gd`): `static var enabled`, `static func setup()`, `static func sample_owned(window, xs, zs, owner_i, owner_j) -> PackedFloat64Array`.

- [ ] **Step 1: Write the failing test** `tests/test_native_tile_kernel.gd`:

```gdscript
extends GutTest
const K := preload("res://scripts/native/NativeTileKernel.gd")
const Tile := preload("res://scripts/terrain/field/TerrainTileField.gd")
const Region := preload("res://tests/fixtures/tile_point_region.gd")

func _dotnet() -> bool:
	return ClassDB.class_exists(&"CSharpScript")

func _random_region(rng: RandomNumberGenerator) -> Object:
	var heights := {}
	for j in range(-2, 8):
		for i in range(-2, 8):
			var h := float(rng.randi_range(0, 6)) * 4.0 + float(rng.randi_range(0, 3))
			if rng.randf() < 0.1: h += 0.5          # graded controls are whole metres; keep a few off-grid
			heights[Vector2i(i, j)] = h
	return Region.new(heights)

func test_sample_window_equals_surface_y_on_side() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var saved := Tile.cliff_end
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2, Tile.CliffEnd.E3]:
		Tile.cliff_end = mode
		var region = _random_region(rng)
		var window := Tile.dense_window(region, Vector2i(-2, -2), Vector2i(10, 10))
		var xs := PackedFloat64Array(); var zs := PackedFloat64Array()
		var oi := PackedInt32Array(); var oj := PackedInt32Array()
		for k in 400:
			var x := rng.randf_range(-6.0, 66.0); var z := rng.randf_range(-6.0, 66.0)
			if k % 5 == 0: x = 12.0 * rng.randi_range(0, 5) + 6.0     # wall midlines
			if k % 7 == 0: z = 12.0 * rng.randi_range(0, 5)          # lattice lines
			xs.append(x); zs.append(z)
			oi.append(Tile.point_of(x, region)); oj.append(Tile.point_of(z, region))
		var got := Tile.sample_window(window, xs, zs, oi, oj)
		for k in xs.size():
			assert_eq(got[k], Tile.surface_y_on_side(region, xs[k], zs[k], Vector2i(oi[k], oj[k])))
	Tile.cliff_end = saved

func test_native_matches_or_stays_off() -> void:
	K.setup()
	if not _dotnet():
		assert_false(K.enabled, "standard editor keeps the GDScript kernel")
		return
	assert_true(K.enabled, "parity gate passed")
```

- [ ] **Step 2: Run to verify it fails**

Run: `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_native_tile_kernel.gd -gexit`
Expected: FAIL (`dense_window` and the loader do not exist).

- [ ] **Step 3: Implement the GDScript reference** in `TerrainTileField.gd`:

```gdscript
static func dense_window(region, lo: Vector2i, size: Vector2i) -> Dictionary:
	var heights := PackedFloat32Array(); heights.resize(size.x * size.y)
	var storeys := PackedInt32Array(); storeys.resize(size.x * size.y)
	for j in size.y:
		for i in size.x:
			heights[j * size.x + i] = region.surface_height(lo.x + i, lo.y + j)
			storeys[j * size.x + i] = int(region.storey_at(lo.x + i, lo.y + j))
	return {"lo": lo, "w": size.x, "h": size.y, "heights": heights, "storeys": storeys,
		"spacing": spacing(region)}

static func sample_window(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> PackedFloat64Array:
	if NATIVE_TILE.enabled:
		return NATIVE_TILE.sample_owned(window, xs, zs, owner_i, owner_j)
	return _sample_window_gd(window, xs, zs, owner_i, owner_j)

## The GDScript reference (the native parity gate compares against this).
static func _sample_window_gd(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> PackedFloat64Array:
	var out := PackedFloat64Array(); out.resize(xs.size())
	var w: int = window.w
	var lo: Vector2i = window.lo
	var heights: PackedFloat32Array = window.heights
	var storeys: PackedInt32Array = window.storeys
	var s: float = window.spacing
	var params := PackedFloat32Array(); params.resize(8)
	for k in xs.size():
		var cx := float(owner_i[k]) * s
		var cz := float(owner_j[k]) * s
		var lx := clampf(xs[k], cx - s * 0.5, cx + s * 0.5)
		var lz := clampf(zs[k], cz - s * 0.5, cz + s * 0.5)
		var ti := owner_i[k] if lx >= cx else owner_i[k] - 1
		var tj := owner_j[k] if lz >= cz else owner_j[k] - 1
		var side := Vector2i(-1 if ti == owner_i[k] else 1, -1 if tj == owner_j[k] else 1)
		var a := (tj - lo.y) * w + (ti - lo.x)
		params[0] = heights[a]; params[1] = heights[a + 1]
		params[2] = heights[a + w + 1]; params[3] = heights[a + w]
		var sa := storeys[a]; var sb := storeys[a + 1]; var sc := storeys[a + w + 1]; var sd := storeys[a + w]
		params[4] = 1.0 if absi(sa - sb) >= 2 else 0.0
		params[5] = 1.0 if absi(sb - sc) >= 2 else 0.0
		params[6] = 1.0 if absi(sd - sc) >= 2 else 0.0
		params[7] = 1.0 if absi(sa - sd) >= 2 else 0.0
		out[k] = eval_params(params, (lx - float(ti) * s) / s, (lz - float(tj) * s) / s, side)
	return out
```

Add `const NATIVE_TILE := preload("res://scripts/native/NativeTileKernel.gd")` at the top of `TerrainTileField.gd`.

- [ ] **Step 4: Implement `NativeTileKernel.cs`.** It is a line-for-line port of `eval_params`, `_layer`, `_corner_profile`, `_profile` and `_step` (TerrainTileField.gd:147-294):

```csharp
// C# mirror of TerrainTileField's tile evaluation (eval_params and helpers)
// over a dense window of corner heights. Same double arithmetic in the same
// order; heights are float32 as tile_params stores them. NativeTileKernel.gd
// checks bit-identity before switching over. Stateless and thread-safe.
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeTileKernel : RefCounted
    {
        const double CLIFF_END_CLEAR = 0.2;   // TerrainTileField.CLIFF_END_CLEAR
        const int E1 = 0, E3 = 2;             // TerrainTileField.CliffEnd

        public double[] SampleOwned(float[] heights, int[] storeys, int w, int h, int i0, int j0,
            double spacing, double[] xs, double[] zs, int[] ownerI, int[] ownerJ, int cliffEnd)
        {
            var output = new double[xs.Length];
            double s = spacing;
            for (int k = 0; k < xs.Length; k++)
            {
                double cx = ownerI[k] * s, cz = ownerJ[k] * s;
                double lx = Clamp(xs[k], cx - s * 0.5, cx + s * 0.5);
                double lz = Clamp(zs[k], cz - s * 0.5, cz + s * 0.5);
                int ti = lx >= cx ? ownerI[k] : ownerI[k] - 1;
                int tj = lz >= cz ? ownerJ[k] : ownerJ[k] - 1;
                int sx = ti == ownerI[k] ? -1 : 1, sy = tj == ownerJ[k] ? -1 : 1;
                int a = (tj - j0) * w + (ti - i0);
                double h0 = heights[a], h1 = heights[a + 1], h2 = heights[a + w + 1], h3 = heights[a + w];
                int sa = storeys[a], sb = storeys[a + 1], sc = storeys[a + w + 1], sd = storeys[a + w];
                double cb = System.Math.Abs(sa - sb) >= 2 ? 1.0 : 0.0;
                double cr = System.Math.Abs(sb - sc) >= 2 ? 1.0 : 0.0;
                double ct = System.Math.Abs(sd - sc) >= 2 ? 1.0 : 0.0;
                double cl = System.Math.Abs(sa - sd) >= 2 ? 1.0 : 0.0;
                output[k] = Eval(h0, h1, h2, h3, cb, cr, ct, cl, (lx - ti * s) / s, (lz - tj * s) / s, sx, sy, cliffEnd);
            }
            return output;
        }

        static double Eval(double h0, double h1, double h2, double h3, double cb, double cr, double ct, double cl,
            double u, double v, int sx, int sy, int mode)
        {
            double lo = Min(Min(h0, h1), Min(h2, h3));
            double hi = Max(Max(h0, h1), Max(h2, h3));
            if (hi - lo <= 0.0) return lo;
            if (cb + cr + ct + cl == 0.0)
            {
                double su = Smootherstep(u), sv = Smootherstep(v);
                return Lerp(Lerp(h0, h1, su), Lerp(h3, h2, su), sv);
            }
            double result = lo, prev = lo;
            while (true)
            {
                double t = double.PositiveInfinity;
                if (h0 > prev && h0 < t) t = h0;
                if (h1 > prev && h1 < t) t = h1;
                if (h2 > prev && h2 < t) t = h2;
                if (h3 > prev && h3 < t) t = h3;
                if (t == double.PositiveInfinity) break;
                result += (t - prev) * Layer(h0 >= t, h1 >= t, h2 >= t, h3 >= t, cb, cr, ct, cl, u, v, sx, sy, mode);
                prev = t;
            }
            return result;
        }

        static double Layer(bool ba, bool bb, bool bc, bool bd, double cb, double cr, double ct, double cl,
            double u, double v, int sx, int sy, int mode)
        {
            int highs = (ba ? 1 : 0) + (bb ? 1 : 0) + (bc ? 1 : 0) + (bd ? 1 : 0);
            bool ends = mode == E3 && (cb >= 1.0 ? 1 : 0) + (cr >= 1.0 ? 1 : 0) + (ct >= 1.0 ? 1 : 0) + (cl >= 1.0 ? 1 : 0) == 1;
            if (highs != 2 || ba == bc)
            {
                bool mixed = (ba != bb && cb < 1.0) || (bd != bc && ct < 1.0) || (ba != bd && cl < 1.0) || (bb != bc && cr < 1.0);
                double c0 = (1.0 - CornerProfile(u, cb, v, 0.0, mixed, sx, sy, ends, mode)) * (1.0 - CornerProfile(v, cl, u, 0.0, mixed, sy, sx, ends, mode));
                double c1 = CornerProfile(u, cb, v, 1.0, mixed, sx, sy, ends, mode) * (1.0 - CornerProfile(v, cr, 1.0 - u, 0.0, mixed, sy, -sx, ends, mode));
                double c2 = CornerProfile(u, ct, 1.0 - v, 1.0, mixed, sx, -sy, ends, mode) * CornerProfile(v, cr, 1.0 - u, 1.0, mixed, sy, -sx, ends, mode);
                double c3 = (1.0 - CornerProfile(u, ct, 1.0 - v, 0.0, mixed, sx, -sy, ends, mode)) * CornerProfile(v, cl, u, 1.0, mixed, sy, sx, ends, mode);
                if (highs == 1) return ba ? c0 : bb ? c1 : bc ? c2 : c3;
                double plateau = 1.0;
                if (!ba) plateau *= 1.0 - c0;
                if (!bb) plateau *= 1.0 - c1;
                if (!bc) plateau *= 1.0 - c2;
                if (!bd) plateau *= 1.0 - c3;
                return plateau;
            }
            bool xb = ba != bb, xt = bd != bc, xl = ba != bd, xr = bb != bc;
            bool anySlope = (xb && cb < 1.0) || (xt && ct < 1.0) || (xl && cl < 1.0) || (xr && cr < 1.0);
            double idle = anySlope ? 0.0 : 1.0;
            double kb = xb ? cb : idle, kt = xt ? ct : idle, kl = xl ? cl : idle, kr = xr ? cr : idle;
            double pu = Profile(u, kb, kt, v, sx, sy, ends, mode);
            double pv = Profile(v, kl, kr, u, sy, sx, ends, mode);
            double a = ba ? 1.0 : 0.0, b = bb ? 1.0 : 0.0, c = bc ? 1.0 : 0.0, d = bd ? 1.0 : 0.0;
            return Lerp(Lerp(a, b, pu), Lerp(d, c, pu), pv);
        }

        static double CornerProfile(double t, double k, double s, double cornerT, bool mixed, int side, int sideS, bool ends, int mode)
        {
            if (k <= 0.0) return Smootherstep(t);
            if (!mixed) return Step(t, side);
            if (ends) return Step(s, sideS) == 0.0 ? Step(t, side) : Smootherstep(t);
            double wall = mode == E1 ? 1.0 - s
                : Smootherstep(Clamp((1.0 - CLIFF_END_CLEAR - s) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0));
            double ramp = Smoothstep(0.0, 1.0, Clamp((t - 0.5 * cornerT) * 2.0, 0.0, 1.0));
            return Lerp(ramp, Step(t, side), wall);
        }

        static double Profile(double t, double k0, double k1, double s, int side, int sideS, bool ends, int mode)
        {
            double k;
            if (mode == E1 || k0 == k1) k = Lerp(k0, k1, s);
            else if (ends) k = Step(s, sideS) == 0.0 ? k0 : k1;
            else if (k0 > k1) k = Smootherstep(Clamp((1.0 - CLIFF_END_CLEAR - s) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0));
            else k = Smootherstep(Clamp((s - CLIFF_END_CLEAR) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0));
            if (k >= 1.0) return Step(t, side);
            if (k <= 0.0) return Smootherstep(t);
            return Lerp(Smootherstep(t), Step(t, side), k);
        }

        static double Step(double t, int side) => t > 0.5 ? 1.0 : t < 0.5 ? 0.0 : (side < 0 ? 0.0 : 1.0);
    }
}
```

Check `GdMath` member names (`Lerp`, `Clamp`, `Min`, `Max`, `Smoothstep`, `Smootherstep`; scripts/native/GdMath.cs:116-164) and adjust the `using static` if they live in a nested class.

One check against the GDScript: `_layer` evaluates all four `corners` before choosing. C# evaluates the same four products in the same order, so the value is identical (pure functions).

- [ ] **Step 5: Implement the loader `NativeTileKernel.gd`.** Copy the structure of `NativeGridKernels.gd` (setup with mutex, CSharpScript check, `can_instantiate`, `push_warning` on mismatch).

```gdscript
static func sample_owned(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> PackedFloat64Array:
	var lo: Vector2i = window.lo
	return _native.SampleOwned(window.heights, window.storeys, window.w, window.h, lo.x, lo.y,
		window.spacing, xs, zs, owner_i, owner_j, TILE.cliff_end)
```

`_parity()` (seed 20261007, 60 cases):
- random windows 4..14 points square;
- heights `storey*4 + level`, with 10% `+0.5`;
- 300 samples per case, mixing random positions, 12 i + 6 midlines and 12 i lattice lines;
- owners from `point_of`;
- each case runs under all three `cliff_end` modes (save and restore the static).

It compares `TILE._sample_window_gd(...)` (the GDScript reference from Step 3) against `_native.SampleOwned`, using `!=`.

Call `NativeTileKernel.setup()` next to `NativeGridKernels.setup()` in `FieldTerrainStreamer._ready` (line ~295), in `tests/harness/profile_mesh_phases.gd:70` and in `tests/harness/water_block_cost.gd:23`.

- [ ] **Step 6: Build and run**

```bash
dotnet build Story.csproj
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_native_tile_kernel.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_native_tile_kernel.gd -gexit
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_tile_field.gd -gexit
```

Expected: PASS on both binaries. `test_terrain_tile_field` is unchanged.

- [ ] **Step 7: Commit**

```bash
git add scripts/native/NativeTileKernel.cs scripts/native/NativeTileKernel.gd scripts/terrain/field/TerrainTileField.gd scripts/terrain/field/FieldTerrainStreamer.gd tests/test_native_tile_kernel.gd tests/harness/profile_mesh_phases.gd tests/harness/water_block_cost.gd
git commit -m "Native tile kernel: batched window sampling, bit-identical parity gate"
```

### Task 2: Use window sampling at the three grid hot spots

**Files:**
- Modify: `scripts/terrain/field/CliffSlopeField.gd:811-830` (`_ground_grid`)
- Modify: `scripts/terrain/water/WaterField.gd:640-661` (`_sample_ground_lattice`)
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd` (~360-395, the per-quad `bake_point`/`sample_baked` loop in `compute_chunk`)
- Test: identity harnesses, plus a graded-region unit test in `tests/test_native_tile_kernel.gd`

**Interfaces:**
- Consumes: `TerrainTileField.dense_window`, `sample_window` (Task 1).
- Produces: `TerrainTileField.sample_grid(region, xs: PackedFloat64Array, zs: PackedFloat64Array) -> PackedFloat64Array`. It covers all `xs × zs` (row-major, z outer), each sample owned by `point_of`, with the region's grades applied exactly as `sample_baked(..., region)` does. It is the shared helper for `_ground_grid` and `_sample_ground_lattice`.

- [ ] **Step 1: Record the reference hashes before changing anything**

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/harness/profile_mesh_phases.gd -- --chunks "0,-2;0,-1;1,-1" --hash-out /private/tmp/native-ports/mesh_before.txt
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/harness/water_block_cost.gd -- --chunk=-4,-5 --no-disk | grep WATER_BLOCK_COST > /private/tmp/native-ports/water_before.txt
```

- [ ] **Step 2: Write the failing test** (graded region)

```gdscript
func test_sample_grid_matches_sample_baked_with_grades() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var region := plan.compute_region(16, 16, 12)
	var grade := TerrainGradePatch.new(&"t", {Vector2i(12, 12): 30.0, Vector2i(13, 12): 30.0}, Vector2(180, 180), 3.0)
	var graded := region.with_terrain_grades([grade])
	var xs := PackedFloat64Array(); var zs := PackedFloat64Array()
	for i in 40: xs.append(150.0 + i * 1.5)
	for k in 40: zs.append(150.0 + k * 1.5)
	for r in [region, graded]:
		var got := TerrainTileField.sample_grid(r, xs, zs)
		for k in zs.size():
			for i in xs.size():
				var p := Vector2i(TerrainTileField.point_of(xs[i], r), TerrainTileField.point_of(zs[k], r))
				assert_eq(got[k * xs.size() + i], TerrainTileField.sample_baked(TerrainTileField.bake_point(r, p), p, xs[i], zs[k], r))
```

Check the `TerrainGradePatch.new` argument order against `tests/test_september10_grass_sampling.gd:8` and match it.

- [ ] **Step 3: Implement `sample_grid`, then switch the three sites**

`sample_grid`:
- builds the window over `[point_of(min x) - 1, point_of(max x) + 1]` × the same in z;
- flattens `xs × zs` into sample arrays with owners;
- calls `sample_window`;
- if `region` is a `HeightfieldRegion` with non-empty `terrain_grades`, replaces each value with `region.graded_height(x, z, value)`; for other region types it uses the `_apply_grade` duck-typing.

Sites:
- `_ground_grid` → `return TerrainTileField.sample_grid(region, xs, zs_array)`. Build `zs_array` with the same single-precision sums: `(origin+Vector2(0,k)*ENVELOPE.H).y`.
- `_sample_ground_lattice` → `sample_grid`. Copy the result into the `PackedFloat32Array` (the same float32 rounding as today).
- The mesher quad loop becomes two passes:
  1. Collect `x0/x1/z0/z1` × the centre owner for all `GRID²` quads into flat arrays, and call `sample_window` once (window = the chunk's points ±1).
  2. Fill `quad_heights` and run the rest of the loop unchanged.
  - Grades: keep `graded := region.has_grade_in(...)` as is, and apply `_apply_grade` to the four values when the region has grades (same as `sample_baked(..., region)` does today).

- [ ] **Step 4: Verify identity and speed**

Re-run the Step 1 commands with `--hash-check /private/tmp/native-ports/mesh_before.txt`. Expected: `HASH CHECK: IDENTICAL`, and the water digest is the same string. Also run `tests/harness/parallel_tail_check.gd -- --rounds=2`, expecting PASS.

Record the `--detail` timings (`d.slope_init`, `mesh`) and `water_block_cost` `ground_ms` before and after in `docs/qa/2026-10-07-native-ports/result.md`.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainTileField.gd scripts/terrain/field/CliffSlopeField.gd scripts/terrain/water/WaterField.gd scripts/terrain/field/TerrainChunkMesher.gd tests/test_native_tile_kernel.gd docs/qa/2026-10-07-native-ports/result.md
git commit -m "Ground grids (cliff envelope, water lattice, chunk surface) sample through the native tile kernel"
```

### Task 3: Remaining per-sample callers (measure first)

- [ ] Profile `GrassField.compute` (`tests/harness/profile_grass_field.gd`) and `RockSkirt.build` under `Godot_mono`. For each one whose share of `TerrainTileField.*` calls is above 30%, batch its samples through `sample_grid` / `sample_window` using the Task 2 pattern:
  - **GrassField:** collect a tile's slot positions and gradient stencil points first, sample once, then run the existing qualification over the arrays.
  - **RockSkirt:** sample all 192 ring vertices plus the 32 contact rays per skirt in one call.

  For each, add a unit test comparing the batched values with the per-sample function (exact), confirm the identity harnesses are unchanged, record timings, and commit per caller.

---

## Phase 2: River tracing and carving

### Task 4: Native source search and raw contour walk

**Files:**
- Create: `scripts/native/NativeRiverWalk.cs`, `scripts/native/NativeRiverWalk.gd`
- Modify: `scripts/terrain/water/WaterPlan.gd`: `source_pos` (415), `_has_source_uncached` (438), `_walk` (597). They dispatch when `NativeRiverWalk.ready_for(world_seed)`.
- Test: `tests/test_native_river_walk.gd`

**Scope (port these functions line for line):**

| Function | Lines | Notes |
|---|---|---|
| `_jitter_pos` | 395-410 | 16 `smooth01` |
| `_ascend` | 348-385 | `Vector2.from_angle` → `V2.FromAngle` |
| `_ring_prominence` | 387-393 | |
| `grad` | 323-331 | |
| `_hash_cell`, `priority_of` | 334-345 | `GdMath.Mix64` |
| gates of `_has_source_uncached` | 438-469 | |
| `_walk` | 597-649 | the raw walk loop only |
| `_contour_step` | 710-780 | |
| `_contained_bed` | 783-790 | |
| `_pond_level` | 568-582 | |

**Stays in GDScript:**
- `_shape_alluvial_reach` (needs `Helper.biome_weights5`);
- `_make_pool` / `_make_pond` / `_fit_terminal_land` (build `PondStamp` objects; cheap);
- caches and junctions.

Field reads go to C#:
- `smooth01(p)` = `HeightfieldPlan.height01(Vector3(p.x,0,p.y), seed, false)`;
- `noise_h(p)` = `HeightfieldPlan.natural01(...) * amplitude`.

The C# side calls `NativeTerrainHeight`'s field directly (same assembly: share the `SeedField` via a `NativeTerrainHeight.FieldFor(long seed)` accessor). It must also mirror the GDScript wrapper in `HeightfieldPlan.height01` (176-195):
- spawn falloff `smootherstep(clamp((len-60)/180))`;
- `lerp(spawn_level_m, h, falloff)`;
- `clamp(h / REF_AMPLITUDE, 0, 1)`.

`spawn_level_m(seed)` and `REF_AMPLITUDE` are passed in from GDScript. The native path is enabled only when `HeightfieldPlan.LOWPASS_M == 0` (the tent filter stays GDScript).

**Interfaces:**
- C#:

```csharp
public Godot.Collections.Dictionary Walk(long seed, int scx, int scy, double amplitude, double spawnLevel, double refAmplitude)
// returns { "points": Vector2[], "beds": float[], "widths": float[], "end": Vector2, "arc": double,
//           "source": Vector2, "pool_level": long }
public Godot.Collections.Dictionary SourceGate(long seed, int scx, int scy, double amplitude, double spawnLevel, double refAmplitude)
// returns { "source_pos": Vector2, "passes_gates": bool }  (every gate of _has_source_uncached before the walk)
```

- GDScript `_walk(sc)`: when native, call `Walk`. Then build the `RiverTrace` from the arrays, attach `source_pool = PondStamp.new(source, SOURCE_POOL_R, ..., pool_level, POOL_DEPTH)`, run `_shape_alluvial_reach`, `_make_pond(end, arc, beds[-1])` and `_fit_terminal_land` exactly as today.

**Parity traps (each must be reproduced):**
- `bed` is a double local passed to the next `_contained_bed` unrounded, while `t.beds` stores float32 (`PackedFloat32Array.append`). C# keeps a `double bed` and appends `(float)bed`.
- `widths` are float32 of `lerpf(W_MIN, W_MAX, arc / (MAX_STEPS*TRACE_STEP))`.
- All `Vector2` operations are float32 (`V2`): `p + heading * TRACE_STEP`, `distance_to`, `dot`, `rotated(float(turn)*PI/12.0)` (the angle is double, converted by `Rotated` exactly as Godot does; check `V2.Rotated`'s signature).
- `visited` buckets: `Vector2i((p / SELF_AVOID_R).floor())`. The nearby list iterates buckets x-inner and z-outer, and appends indices in insertion order.
- `Helper._value_noise01(Vector3(arc+phase,0,0), seed+71, MEANDER_SCALE)` → `GdMath.ValueNoise01` (same arguments). Confirm its signature takes (x, y, z, seed, scale).

- [ ] **Step 1: Write the failing test** (`tests/test_native_river_walk.gd`):

```gdscript
extends GutTest
const N := preload("res://scripts/native/NativeRiverWalk.gd")

func test_native_walks_match_gdscript_exactly_or_stay_off() -> void:
	var seed := 2697992464
	N.setup(seed)
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(N.ready_for(seed)); return
	assert_true(N.ready_for(seed), "parity gate passed")
	var gd := TerrainWorldTuning.make_water(seed)
	var native := TerrainWorldTuning.make_water(seed)
	TerrainWorldTuning.make_heightfield(seed, gd)
	TerrainWorldTuning.make_heightfield(seed, native)
	for sc in [Vector2i(-3, -11), Vector2i(1, -5), Vector2i(2, 2), Vector2i(-6, 4), Vector2i(9, -9)]:
		N.force_off = true
		var a := gd.has_source(sc)
		var ta: RiverTrace = gd._walk(sc) if a else null
		N.force_off = false
		var b := native.has_source(sc)
		assert_eq(a, b, "has_source %s" % sc)
		if a:
			var tb: RiverTrace = native._walk(sc)
			assert_eq(ta.points, tb.points); assert_eq(ta.beds, tb.beds); assert_eq(ta.widths, tb.widths)
			assert_eq(ta.pond.center, tb.pond.center); assert_eq(ta.pond.level, tb.pond.level)
			assert_eq(ta.source_pool.level, tb.source_pool.level)
```

- [ ] **Step 2: Run to verify it fails.** Build first (`dotnet build Story.csproj`), then run the test under `Godot_mono`.

- [ ] **Step 3: Implement** the C# port and the loader:
- The loader's `setup(seed)` runs `_parity(seed)`: 40 fixed super-cells (`hash([seed,"river-walk-parity"])` RNG, ±12 cells). It compares `SourceGate` and `Walk` against the GDScript functions with `N.force_off` semantics, field by field, using `!=`.
- Seeds are recorded in a copy-on-write `seeds` Dictionary, like `NativeHeightField`.
- Add `static var force_off := false` for tests and the parity gate.
- In `WaterPlan`, call `NativeRiverWalk.setup(world_seed)` from `_init` (main thread, like `HeightfieldPlan._init`).

- [ ] **Step 4: Verify**
- the test passes;
- `tests/test_water_plan.gd` passes under both binaries;
- `water_block_cost.gd --chunk=-4,-5 --no-disk` digest is unchanged (`b6c965def22e7e93` at the current tree; re-record if Task 2 changed it, which it must not);
- `parallel_tail_check` passes.

Record `region_ms` and `seeds_ms` before and after.

- [ ] **Step 5: Commit**

```bash
git add scripts/native/NativeRiverWalk.cs scripts/native/NativeRiverWalk.gd scripts/native/NativeTerrainHeight.cs scripts/terrain/water/WaterPlan.gd tests/test_native_river_walk.gd docs/qa/2026-10-07-native-ports/result.md
git commit -m "Native river walks: source search and contour walk in C#, bit-identical"
```

### Task 5: Native batched carve

**Files:**
- Create: `scripts/native/NativeCarve.cs`, `scripts/native/NativeCarve.gd`
- Modify: `scripts/terrain/water/WaterPlan.gd`:
  - `_region_for` (912-977): after building `out`, also build `out["native"]`, a C# `CarveRegion` handle;
  - new `carve_batch(xs, zs, grounds) -> PackedFloat64Array`.
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`: `_prefetch_samples` computes each missing point's natural height with `NativeHeightField.height_batch` plus the `height01` wrapper, then carves with `WaterPlan.carve_batch`, filling `_samples` under its lock. The serial `_sample` path is unchanged.
- Test: `tests/test_native_carve.gd`

**Scope:** port `carve_at` (1162-1234) and what it calls:
- `PondStamp.carve_at` / `footprint_t` / `radius_at` / `island_excavation_weight` / `surface_y` / `bed_y` (PondStamp.gd 43-98);
- `RiverTrace.retained_ground_weight` (RiverTrace.gd:20);
- `bank_strengths` (1096) as precomputed arrays.

`CarveRegion` is built once per `_region_for` from flattened data:
- per trace: points (`Vector2[]`), beds/widths (`float[]`), bank strengths (`double[]`), land bars (center, axis, half_length, half_width);
- pond parameters per pond: center, radius, shape_seed, level, surface_ceiling, depth, island_radius, island_offset, peninsula, aspect_ratio;
- the region's `segments` index flattened to CSR arrays: cell → list of (trace, segment).

**Interfaces:**

```csharp
public partial class NativeCarve : RefCounted {
    public long Build(Godot.Collections.Dictionary flat);            // returns a handle; regions kept in a ConcurrentDictionary<long, CarveRegion>
    public double[] CarveBatch(long handle, double[] xs, double[] zs, double[] grounds);
    public void Release(long handle);                                 // called when WaterPlan evicts the region
}
```

`grounds[k]` is `noise_h(p)`, which the caller already has (`h` in `HeightfieldPlan._sample`). Pass `NaN` to mean "compute lazily", which never happens on the batched path.

Parity traps:
- the early outs (`carve <= best`, `bar_carve >= carve`) change only speed, not value;
- spawn disk (`|p| < 200` → 0);
- owner cell `cx = floori(x/24 + .5)`, `rc = floori(cx/32)`;
- the per-trace bank-strength lerp at `si`, `si+1`.

- [ ] **Step 1: Write the failing test.** For seed 2697992464, take 3000 points: random within ±4 km, plus 12 m lattice points near the Task 4 cells. Compare `plan._sample(i, j)` (GDScript serial carve) against the prefetch path (`compute_rect_region` over a 60×60 window containing them with `NativeCarve` on), using `assert_eq` on `[h - carve, carve, h]` for every point. Also assert `NativeCarve.enabled` under .NET.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement.** The loader `setup()` runs a parity gate: build 6 regions near spawn and far, then compare `CarveBatch` with `carve_at` on 2000 points each, using `!=`. `WaterPlan` calls `NativeCarve.release` in `_memo_insert` eviction of `_region_cache` (wrap: evicted values that carry `native` get released).
- [ ] **Step 4: Verify** the test passes, `test_water_plan.gd` (all 29) passes, the `water_block_cost` digest is unchanged, and `parallel_tail_check` passes. Record `region_ms`.
- [ ] **Step 5: Commit** `"Native carve: batched river/pond carving for region prefetch, bit-identical"`.

---

## Phase 3: Water fill solver

### Task 6: Exact priority queue plus relax / reconcile / smooth / retain kernels

**Files:**
- Create: `scripts/native/GdPriorityQueue.cs`, `scripts/native/NativeWaterFill.cs`, `scripts/native/NativeWaterFill.gd`
- Modify: `scripts/terrain/water/WaterField.gd`:
  - `_relax_fill` (1166-1193)
  - `_reconcile_connected_surface` (448-494)
  - `_smooth_fill_surface` (589-615)
  - `_retain_source_connected_fill` (415-441)

  Each starts with `if NATIVE_FILL.enabled: return NATIVE_FILL.<kernel>(...)`.
- Test: `tests/test_native_water_fill.gd`

**Interfaces:**
- `GdPriorityQueue<T>`: a port of `scripts/core/PriorityQueue.gd`.
  - Binary min-heap of (item, priority double) with hole-sift.
  - `BubbleUp` stops when `priority >= parent`.
  - `BubbleDown` takes the left child if `left < current`, then the right child if `right < (chosen)`.
  - `Pop` returns the root, moves the last element to the root and sifts down.
  - Copy the comparison operators exactly; do not use `System.Collections.Generic.PriorityQueue`.
- C# kernels take the packed arrays these functions take today. `float[]` stands for `PackedFloat32Array`; the returned arrays replace the GDScript return or the mutated array. The ground array is the dense `PackedFloat32Array` built by `_sample_ground_lattice`. Native kernels are used only when the caller passes the complete ground array; the `_build_fill` fallback path keeps GDScript.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
const F := preload("res://scripts/native/NativeWaterFill.gd")
const PQ := preload("res://scripts/core/PriorityQueue.gd")

func test_priority_queue_tie_order_matches_gdscript() -> void:
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var gd := PQ.new()
	var pushes := PackedFloat64Array()
	for i in 500:
		var p := float(rng.randi_range(0, 9))     # many ties
		pushes.append(p); gd.push(i, p)
		if rng.randf() < 0.3 and not gd.is_empty(): pushes.append(-1.0); gd.pop()
	var order_gd := PackedInt64Array()
	while not gd.is_empty(): order_gd.append(gd.pop())
	gd.free()
	assert_eq(F.queue_replay(pushes), order_gd, "-1 = pop; the native heap must pop the same items")

func test_fill_kernels_match_gdscript_exactly_or_stay_off() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(F.enabled); return
	assert_true(F.enabled, "parity gate passed (random basins incl. ties and INF ground)")
```

The parity gate in `F.setup()` replays:
- `queue_replay` and its pop order;
- random 20..60-side lattices: ground terraced in 1 m steps (many ties), 10% river seeds, a few pond seeds;
- each kernel against the GDScript function with `!=`.

- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement** the heap and the four kernels, ported line for line from the ranges above:
  - priorities are doubles; levels are stored to `float[]` (float32 rounding at store);
  - `_reconcile_connected_surface` compares in float32 through a one-element array: reproduce that with `(float)` casts at the same points;
  - add `queue_replay(pushes: PackedFloat64Array) -> PackedInt64Array` to the loader as a test hook.
- [ ] **Step 4: Verify** the tests above pass, plus the existing kernel tests (they call these functions directly, so they now exercise native under .NET):
  - `test_september9_water_containment.gd`
  - `test_september10_water_surface.gd`
  - `test_september10_water_relaxation_work.gd`
  - `test_september11_water_rounding.gd`
  - `test_september15_water_drops.gd`
  - `test_september15_water_source_connectivity.gd`
  - `test_priority_queue.gd`

  Also check the `water_block_cost` digest is unchanged and record `relax_ms` / `smooth_ms`.
- [ ] **Step 5: Commit** `"Native water fill: exact binary heap; relax, reconcile, smooth, retain kernels"`.

### Task 7: Spill search and hydrostatic cap

**Files:**
- Modify: `scripts/native/NativeWaterFill.cs/.gd`
- Modify: `WaterField.gd`:
  - `SpillSearch` (1201-1295) and `_cap_hydrostatic_fill` (1297-1323) dispatch to native when the ground is dense;
  - `_source_fill` (346-351) samples the uncarved `natural` ground densely with `sample_grid` (Task 2) instead of lazily inside the cap.

**Interfaces:**

```csharp
public double[] CapHydrostatic(float[] levels, float[] ground, float[] natural, float[] flowCeilings,
    byte[] anchors, int m1, int rows, double eps)   // returns ceilings; mutates a copy of levels returned as "levels"
```

Return a Dictionary `{levels: float[], ceilings: double[]}`.

Port `SpillSearch` (escape/marks/distance arrays, generation counter, memoized escape writes) inside C#. It is used only through `CapHydrostatic` and, later, the fine solve.

- [ ] Step 1: write the failing parity test: `test_cap_matches_gdscript_on_random_basins` (random lattices as in Task 6, with anchors and boundary nodes), comparing exactly.
- [ ] Step 2: run it to verify it fails.
- [ ] Step 3: implement. Precomputing `natural` densely must produce the same values the lazy `_ground_at(natural, ...)` produced. Add one exact equality test of the dense versus lazy sampling for a real domain.
- [ ] Step 4: verify the `water_block_cost` digest is unchanged, `test_september9_water_containment.gd` passes, and record `cap_ms` / `natural_ms` / `spill_ms`.
- [ ] Step 5: commit `"Native spill search and hydrostatic cap"`.

### Task 8: River seeding (claim and containment)

**Files:**
- Modify: `NativeWaterFill.cs/.gd`
- Modify: `WaterField.gd` `_seed_rivers` (971-1050): the `_claim_river_segment` loops (1052-1084) and the containment loop run in C# over flattened traces (points, widths, profile levels, bank weights, terminal pond parameters). `profile()` itself stays GDScript until Task 9.

- [ ] Step 1: write a parity test on the `_seed_rivers` output (`river_levels`, `margins`, `source_indices`) for 4 real domains (`test_september9_pond_seed_queries.gd` already builds them; reuse its fixtures), comparing exactly.
- [ ] Step 2: run it to verify it fails.
- [ ] Step 3: implement.
- [ ] Step 4: verify, and record `claim_ms` / `containment_ms`.
- [ ] Step 5: commit `"Native river seeding: segment claims and containment"`.

### Task 9: Hydraulic profiles (the largest seeding cost)

**Files:**
- Modify: `WaterField.gd` `profile` (1367-1526), `_descend_segment` (1575), `_dense_span_curve` (1733), `_find_descent_knots` (1790), `_eval_descent_knots` (1880), `_descent_knot_tangents` (1924), `_dense_span_points` (1962)
- Modify: `NativeWaterFill.cs/.gd`

**Approach.** `profile()` spends its time in terrain samples along the trace (`TerrainTileField.surface_y` per 4 m substep) and in the iterative knot search.
1. Batch every ground sample a trace needs: the dense 4 m points along every segment and span. That is one `sample_grid`-style call (`sample_window` with `point_of` owners) over `_trace_owned_region`, before the loops.
2. Port the knot search and Hermite evaluation (pure math on arrays) to C#. Convert `Array` of `{k, val}` Dictionaries to two parallel `double[]`.

- [ ] Step 1: add a parity test to `tests/test_water_field.gd`: profiles for 30 traces from two seeds compared exactly (levels and every descent's arrays), with native on vs `force_off`.
- [ ] Step 2: run it to verify it fails.
- [ ] Step 3: implement.
- [ ] Step 4: verify the `water_block_cost` digest is unchanged and `test_water_field.gd` passes. Record `profile_ms`, and the full cold block time against the 59 s baseline. Run the 240 s `travel_profile.tscn -- --seconds 240 --mode walk --startup-timeout 3000` and record frozen seconds and distance.
- [ ] Step 5: commit `"Native hydraulic profiles: batched ground samples, knot search in C#"`.

**Phase 3 exit check.** If the fine rescue (`fine_ms`, ~9 s) is now the largest water cost, write a follow-up plan for it. It is query-heavy (`_fill_bilinear_coarse`, wall spans, shore support); it should be ported only after measuring what the above leaves.

---

## Phase 4: Cliff sheet builder

### Task 10: Native envelope build from presampled inputs

**Files:**
- Create: `scripts/native/NativeCliffEnvelope.cs`, `scripts/native/NativeCliffEnvelope.gd`
- Modify: `scripts/terrain/field/CliffSlopeEnvelope.gd` `build` (132-312). It presamples its three callables into arrays, then dispatches the whole numeric pipeline to native when enabled.
- Test: `tests/test_native_cliff_envelope.gd`

**Presampled inputs** (GDScript, before dispatch):
- `ground` (`double[] w*h`): already from `ground_grid` (Task 2, native-backed);
- `excluded` (`byte[]`): the exclusion mask with the existing coarse-then-edge refinement (155-176);
- `wet` (`double[]`, NaN where dry): from `_levels(env, water_at)` (318-345);
- the wall-line ground samples `_walls` takes at ±0.001 across every 12 m line (395-396). Gather these by scanning the same lines in GDScript and passing a `double[]` per axis.

**Port** (line for line, packed arrays only):
- `_walls` (359-441) minus its `ground_at` calls;
- `_close_walls` (457-583);
- `_lips` (596-626); its `runs` Dictionary becomes a hash map keyed by `(at, toward)` packed into a long. Iterate in insertion order (use an ordered list beside the map);
- `_ridges` (841-866), using `GdMath.ValueNoise01`;
- the transforms (216-258);
- `_distance` (881);
- `_bedrock` (960-1069), with its `lattice`/`cells` memos as hash maps (values are pure, so order is irrelevant for values; keep insertion order where the code iterates them);
- `_bench` / `_bench_profile` (1088-1103);
- `_level_outward` (1113-1130).

The existing native `EnvelopeAxis`/`Blur` kernels are called directly in C#.

Outputs:
- `surface`, `rock`, `moss_grade` (`double[]`);
- `excluded` (`byte[]`), possibly updated;
- `ground` (unchanged).

The GDScript `build` assigns them onto the env object exactly as today.

- [ ] **Step 1: Write the failing tests**
  - Parity on the real fixture `tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz` (origin/w/h/ground/excluded/wet), as `tests/test_cliff_sheet_normals.gd`'s second test loads it. Compare GDScript `build` output arrays against native (`!=` on each array).
  - Parity on 12 synthetic regions from `tests/fixtures/tile_point_region.gd`: random terraces, 2-4 storey walls, wet channels.
  - Under the standard editor, assert `enabled == false`.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement.** Port stage by stage. After each stage, add that stage's intermediate arrays to the parity comparison (keep a debug `stages` output behind a flag), so a mismatch names the stage.
- [ ] **Step 4: Verify** `profile_mesh_phases --hash-check` is IDENTICAL on `0,-2;0,-1;1,-1` plus three cliffy chunks of seed 2697992464 (pick them from `cliff_site_review` photo sites). These pass: `test_cliff_envelope_shortcuts.gd`, `test_cliff_sheet_ends.gd`, `test_cliff_sheet_normals.gd`, `test_september26_bedrock.gd`, `test_september28_ground_seams.gd`. Record `d.slope_init` with `--detail`.
- [ ] **Step 5: Commit** `"Native cliff envelope: the whole numeric build in C# from presampled grids"`.

### Task 11: Native column surface nets (solid)

**Files:**
- Create: `scripts/native/NativeCliffSolid.cs`, `scripts/native/NativeCliffSolid.gd`
- Modify: `scripts/terrain/field/CliffSlopeField.gd`:
  - `solid` (1076-1239), `_columns` (961-1018), `_window_max` (1023-1039), `_drop_fragments` (1245-1265);
  - the bedrock branch only (`rock_cells` empty; production style).
- Test: `tests/test_native_cliff_solid.gd`

**Inputs:**
- the envelope arrays;
- `_mesh_height` corner heights, batched per column through `sample_window` (Task 1);
- the excluded mask;
- the owned rect.

**Outputs:**
- `faces` (`Vector3[]`, the same emission order);
- `roots` (parallel arrays `Vector3[] points`, `Vector3[] normals`, `double[] exposure`, `double[] grade`, in first-occurrence order). GDScript rebuilds the `native_roots` Dictionary in that order;
- `replacement_columns` data.

**Parity traps:**
- `cols` / `field` / `points` insertion order, which defines face order;
- `PackedFloat32Array` column values (`surface - j*GRID` stored float32);
- the vertex snap `.snapped(Vector3.ONE*.0001)` in float32;
- the winding rule `forward := ((f0 > 0.0) == (axis == 1))`;
- the degenerate-quad threshold `|cross|² < 1e-10`;
- union-find order in `_drop_fragments` (`MIN_PIECE` 60).

- [ ] Step 1: write a failing test comparing the solid payload (`faces` and the `native_roots` keys, values and order) for the p03 fixture and 3 real chunks, native vs GDScript (`!=` on arrays; iterate the dict keys in order).
- [ ] Step 2: run it to verify it fails.
- [ ] Step 3: implement.
- [ ] Step 4: verify `--hash-check` IDENTICAL and the cliff tests listed in Task 10 pass. Record `d.solid`.
- [ ] Step 5: commit `"Native cliff solid: column surface nets in C#"`.

### Task 12: Skirts

**Files:**
- Modify: `scripts/terrain/dressing/RockSkirt.gd:80-189`

- [ ] **Step 1: Write a failing test** in `tests/test_september27_rock_placement.gd` style. It builds one skirt with a counting wrapper around `BiomeRegistry.ground_tint_at` and asserts the calls are ≤ the distinct 24 m lattice corners touched (today it is 4 per vertex).
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement.**
  - Memoize the tint closure's corner tints per skirt build, as `CliffRockCrags.mesh_arrays` does (CliffRockCrags.gd:165).
  - Batch the ring's `terrain_ground` samples through `sample_window` (one call per skirt).
  - Values must be unchanged: `--hash-check` IDENTICAL.
- [ ] **Step 4: Verify.** Record `d.add_skirts`.
- [ ] **Step 5: Commit** `"Skirts: memoized lattice tints, batched ground samples"`.

---

## Final verification

- [ ] Run the identity harnesses and the full native test set under both binaries.
- [ ] Run the 240 s walk and `frame_feel_profile` (to confirm no main-thread regressions).
- [ ] Update `AGENTS.md`: native ports, their loaders, the parity-gate rule, and the measured cold block / chunk / walk numbers.
- [ ] Commit `"AGENTS: native terrain/water/cliff ports"`.
