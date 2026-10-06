# Automatic stair margins and complete dormer clearance

Production now chooses bounded roof-side stair setbacks before sealing public surfaces. The shared profile owns tread geometry, collision, rails and landing returns. Both route lane centres remain supported, and a neighbouring lateral public connection prevents narrowing that side. Court corner closure runs before selection so those connections count too. Decisions use construction geometry, not seed-specific exceptions.

Structural eave/verge fitting now precedes optional dormers. Dormer fitting checks complete authored geometry against public headroom, as well as the existing window-opening and roof-junction tests. It relocates or omits an obstructed whole module instead of leaving a cut roof skin. Unsupported tight-dormer roles are rejected.

## Evidence

- Focused roof, admission, physical-profile and production-surface suite: **34 tests / 1,952 assertions pass** (`stair-repair-suite.out`).
- Final dormer suite: **4 tests / 107 assertions pass** (`dormer-final.out`). New regression demonstrably fails the prior fitter: two assertions fail when glass is clear but the hood skin is cut (`dormer-whole-red.out`).
- Compact photo town 85830433957479026 now passes the existing closed-roof regression. Its selected roof-side inset is 0.348262 fabric metres (approximately 0.929 world metres), with a native tight eave and flush verge. The roof is intact in the close and upper native renders; short rail returns meet their stock timber joints.
- Actual character/controller traversal: **six of six directional walks pass**, across the compact flight and both admitted flights in 103/grand. Full generated-town collision is used, not isolated substitute geometry.
- Four holdouts (53, 103, 301, 83 grand) all build. Complete roof-audit dictionaries, including examples, are identical to the prior behavior. Only 103 admits margins (two flights).

## Limits and remaining defects

This closes the specific stair/eave regression, not town-wide roof acceptance. Holdouts still report: 53 one tiny wing and one gable hole; 103 two tiny wings and two eave cuts; 301 two gable holes and two eave cuts; 83 one gable hole and three eave cuts. These remain real defects and were verified present with the previous behavior. Wider architectural variety, canopy/facade joins and full redesign acceptance remain open. No global green-suite claim is made.

The first 103 close cameras were obstructed by houses; they are not visual evidence. Replacement cameras use the tested walk endpoints.

Replacement 103 route views inspected: both rail returns and the upper blue roof remain continuous. The lower flight has existing projecting stone detailing on its opposite wall; centre-route player traversal passes, but these images do not establish full-width facade clearance or overall architectural acceptance.
