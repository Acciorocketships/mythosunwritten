# Final city, hamlet and T-roof visual judgment

All views listed here were opened and inspected, including their amplified differences. Pixel changes alone are not a pass criterion.

## Complete towns

`complete-before/1..4` and `complete-final/standard-1..4`: twenty matched 1920×1080 views, four diagonal angles and a plan per town. These use the real production fabric, native prefab placement, collision and terrain mesher over a controlled flat site. They isolate construction; they do not show full streamed biome dressing.

- Seed 1, ridge: the long axis and lower flanks are readable from both ends. Small native houses now occupy inner street frontages beside the warren, rather than only isolated exterior lots. The plan verifies the elongated footprint and shared approaches.
- Seed 2, courtyard: varied roof levels and occupied ground frontages surround an open internal route/court. The diagonal views retain a taller inhabited core; this is still an urban form, not the tiny-town tier.
- Seed 3, crescent: the footprint has an open notch and uneven arms. The rear remains taller, while the approach has small houses and low courses. Its larger area is intentional for the explicit standard profile; defaults separately favor hamlets and compact villages.
- Seed 4, hill: retains the recognizable stepped warren but loses the ring of uniformly tall isolated prefabs. Smaller houses and native ground entrances fill the shared streets. Its plan differs from the ridge and crescent.

All twenty amplified differences were inspected. RGB MAE spans 2.230–12.066 (0–255); 4.246–33.854% of pixels change by more than eight levels in any channel. Changed ground collars are expected because the footprint changes. These are whole-frame measures, not image-quality scores.

`complete-final/compact-1` and `compact-4`: ten additional views verify substantially smaller populations, one-storey outer courses, ground houses and retained public platforms. The fixed cameras deliberately remain the same size for scale comparison. The central street circuit remains rectilinear; this work varies the occupied mass and frontage, not every road into a free-form spline.

The performance-only rerender of standard seed 3 matches four views byte-for-byte in decoded pixels. The plan view differs by one color level in two channel values. See `optimization-render-equality.json`.

## Tiny settlements

`hamlet-candidate4/1,3,4` supplies twelve final views (NE, SW, plan, square). All twelve candidate3→candidate4 pairs and differences were judged. Oversized civic houses are replaced by appropriately small native houses; the tree uses the ordinary biome tint instead of white foliage. Supported entrances address one shared gathering space. The well/fire stays clear of the walking loop; the tree green reserves its canopy footprint. The square remains deliberately open.

MAE spans 0.577–13.846; changed pixels 0.726–17.534%. Candidate1's grass cutouts and candidate3's tall houses/white tree are rejected, not accepted evidence. These flat fixtures omit the surrounding world's incidental plants and atmosphere. Fifty real-physics walks across the squares and native approaches pass separately.

## Connected T roofs

All twelve `roof-valley/before`→`after` pairs were inspected: two tile colors, four diagonal angles, plan and close. Native S002 slope derivatives close the previously visible triangular gaps and meet at the same ridge/valley pitch. The difference is localized to the junction; whole-frame MAE is 0.183–1.584, with 0.502–3.762% changed pixels.

Actual triangle coverage tests additionally inspect both eave hands, both colors and all three supported 6 m / 9 m host signatures (20,532 samples). This does not certify unsupported arbitrary widths or offsets.
