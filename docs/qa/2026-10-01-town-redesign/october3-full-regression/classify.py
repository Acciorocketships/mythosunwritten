import pathlib,json,re
out=pathlib.Path('/Users/ryko/.codex/worktrees/77a0/story/docs/qa/2026-10-01-town-redesign/october3-full-regression')
def failures(p):
 if not p.exists():return {}
 text=re.sub(r'\x1b\[[0-9;]*m','',p.read_text());method='<script>';rows={}
 for line in text.splitlines():
  if 'Run Summary' in line:break
  if line.startswith('* test_'):method=line[2:].strip()
  if '[Failed]' in line or 'SCRIPT ERROR' in line:
   rows.setdefault(method,[]).append(line.strip())
 return rows
state=json.loads((out/'state.json').read_text());report=[]
for row in state['completed']:
 if row['passed']:continue
 name=row['test'];base={};paths=[]
 for suffix in ['', '-second','-third']:
  p=pathlib.Path('/tmp/town-baseline-comparison'+suffix+'.txt.logs')/(name+'.log')
  if p.exists():base.update(failures(p));paths.append(str(p))
 current=failures(out/(name+'.log'))
 report.append({'test':name,'baseline_logs':paths,'methods':[{'method':m,'current_failures':v,'baseline_failures':base.get(m,[]),'classification':'same_explicit_failures_at_baseline' if v and all(x in base.get(m,[]) and x != '[Failed]:  Unexpected Errors:' for x in v) else 'not_proven_baseline'} for m,v in current.items()]})
(out/'classification.json').write_text(json.dumps({'note':'Initial current logs only; repaired reruns tracked separately. A matching failed method does not establish an identical defect. Baseline warnings can hide assertions; inspect messages.','completed':len(state['completed']),'current':state.get('current'),'files':report},indent=2)+'\n')
print('completed',len(state['completed']),'failed files',len(report),'current',state.get('current'))
