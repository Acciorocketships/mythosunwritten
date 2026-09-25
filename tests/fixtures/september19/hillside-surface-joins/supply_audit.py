"""Report whole-route snapshot coverage, with optional explicit downhill gate."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[4]
QA=ROOT/'docs/qa/2026-09-19-manual/114-hillside-surface-joins'
summary={}
for row in json.loads((QA/'supply-P10.json').read_text()):
    samples=row['samples'];inside=[s for s in samples if s['ground'] is not None]
    rises=[]
    for i,(a,b) in enumerate(zip(samples,samples[1:])):
        if a['ground'] is None or b['ground'] is None or a['water'] is None or b['water'] is None:continue
        if b['water']-a['water']>.001:
            rises.append({'index':i,'from':a,'to':b,'rise':b['water']-a['water']})
    summary[row['phase']]={'total':len(samples),'inside_snapshot':len(inside),'outside_snapshot':len(samples)-len(inside),'dry_inside':sum(s['water'] is None for s in inside),'buried_more_than_10cm':sum(s['water'] is not None and s['water']<s['ground']-.1 for s in inside),'rises_over_1mm':rises}
(QA/'supply-audit.json').write_text(json.dumps(summary,indent=2)+'\n')
for phase,r in summary.items():
    print(phase,{k:v for k,v in r.items() if k!='rises_over_1mm'},'rises',len(r['rises_over_1mm']),'max',max([v['rise'] for v in r['rises_over_1mm']],default=0))
if '--require-downhill' in sys.argv:
    assert not summary['after']['rises_over_1mm'], 'Candidate native water rises along its intended downstream route; do not accept.'
