"""Summarize actual saved-mesh ray surveys; no appearance acceptance inferred."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[4]
QA = ROOT / 'docs/qa/2026-09-19-manual/112-hillside-native-reaches'
summary = {}
for spot in ('P10', 'P21'):
    reports = json.loads((QA / f'survey-{spot}.json').read_text())
    before, after = reports
    assert before['phase'] == 'before' and after['phase'] == 'after'
    assert all(r['control_hits'] == r['water_controls'] > 0 for r in reports)
    a, b = before['samples'], after['samples']
    assert len(a) == len(b) == 441
    assert all((u['x'],u['z']) == (v['x'],v['z']) for u,v in zip(a,b))
    assert all(u['ground'] is not None and v['ground'] is not None for u,v in zip(a,b))
    deltas = [v['ground']-u['ground'] for u,v in zip(a,b)]
    changed = [d for d in deltas if abs(d) > .01]
    water_changes = [v['water']-u['water'] for u,v in zip(a,b) if u['water'] is not None and v['water'] is not None]
    summary[spot] = dict(points=len(a), ground_changed=len(changed), ground_delta_min=min(deltas), ground_delta_max=max(deltas), water_before=sum(u['water'] is not None for u in a), water_after=sum(v['water'] is not None for v in b), wet_to_dry=sum(u['water'] is not None and v['water'] is None for u,v in zip(a,b)), dry_to_wet=sum(u['water'] is None and v['water'] is not None for u,v in zip(a,b)), retained_water_delta_min=min(water_changes), retained_water_delta_max=max(water_changes), water_controls=[r['water_controls'] for r in reports])
    # Corrected central nine are a subset of the same physical ray survey.
    central = []
    for r in reports:
        s = dict(r)
        s['samples'] = [r['samples'][z*21+x] for z in (9,10,11) for x in (9,10,11)]
        s['derived_from'] = f'survey-{spot}.json'
        central.append(s)
    (QA/f'physical-{spot}.json').write_text(json.dumps(central,indent=2)+'\n')
    for phase in ('before','after'):
        data=json.loads((QA/phase/spot/'audit.json').read_text())
        assert len(data['chunks']) == 9
    aa=json.loads((QA/'before'/spot/'audit.json').read_text())
    bb=json.loads((QA/'after'/spot/'audit.json').read_text())
    assert aa['spot'] == bb['spot']
    assert aa['cameras'] == bb['cameras']
(QA/'survey-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
