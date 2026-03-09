# Simplify and optimise the codebase

**Goal:** Make the terrain and related systems easier to follow and faster: simplify architecture and wording, reduce special cases, then profile and fix inefficiencies.

## Simplification

- **Succinct and readable:** Consolidate repeated logic; shorten code where it improves clarity. Prefer shorter, clearer paths over long branches.
- **Fewer special cases:** Rethink design so tag/socket/piece-type–specific branches are minimised or removed. Aim for generalisable logic instead of “if level then …”, “if ground then …”, etc.
- **Easier to follow:** Reorganise so control flow is linear where possible; avoid retries, multi-attempt loops, and defensive fallbacks. Document invariants and data flow.
- **Align with AGENTS.md:** The codebase rules already ask for no fallbacks, no backward-compatibility paths, and minimal special cases—this doc is the umbrella for systematically applying those principles across the codebase.

## Optimisation

- **Profile first:** Use Godot profiler (or scripted timers) to find real bottlenecks (terrain loop, index queries, rule application, AABB/overlap checks, etc.) instead of guessing.
- **Fix inefficiencies:** Once hotspots are identified, address them (e.g. reduce allocations in hot paths, cheaper overlap checks, fewer redundant lookups, better indexing).
- **Keep behaviour:** Optimisations should not introduce new special cases or reduce readability in a way that conflicts with the simplification goals. Prefer “same behaviour, faster” over “faster but harder to follow.”

## Scope

- **Terrain:** `TerrainGenerator`, rules, `TerrainModuleLibrary`, `PositionIndex`, `TerrainIndex`, definitions.
- **Optional:** Camera, character, and other systems if they become a focus for clarity or performance.
