# Use item action and generic weapons/projectiles

**Goal:** Add use-item action in backend and animations. Design a generic weapon class that generalises all weapons via parameters. Add a projectile class.

- Use item: backend (e.g. “use” on current hotbar item) and character animations for use/attack.
- Generic weapon class: one class parametrised per weapon (damage, range, speed, projectile scene, etc.) so new weapons are data-driven.
- Projectile class: movement, collision, hit detection, lifetime; weapons can spawn projectiles with shared behaviour.
- Hook use-item to the generic weapon flow and to projectiles where applicable.
