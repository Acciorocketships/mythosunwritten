# Hillside confluence ordering — investigation only

No production water code changes. W01 remains open. This investigates the missed downhill confluence documented in [the original diagnosis](../../2026-09-16-manual/17-hillside-sources/diagnosis.md) and the [rejected local priority change](../02-hillside-junction/result.md).

Two detached WaterPlan subclasses order candidate receivers by immutable source bed, with priority as the tie-breaker. Raw geometry prefilters potential contacts before resolving a candidate. Seed 2697992464, incoming source (-2,-1), old receiver (-3,-4).

The depth-bounded fixture in `head_order.gd` still changes the incoming prefix at successive resolution depths: **288 raw, then 44, 123 and 69 stations**. Acyclic ordering alone is insufficient while receiver prefixes are truncated differently by the depth limit. The receiver becomes 34 stations at all positive depths. This candidate is not suitable for production.

The `resolved_order.gd` fixture uses strict source-bed/priority ordering and resolves the full dependency graph. It retains **69 incoming stations** and **34 receiver stations** at positive depths 1, 2 and 3. The probe takes **34.986 seconds** with 464 cache entries. This establishes stability only for these two traces in this query order. It removes the configured dependency-depth bound and therefore is not promoted.

Unresolved requirements: bound dependency extent and work; verify reverse query order and cache behavior; identify the actual retained receiver at the final endpoint; prove supplied hydraulic descent into that receiver; review regenerated native water at the reported and nearby cameras. The old receiver's downstream tail can legitimately disappear after an earlier confluence, so forcing the original first crossing would not prove correct water.

Evidence: [bounded probe](probe.log), [resolved probe](resolved.log). Reproduction uses `tests/harness/september17_hillside_order_probe.gd`; add `-- --resolved` for the second fixture. Neither result closes W01 or changes shipped water.

## Follow-up: bounded ordering and hydraulic endpoint

Two additional detached experiments retain production water unchanged:

- `certified_prefix.gd` admits receivers only along their immutable raw prefix before any potential confluence. Two finite neighborhood scans avoid recursive dependency chains. [Its probe](certified.log) is stable at 123 incoming / 34 receiver stations across all positive depths, but misses the earlier retained confluence found by full resolution. It is too conservative to serve as the desired final fix.
- `terrace_order.gd` requires a strictly lower native storey of source head at every dependency. This makes the dependency chain finite in the available terrain height, instead of using arbitrary hash order within an equal-height band. [Forward](terrace.log) and [reverse source-query order](terrace-reverse.log) both retain 69 incoming / 34 old-receiver stations. Actual dependency nesting is four, with 13 strictly descending edges. The fixture does not admit equal-band confluences; its broader routing consequences remain untested, so it is not production-ready.

The incoming river now terminates inside the actual retained river from **(-4,-1)**, at station 157 of its 221-station prefix. Distance **20.268 m**, receiver half-width **22.617 m**. This avoids joining a receiver tail that has already disappeared. However, [canonical native profiles](receiver-profile.log) reveal an unresolved **12.2835 m surface-height gap**: incoming **17.7000 m** at (-1135.292,-782.2354), receiving **5.4165 m** near (-1155.197,-786.0555). Incoming terminal bed is 15.5 m; receiver bed is 3.2165 m. The current join copies the incoming prefix but does not pass a receiving hydraulic target into profile construction.

Therefore a stable route alone cannot be accepted. The next water change needs an actual terminal hydraulic transition and receiving provenance, verified against native terrain and source continuity. The existing profile lock must not be re-entered through a cross-river profile lookup. `tests/harness/september17_hillside_receiver_profile.gd` reproduces this diagnostic. The measured source-head and profile differences are not a judged rendered waterfall, nor proof that W01 is fixed.

## Follow-up: connector participates in terrain carving

`september17_hillside_terminal_study.gd` first compared an unchanged prefix, an endpoint-bed-only change and seven added connector stations over the original terrain. The endpoint-only candidate still left a 2.6835 m gap because native ground constrained it; the connected candidate reached the receiver with no gap. This alone did not prove the connector would survive shared terrain construction.

The new `tests/fixtures/september17/hillside-order/terminal_join.gd` extends the experimental descending-source-band resolver. After an admitted channel contact, it selects the nearest receiving station inside that receiver's width with a non-higher bed, and appends bounded steps of at most 3 m before publishing the immutable trace. The target uses the receiving trace's bed directly; it does not enter WaterField profile computation or its mutex during route planning. Pond-only joins without a qualifying channel station are left alone. This remains an experimental subclass, not production code.

`tests/harness/september17_hillside_carved_terminal.gd` then constructs a fresh heightfield using that water plan and samples canonical profiles and native terrain. [Forward](carved-terminal.log) and [receiver-first](carved-terminal-reverse.log) probes both retain 76 incoming stations, receiver (-4,-1) with 221 stations, target station 157, a 20.2683 m connector, zero terminal spatial/head gap and no rise in the incoming profile. The endpoint's carve owner discovers the incoming trace. Dependency nesting remains four (38 inspected dependency edges during terrain/profile construction). These matching terminal results do not prove all river arrays or every query order identical.

A separate `--fill` probe tests the actual filled surface, not just the planned river profile. Its first 128 m query exceeded WaterFieldContext's canonical fill margin; [that failed harness run](carved-terminal-fill.log) is excluded. The corrected query is the connector's own bounds plus four metres. The probe must be judged before promoting any water change.

The corrected [candidate fill](carved-terminal-fill-final.log) has 28/28 wet samples with no uphill step, plus a separately sampled endpoint at 5.8092 m. However, the matching [routing-only control](terminal-fill-control.log), using `--fill --control`, already has 29/29 wet samples including its endpoint, also with no uphill step. Its receiving endpoint is 5.4165 m. The connector raises the surface unnecessarily: at the original incoming terminal it changes 8.6288 m to 11.3814 m, despite identical 8 m native ground. A zero gap between planned profiles therefore does not demonstrate an improvement to the actual filled surface. The connector is not selected for production.

Remaining: rendered waterfall/receiving-water joining; bounded discovery for every added segment (the production raw-route prefilter assumes prefixes only); equal-band confluences; complete query-order/corpus checks; potential retained-bank and island intersections. W01 remains open, and no production hydraulic or routing acceptance is claimed.

## Follow-up: ten-source route-order audit

The experimental `terrace_order.gd` resolver was audited across ten source cells in both forward and reverse query order using `tests/harness/september17_hillside_order_corpus.gd`. [The corpus log](corpus.log) records zero differences in route points, beds, widths, joined flags and land bars; all five admitted joins retain an actual receiver. Depth one and default-depth route arrays also match. Each run retains 537 cache entries and 26 dependency edges, with nesting five forward and four reverse. Durations are 53.508 and 53.859 seconds.

The fingerprints do not include every pond/source-pool field. This is not universal query-order, equal-band confluence, hydraulic or rendered-water acceptance. The experiment remains unshipped; production water is unchanged.
