# Native eave and grounded tower junctions

Status: implementation progress; overall architectural acceptance remains open.

## Source relationship

The actual Pure Village House_16c study shows its cap at y13 with the adjoining house eave at13.5. The previous proposer put the cap one course higher than that relationship. The generated tower now starts far enough down the facade that its cap begins at `eave - ROOF_LAP` (0.5 native metres). It uses at least two full courses; one-course attic ornaments remain rejected.

The proposer tries eave-side attachments before gable attachments, using corner-adjacent offsets on broader faces. `KitTowerHostFit` recognizes the eave junction only at the source cap datum. Eave attachments retain the original gable verges; measured native cap cutters join the roof skins. Backing, doors, neighbours, other roof wings and finished public headroom still govern admission.

The native grounded half-tower form is now preferred where every base column meets the source terrain datum. A neighbouring roof or raised walkway is not accepted as ground. Eave attachments require this ground base. Existing gable attachments can still consider a fully backed corbelled shaft. This does not yet implement the full stepped-wing House_16c massing or the narrower House_11c family.

## Evidence

- Before the final visual rejection below, three focused suites: 23/23, 2,627 assertions, 78.794s. Includes native course contacts, support, all four facade directions, public/neighbor clearance, deterministic proposals, host-window replacement, both-kit eave datum checks and a generated eave junction mutation test.
- A 31/large experiment proved the cap-removal mutation but was visually rejected; the final mutation test now exercises the grounded43/grand eave tower. Removing that actual cap must increase the exposed-eave-cut count, along with the uncapped-shaft check. The audit excludes only cutters matched to a cap actually present, rather than exempting all tower hosts.
- 13/large: one two-course gable shaft; 43/grand: a grounded two-course eave shaft plus two corbelled gable shafts; 31/large: the experimental two-course eave shaft was rejected; 103/grand: none. Before that final rejection, all four sampled buildings' whole-town gable-hole/unsupported-roof/uncapped-shaft counts are zero. This is not a claim that every roof metric is green: 43/grand still has two tiny roof fragments and additional eave-cut flags outside the new cap's location to investigate.
- The former compact mutation fixture no longer contains a tower at the lower source datum. The positive mutation oracle now uses the actually built 13/large shaft; no missing-cap criterion was relaxed.
- Native13 and43 views rendered. The first automated grounded-tower cameras were occluded by neighbouring buildings and are not acceptance evidence. `join/43_grand_join.png` and `join/43_grand_foot.png` are the inspected close views: native stone base meets ground and the cap meets the eave without the previous high detached relationship. Corbelled examples still reveal broad flat backing panels, so the owner’s integration concern is not fully resolved.

## Still required

More stepped/corner massing and the narrow source tower family; shallow projecting wall frontages with shed roofs; inhabited supported massifs enclosing climbs. Tall flat facade examples remain. The16-town production refresh passed16/16 before the final suspended-eave rejection. All measured geometry fits halo1; player routes predate this tower revision and need refreshing for final acceptance. Final quiet production passes at7,511ms against the unchanged8,000ms ceiling,149 assertions; log `/tmp/oct3-towers-production16.log` records the16-record run.

## Rejected visual iteration

`rejected-eave31/` shows a closed, collision-clear eave joint that still looks like a cylinder hung on a broad flat apartment facade. It was rejected on art grounds despite its passing geometric tests. New eave attachments now require the grounded native base; corbelled eave attachments need a lower inhabited supporting wing before reintroduction. The43/grand grounded close views remain representative of the retained rule. Final focused rerun:12/12,1,506 assertions,78.098s (`final-tests.log`). The unchanged native assembly suite passed in the preceding23-test run.

Final strengthening: the mutation removes ONLY eave-tower caps, leaving gable caps intact. The additional exposed-eave-cut assertion still passes (1/1,6 assertions,24.484s). No live jobs at this checkpoint.
