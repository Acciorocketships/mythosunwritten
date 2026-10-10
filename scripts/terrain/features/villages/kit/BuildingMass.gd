class_name BuildingMass
extends RefCounted

## Pack-agnostic architectural description of one building.
##
## Coordinates are MODULE CELLS (x, z) and planner BANDS (y; one storey is two
## bands). Nothing here names an asset: a `BuildingKit` realizes it through
## `BuildingKitAssembler`. Designers write architecture (footprints,
## materials, jetties, roof wings, openings, dressing); assemblers only
## realize it, so the same mass can be built with any kit.

## Outward face directions, indexed 0..3: +X, +Z, -X, -Z.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, 0), Vector2i(0, -1)]

const MATERIAL_STONE := &"stone"
const MATERIAL_TIMBER := &"timber"

const OPENING_WINDOW := &"window"
const OPENING_PLAIN := &"plain"
const OPENING_DOOR := &"door"
const OPENING_BAY := &"bay"
## No wall at all (an open portal onto a skywalk, a party seam...).
const OPENING_NONE := &"none"

var stable_id: StringName = &""
var seed := 0
## Floor band of the storey standing on terrain. Storeys above it whose cells
## have nothing beneath receive an underside (soffit) closure.
var ground_band := 0
## Set by the town adapter (KitGrowingFronts.house_grows): on chosen faces this
## house's lower storeys step in under its top storey and roof, each upper storey
## overhanging the one below. False everywhere else.
var grows := false
## Each storey: {
##   floor_band: int            -- lower band; the storey spans two bands
##   cells: Dictionary          -- Vector2i -> true, the storey footprint
##   material: StringName       -- MATERIAL_*
##   inset: bool                -- walls step half a module inside the
##                                 footprint (the storey above then reads as
##                                 a jetty carried on brackets)
##   plinth: bool               -- stone course below the floor
##   ceiling: bool              -- close an inhabited passage's attic with
##                                 native boards at the room's upper band
##   openings: Dictionary       -- Vector3i(x, z, dir) -> OPENING_* override
##   default_opening: StringName
##   plain_every: int           -- 0 = never; n = every n-th wall plain
## }
var storeys: Array[Dictionary] = []
## Each roof wing: {
##   rect: Rect2i                -- cells covered (x, z)
##   axis: int                   -- 0: ridge along X, 1: ridge along Z
##   eave_band: int
##   colour: StringName
##   open_min / open_max: bool   -- end abuts another wing (no gable)
##   extend_min / extend_max: int -- extra pieces pushed into that wing
##   dormers: Dictionary         -- Vector2i(side 0/1, slot) -> true
##   ridge_peaks: bool
## }
var roofs: Array[Dictionary] = []
## Measured roof articulation attempts, retained for generation diagnostics.
var roof_design_trace: Array[Dictionary] = []
## Flat decks on exposed crowns: {cells: Dictionary, band: int, rails: bool}
var decks: Array[Dictionary] = []
## Dressing: {kind: StringName, storey: int, edge: Vector3i, ...}
var decor: Array[Dictionary] = []


static func edge_key(cell: Vector2i, dir: int) -> Vector3i:
	return Vector3i(cell.x, cell.y, dir)


static func rect_cells(rect: Rect2i) -> Dictionary:
	var out: Dictionary = {}
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			out[Vector2i(x, z)] = true
	return out


func add_storey(floor_band: int, cells: Dictionary, material: StringName,
		inset := false, plinth := false) -> Dictionary:
	var storey := {
		"floor_band": floor_band, "cells": cells.duplicate(),
		"material": material, "inset": inset, "plinth": plinth,
		"openings": {}, "default_opening": OPENING_WINDOW, "plain_every": 0,
	}
	storeys.append(storey)
	return storey


func add_roof(rect: Rect2i, axis: int, eave_band: int, colour: StringName) -> Dictionary:
	var wing := {
		"rect": rect, "axis": axis, "eave_band": eave_band, "colour": colour,
		"open_min": false, "open_max": false, "extend_min": 0, "extend_max": 0,
		"dormers": {}, "ridge_peaks": false,
	}
	roofs.append(wing)
	return wing


## Union footprint of every storey whose band range contains `band`.
func cells_at_band(band: int) -> Dictionary:
	var out: Dictionary = {}
	for storey: Dictionary in storeys:
		var floor := int(storey.floor_band)
		if band >= floor and band < floor + int(storey.get("bands", 2)):
			for cell: Vector2i in storey.cells:
				out[cell] = true
	return out


func top_band() -> int:
	var highest := -1000000
	for storey: Dictionary in storeys:
		highest = maxi(highest, int(storey.floor_band) + int(storey.get("bands", 2)))
	return highest
