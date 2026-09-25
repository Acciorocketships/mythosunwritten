from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[4]
QA=ROOT/'docs/qa/2026-09-19-manual/116-hillside-mouth-contact'
BASE=ROOT/'docs/qa/2026-09-19-manual/115-hillside-fill-stages'
identities=json.loads((QA/'geometry-P10-P21.json').read_text())
assert len(identities)==2 and all(r['equal'] and r['before']==r['after'] for r in identities)
summary={}
for spot in ('P10','P21'):
    before,after=[r for r in json.loads((QA/'survey-P10-P21.json').read_text()) if r['spot']==spot]
    a,b=before['samples'],after['samples']
    assert len(a)==len(b)==441
    assert all(r['control_hits']==r['water_controls']>0 for r in (before,after))
    assert all((u['x'],u['z'])==(v['x'],v['z']) and u['ground']==v['ground'] for u,v in zip(a,b))
    delta=[v['water']-u['water'] for u,v in zip(a,b) if u['water'] is not None and v['water'] is not None]
    summary[spot]={'ground_changed':0,'points':441,'water_before':sum(u['water'] is not None for u in a),'water_after':sum(v['water'] is not None for v in b),'wet_to_dry':sum(u['water'] is not None and v['water'] is None for u,v in zip(a,b)),'dry_to_wet':sum(u['water'] is None and v['water'] is not None for u,v in zip(a,b)),'water_change_min':min(delta),'water_change_max':max(delta),'water_controls':[before['water_controls'],after['water_controls']]}
    aa=json.loads((BASE/'after'/spot/'audit.json').read_text());bb=json.loads((QA/'after'/spot/'audit.json').read_text())
    assert aa['spot']==bb['spot'] and aa['cameras']==bb['cameras']
(QA/'audit.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
