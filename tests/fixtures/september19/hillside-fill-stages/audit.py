"""Compare frozen fill stages and preserve the full-route failure separately."""
from pathlib import Path
import argparse,json
root=Path(__file__).resolve().parents[4]
qa=root/'docs/qa/2026-09-19-manual/115-hillside-fill-stages'
parser=argparse.ArgumentParser();parser.add_argument('--variant',default='eight');parser.add_argument('--require-primary-descent',action='store_true');parser.add_argument('--require-downhill',action='store_true');args=parser.parse_args()
def rises(rows,key):
 return [{'index':a['index'],'rise':b[key]-a[key]} for a,b in zip(rows,rows[1:]) if a[key] is not None and b[key] is not None and b[key]-a[key]>.001]
previous=json.loads((qa.parent/'114-hillside-surface-joins/candidate-samples.json').read_text())
replay=json.loads((qa/'replay.json').read_text())
assert len(replay)==2 and all(len(v['samples'])==34 for v in replay)
assert all(a['point']==b['point'] and a['field']==b['level'] for a,b in zip(previous,replay[0]['samples'])), 'Frozen original must reproduce previous candidate exactly'
report={'original_replay_exact':True,'stages':{},'variants':{}}
for stage in ['seed','relax','contain','smooth','grade','crest']:
 report['stages'][stage]=rises(json.loads((qa/(stage+'.json')).read_text()),'level')
for v in replay:report['variants'][v['variant']]=rises(v['samples'],'level')
(qa/'stage-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if args.require_primary_descent:assert not [r for r in report['variants'][args.variant] if 174<=r['index']<=180], 'Primary descent still rises'
if args.require_downhill:assert not report['variants'][args.variant], 'Remaining downstream rise: the complete water fix is not accepted'
