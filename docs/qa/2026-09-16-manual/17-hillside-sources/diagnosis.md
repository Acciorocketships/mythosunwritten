# P10/P21 hillside source diagnosis — no production change yet

`probe.json` attributes the photographed high-bank water near (-1190.7, -604.5) to river source cell (-2,-1), whose local bed is 23.5 m and hydraulic surface about 25.7 m. The same river already crossed a much lower channel before reaching that bank.

The follow-up [junction probe](junction.log) isolates why the planner misses that confluence:

- Source (-2,-1) priority = 8848326053416111732. Its 288-station trace remains unchanged and unjoined at depths 0, 1 and 2.
- Source (-3,-4) priority = 8738890649821881169. Its 305-station trace also remains unchanged.
- At station 43 of the high river, the receiving channel is 15.58 m away, inside its 24.75 m half-width. Incoming bed is 23.5 m; receiver bed is -0.5 m.
- At station 45, their center samples are only 3.21 m apart. The high river continues beyond the crossing and crosses the low channel again at stations 57–60.

`WaterPlan._neighbour_rivers` admits only larger random priorities, so the high river cannot see this lower receiver. The reverse river cannot join uphill. This leaves two independently supplied routes at incompatible heights over the same channel, including the high supply beyond the crossing.

This is a topology defect, not an animation-direction defect. It is distinct from the corrected W02 packet/current direction. Do not lower all deep water to the local terrain, which would destroy legitimate lakes.

Next implementation needs a locally downhill confluence rule with deterministic equal-level precedence, finite dependency discovery, and proof that the selected receiving prefix survives final depth-two resolution. Preserve the existing immutable raw-route/prefix contract. Check the terminal hydraulic surface as well as trace truncation: the current join retains the incoming bed, so a large fall must actually meet receiving water rather than ending in an elevated sheet. Tests must cover reciprocal candidates, stable final target presence, query-order independence, and the photographed source. Then rebuild terrain/water and judge the reported and nearby timed views.

Reproduce: Godot headless `--script tests/harness/september17_hillside_junction_probe.gd`. This report is diagnosis only; W01 remains open and no water production file changed in this follow-up.
