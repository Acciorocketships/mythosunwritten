class_name TerrainIndex
extends Object

# ============================================================
# CONFIG
# ============================================================

const CHUNK_XZ := 24
const STEP_XZ  := 4
const STEP_Y   := 2
const EPS      := 1e-6
#warning-ignore:integer_division
const NX_LOCAL := CHUNK_XZ / STEP_XZ    # 6


# ============================================================
# DEBUG HELPERS
# ============================================================

func _debug(msg: String) -> void:
	print("[TerrainIndex] ", msg)

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERT FAILED: " + msg)
		print_stack()
		assert(false, msg)


static func _safe_ix(ix: int) -> bool:
	return ix >= 0 and ix < NX_LOCAL

static func _safe_iz(iz: int) -> bool:
	return iz >= 0 and iz < NX_LOCAL


# ============================================================
# CHUNK STRUCTURE
# ============================================================

class Chunk:
	var modules: Dictionary = {}             # {TerrainModuleInstance: true}

	var x_buckets: Array = []                # Array[Dictionary]
	var z_buckets: Array = []                # Array[Dictionary]
	var y_buckets: Dictionary = {}           # {iy: Dictionary[module:true]}

	func _init():
		x_buckets.resize(NX_LOCAL)
		z_buckets.resize(NX_LOCAL)
		for i in range(NX_LOCAL):
			x_buckets[i] = {}
			z_buckets[i] = {}

# ============================================================
# STORAGE
# ============================================================

var chunks: Dictionary = {}                 # {Vector2i: Chunk}
var all_modules: Dictionary = {}            # {TerrainModuleInstance: true}
var aabb_by_module: Dictionary = {}         # {TerrainModuleInstance: AABB}

# Global coarse span of chunk keys
var span_valid := false
var ix_min: int
var ix_max: int
var iz_min: int
var iz_max: int


# ============================================================
# CHUNK HELPERS
# ============================================================

static func _chunk_key_from_xz(x: float, z: float) -> Vector2i:
	var cx = int(floor(x / CHUNK_XZ + 0.5))
	var cz = int(floor(z / CHUNK_XZ + 0.5))
	return Vector2i(cx, cz)

static func _chunk_center(key: Vector2i) -> Vector2:
	return Vector2(float(key.x * CHUNK_XZ), float(key.y * CHUNK_XZ))

static func _chunk_lower(key: Vector2i) -> Vector2:
	var c = _chunk_center(key)
	return Vector2(c.x - CHUNK_XZ * 0.5, c.y - CHUNK_XZ * 0.5)

static func _chunk_rect_xz(key: Vector2i) -> Rect2:
	var lower = _chunk_lower(key)
	return Rect2(lower, Vector2(CHUNK_XZ, CHUNK_XZ))


# ============================================================
# BUCKET HELPERS (CLAMP-SAFE)
# ============================================================

static func _local_x_index(x: float, low: float) -> int:
	var lx: float = (x - low) / STEP_XZ
	lx = clampf(lx, 0.0, float(NX_LOCAL) - EPS)
	return int(floor(lx))

static func _local_z_index(z: float, low: float) -> int:
	var lz: float = (z - low) / STEP_XZ
	lz = clampf(lz, 0.0, float(NX_LOCAL) - EPS)
	return int(floor(lz))

static func _local_x_range(box: AABB, low: float) -> Vector2i:
	var x0: float = max(box.position.x, low)
	var x1: float = min(box.position.x + box.size.x, low + float(CHUNK_XZ))
	if box.size.x > 0.0:
		x1 -= EPS
	var ix0: int = _local_x_index(x0, low)
	var ix1: int = _local_x_index(x1, low)
	return Vector2i(ix0, ix1)

static func _local_z_range(box: AABB, low: float) -> Vector2i:
	var z0: float = max(box.position.z, low)
	var z1: float = min(box.position.z + box.size.z, low + float(CHUNK_XZ))
	if box.size.z > 0.0:
		z1 -= EPS
	var iz0: int = _local_z_index(z0, low)
	var iz1: int = _local_z_index(z1, low)
	return Vector2i(iz0, iz1)

static func _y_index(y: float) -> int:
	return int(floor(y / STEP_Y))

static func _y_range(box: AABB) -> Vector2i:
	var y0 = _y_index(box.position.y)
	var y1 = _y_index(box.position.y + box.size.y)
	if box.size.y > 0.0:
		y1 = _y_index(box.position.y + box.size.y - EPS)
	return Vector2i(y0, y1)


# ============================================================
# SPAN MAINTENANCE
# ============================================================

func _update_span_on_insert(key: Vector2i) -> void:
	if not span_valid:
		ix_min = key.x; ix_max = key.x
		iz_min = key.y; iz_max = key.y
		span_valid = true
	else:
		if key.x < ix_min: ix_min = key.x
		if key.x > ix_max: ix_max = key.x
		if key.y < iz_min: iz_min = key.y
		if key.y > iz_max: iz_max = key.y

func _recalc_span() -> void:
	if chunks.is_empty():
		span_valid = false
		return

	var first := true
	var nx_min := 0
	var nx_max := 0
	var nz_min := 0
	var nz_max := 0

	for key in chunks.keys():
		var ck: Vector2i = key
		if first:
			nx_min = ck.x; nx_max = ck.x
			nz_min = ck.y; nz_max = ck.y
			first = false
		else:
			if ck.x < nx_min: nx_min = ck.x
			if ck.x > nx_max: nx_max = ck.x
			if ck.y < nz_min: nz_min = ck.y
			if ck.y > nz_max: nz_max = ck.y

	ix_min = nx_min
	ix_max = nx_max
	iz_min = nz_min
	iz_max = nz_max
	span_valid = true


# ============================================================
# INSERT
# ============================================================

func insert(module: TerrainModuleInstance) -> void:
	if all_modules.has(module):
		#_debug("Re-inserting existing module, calling remove first: " + module.debug_string())
		remove(module)

	all_modules[module] = true
	var box: AABB = module.aabb
	aabb_by_module[module] = box

	var min_x = box.position.x
	var max_x = box.position.x + box.size.x
	if box.size.x > 0.0:
		max_x -= EPS
	var min_z = box.position.z
	var max_z = box.position.z + box.size.z
	if box.size.z > 0.0:
		max_z -= EPS

	var ck0 = _chunk_key_from_xz(min_x, min_z)
	var ck1 = _chunk_key_from_xz(max_x, max_z)

	#_debug("insert: " + module.debug_string() + " chunk range x=[" + str(ck0.x) + "," + str(ck1.x) + "] z=[" + str(ck0.y) + "," + str(ck1.y) + "]")

	for cz in range(ck0.y, ck1.y + 1):
		for cx in range(ck0.x, ck1.x + 1):
			var key = Vector2i(cx, cz)
			var chunk: Chunk = chunks.get(key)
			if chunk == null:
				chunk = Chunk.new()
				chunks[key] = chunk

			chunk.modules[module] = true
			_update_span_on_insert(key)

			var lower = _chunk_lower(key)
			var xr = _local_x_range(box, lower.x)
			var zr = _local_z_range(box, lower.y)
			var yr = _y_range(box)

			#_debug("  insert into chunk " + str(key) + " lower=" + str(lower) + " xr=" + str(xr) + " zr=" + str(zr) + " yr=" + str(yr))

			for ix in range(xr.x, xr.y + 1):
				if not _safe_ix(ix):
					#_debug("    [WARN] insert: ix out of range: " + str(ix) + " for xr=" + str(xr) + " NX_LOCAL=" + str(NX_LOCAL))
					continue
				chunk.x_buckets[ix][module] = true

			for iz in range(zr.x, zr.y + 1):
				if not _safe_iz(iz):
					#_debug("    [WARN] insert: iz out of range: " + str(iz) + " for zr=" + str(zr) + " NX_LOCAL=" + str(NX_LOCAL))
					continue
				chunk.z_buckets[iz][module] = true

			for iy in range(yr.x, yr.y + 1):
				var ys = chunk.y_buckets.get(iy)
				if ys == null:
					ys = {}
					chunk.y_buckets[iy] = ys
				ys[module] = true


# ============================================================
# REMOVE
# ============================================================

func remove(module: TerrainModuleInstance) -> void:
	if not all_modules.has(module):
		return

	var box: AABB = aabb_by_module.get(module)
	if box == null:
		#_debug("remove: module had no stored aabb: " + module.debug_string())
		all_modules.erase(module)
		return

	var min_x = box.position.x
	var max_x = box.position.x + box.size.x
	if box.size.x > 0.0:
		max_x -= EPS
	var min_z = box.position.z
	var max_z = box.position.z + box.size.z
	if box.size.z > 0.0:
		max_z -= EPS

	var ck0 = _chunk_key_from_xz(min_x, min_z)
	var ck1 = _chunk_key_from_xz(max_x, max_z)

	#_debug("remove: " + module.debug_string() + " chunk range x=[" + str(ck0.x) + "," + str(ck1.x) + "] z=[" + str(ck0.y) + "," + str(ck1.y) + "]")

	for cz in range(ck0.y, ck1.y + 1):
		for cx in range(ck0.x, ck1.x + 1):
			var key = Vector2i(cx, cz)
			var chunk: Chunk = chunks.get(key)
			if chunk == null:
				continue

			chunk.modules.erase(module)

			var lower = _chunk_lower(key)
			var xr = _local_x_range(box, lower.x)
			var zr = _local_z_range(box, lower.y)
			var yr = _y_range(box)

			#_debug("  remove from chunk " + str(key) + " lower=" + str(lower) + " xr=" + str(xr) + " zr=" + str(zr) + " yr=" + str(yr))

			for ix in range(xr.x, xr.y + 1):
				if not _safe_ix(ix):
					#_debug("    [WARN] remove: ix out of range: " + str(ix) + " for xr=" + str(xr))
					continue
				chunk.x_buckets[ix].erase(module)

			for iz in range(zr.x, zr.y + 1):
				if not _safe_iz(iz):
					#_debug("    [WARN] remove: iz out of range: " + str(iz) + " for zr=" + str(zr))
					continue
				chunk.z_buckets[iz].erase(module)

			for iy in range(yr.x, yr.y + 1):
				var ys = chunk.y_buckets.get(iy)
				if ys:
					ys.erase(module)

			for iy in chunk.y_buckets.keys().duplicate():
				if chunk.y_buckets[iy].is_empty():
					chunk.y_buckets.erase(iy)

			if chunk.modules.is_empty():
				chunks.erase(key)

	all_modules.erase(module)
	aabb_by_module.erase(module)
	_recalc_span()


# ============================================================
# UPDATE
# ============================================================

func update(module: TerrainModuleInstance) -> void:
	#_debug("update: " + module.debug_string())
	# Must be called after module.aabb updated from its transform
	if not all_modules.has(module):
		insert(module)
	else:
		remove(module)
		insert(module)


# ============================================================
# QUERY
# ============================================================

func query_box(box: AABB) -> Array:
	if all_modules.is_empty() or not span_valid:
		return []

	var min_x = box.position.x
	var max_x = box.position.x + box.size.x
	if box.size.x > 0.0:
		max_x -= EPS
	var min_z = box.position.z
	var max_z = box.position.z + box.size.z
	if box.size.z > 0.0:
		max_z -= EPS

	var ck0 = _chunk_key_from_xz(min_x, min_z)
	var ck1 = _chunk_key_from_xz(max_x, max_z)

	var cx0 = max(ck0.x, ix_min)
	var cx1 = min(ck1.x, ix_max)
	var cz0 = max(ck0.y, iz_min)
	var cz1 = min(ck1.y, iz_max)

	if cx0 > cx1 or cz0 > cz1:
		return []

	var yr = _y_range(box)
	var candidates: Dictionary = {}

	#_debug("query_box: box=" + str(box) + " chunk x=[" + str(cx0) + "," + str(cx1) + "] z=[" + str(cz0) + "," + str(cz1) + "] yr=" + str(yr))

	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var key = Vector2i(cx, cz)
			var chunk: Chunk = chunks.get(key)
			if chunk == null:
				continue

			var rect = _chunk_rect_xz(key)
			var fully_covers = (
				box.position.x <= rect.position.x
				and (box.position.x + box.size.x) >= rect.position.x + rect.size.x
				and box.position.z <= rect.position.y
				and (box.position.z + box.size.z) >= rect.position.y + rect.size.y
			)

			if fully_covers:
				#_debug("  query chunk " + str(key) + " fully covered by box. rect=" + str(rect))
				var sy: Dictionary = {}
				for iy in range(yr.x, yr.y + 1):
					var yset = chunk.y_buckets.get(iy)
					if yset:
						for m in yset.keys():
							sy[m] = true
				for m in chunk.modules.keys():
					if sy.has(m):
						candidates[m] = true
				continue

			var lower = _chunk_lower(key)
			var xr = _local_x_range(box, lower.x)
			var zr = _local_z_range(box, lower.y)

			#_debug("  query chunk " + str(key) + " lower=" + str(lower) + " xr=" + str(xr) + " zr=" + str(zr))

			var sx: Dictionary = {}
			var sz: Dictionary = {}
			var sy2: Dictionary = {}

			for ix in range(xr.x, xr.y + 1):
				if not _safe_ix(ix):
					#_debug("    [WARN] query: ix out of range: " + str(ix) + " for xr=" + str(xr))
					continue
				var xs = chunk.x_buckets[ix]
				for m in xs.keys():
					sx[m] = true

			for iz in range(zr.x, zr.y + 1):
				if not _safe_iz(iz):
					#_debug("    [WARN] query: iz out of range: " + str(iz) + " for zr=" + str(zr))
					continue
				var zs = chunk.z_buckets[iz]
				for m in zs.keys():
					sz[m] = true

			for iy in range(yr.x, yr.y + 1):
				var ys2 = chunk.y_buckets.get(iy)
				if ys2:
					for m in ys2.keys():
						sy2[m] = true

			for m in sx.keys():
				if sz.has(m) and sy2.has(m):
					candidates[m] = true

	# Safety check: ensure candidate has AABB
	for m in candidates.keys().duplicate():
		if not aabb_by_module.has(m):
			#_debug("  [WARN] candidate without stored AABB: " + str(m))
			_assert(false, "query: candidate without AABB")

	var out: Array = []
	for m in candidates.keys():
		var aabb: AABB = aabb_by_module[m]
		#var a_max := aabb.position + aabb.size
		#var b_max := box.position + box.size
		#print("dz gaps: a_max.z - b_min.z =", a_max.z - box.position.z, " b_max.z - a_min.z =", b_max.z - aabb.position.z)
		if aabb.intersects(box):
			out.append(m)

	return out


func query_outside(box: AABB) -> Array:
	var inside = query_box(box)
	if inside.is_empty():
		return all_modules.keys()

	var inside_set: Dictionary = {}
	for m in inside:
		inside_set[m] = true

	var out: Array = []
	for m in all_modules.keys():
		if not inside_set.has(m):
			out.append(m)

	return out
