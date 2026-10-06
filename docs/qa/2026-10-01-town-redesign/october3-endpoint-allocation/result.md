# Endpoint allocation investigation — October 3

No production changes retained. The carver and climbing-support tests were
restored byte-for-byte to their pre-investigation state. The enclosure probe
now additionally saves source plots, selected bridge proofs and plot outcomes;
console output omits those large ledgers.

## Findings

The original late-ground candidate's 7/standard bridge never allocated:
`lower endpoint house 0: plot bridge.00.end.0.lower occupies reserved ground at (2, -3)`.
The natural-ground shortcut bypassed `_column_is_solid_at`, which also rejects
reserved green space. That exclusion must remain explicit in any future direct
bearing repair. The previously suspected wall-room collision was not this
bridge's actual allocation failure; the ledger resolves that distinction.

Restoring the reserved-ground exclusion selects a narrower valid bridge in
7/standard, which allocates successfully, but still reduces finished inhabited
coverage. Eight-town candidate results (current -> candidate covered quarters):

| Town | Current | Candidate |
|---|---:|---:|
| 7/standard | 40 | 32 |
| 13/large | 28 | 28 |
| 31/large | 12 | 16 |
| 43/grand | 72 | 72 |
| 58/large | 12 | 12 |
| 101/large | 20 | 20 |
| 103/grand | 28 | 28 |
| 211/grand | 68 | 68 |
| Total | 280 | 276 |

All eight candidates build; floating and roof/public-air audits are zero.
Nevertheless, the candidate is rejected. No additional native/player run is
claimed for it: it fails the structural comparison first.

## Further cause to isolate

`WarrenPlotPlanner` reserves bridge span and foundation columns wholesale.
Also, footprint and height entropy uses the mutable building-array index.
Removing a seed therefore changes other houses' draws, not just the bridge's
immediate neighbors. For example, 7's unchanged upper footprint `(0,1),(1,1)`
with door `(1,6,2)` changes from `house.004` / top 12 to `house.003` / top 16.
This is evidence of coupled changes, not a claim that entropy alone explains
all lost coverage. The source ledgers must distinguish changed carving,
reserved columns, changed roll inputs, and final kit composition.

Do not ship the deferred ground patch alone. A local architectural feature needs
stable structural identity and coordinated upper-room ownership before this
admission change can be accepted. Keep reserved greens, full support, public
clearance and roof grammar intact.

## Validation

Candidate support tests pass 4/4, 20 assertions, including natural terrain,
reserved clearings, narrowed footprint, burial and carved/public-air checks.
Their source is saved as `candidate-regressions.gd.txt`, not an active test.
Restored production tests are recorded separately in `restored-tests.log`.
No full-suite or fresh production-timing acceptance is claimed.
