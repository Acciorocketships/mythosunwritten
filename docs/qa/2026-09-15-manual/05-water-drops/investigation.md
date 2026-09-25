# Issue 05: connected water disappears before the cliff lip

Reference: September 15 P10, 9:53:41 AM; seed 2697992464, feet (-201,8,-1485.6), crosshair (-221.2,0,-1478.9).

The native field reproduces an upper dry strip although both its upper river and lower receiving water are supplied. At x=-240, the surface is 8.10000038 m at z=-1470, but 5.71928549 m at z=-1476. The terrain is 8 m across the interval up to the cliff boundary. Interpolation therefore passes through the crown. Three measured approaches have 134 dry samples out of 180 and up to 4.011 m negative cover. The initial red test records both failures.

Options considered:

- Raising every dry surface to ground would flood real banks and erase islands. Rejected.
- A separate waterfall mesh would leave the physical field broken and introduce a second water surface. Rejected.
- Carry an already supplied upper film to its native cliff lip, with the lower interval owning the descent. Selected for review. It changes the canonical field before geometry and frozen physics sampling.

The final candidate inspects an upper supplied node, its physical crest, and existing lower receiving water. It carries at most the existing upper head, using the actual crown plus the established 0.10 m film clearance. The entire approach must lie below that head. An unsupplied upper bank, an intervening ridge or an empty receiving basin cannot gain water. Both coarse and rescued water apply the same support rule; input snapshots make traversal order irrelevant.

The first candidate passed the right-hand wet-approach regression plus four-orientation, idempotence, dry-bank and ordinary-slope controls (4 tests / 206 assertions). It also passed 55 broader tests / 3,835 assertions. It was nevertheless rejected as complete: the full rebuilt scene retained the left-hand strip. Its native boundary is owned by the high tile and had been rejected by the lower receiving river's head. Fifteen of twenty left-hand samples remained dry.

The second candidate supported that supplied dry crest but still failed five corner samples. At z=-1428 the conservative approach bound included both the actual 8 m supporting tile and a 12 m neighbor touching the line with zero area. The third candidate queries the one-sided bounds of the actual crown owner when the complete approach belongs to that cell. Multi-cell bounds remain conservative, and the same native quadrant extrema are used. All twenty left-hand samples now pass. New controls retain both neighboring heights in unowned bounds and preserve the true high owner.

Eight focused tests pass in the final broader run so far, including 186 points comparing the detached physics sampler with the canonical field through both descents. Final matched water-only comparisons change 1.786–2.391% of full-image pixels and repair both exposed cuts. These comparisons retain the original grass placements to isolate water geometry. A fresh complete production rebuild and the broader regression run are still pending acceptance.

The first capture used the tactical overview. Matched close-camera comparisons use the photo's reconstructed close view and identical recorded poses. The screenshot overlays are rounded; this is a reconstruction, not an exact recovered camera transform.
