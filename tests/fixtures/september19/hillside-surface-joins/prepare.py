"""Freeze an isolated WaterField variant; never alter production sources."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[4]
p=root/'scripts/terrain/water/WaterField.gd'
s=p.read_text()
s=s.replace('class_name WaterField\n','')
needle='\tvar out := {"levels": levels, "descents": descents}\n'
assert s.count(needle)==1
s=s.replace(needle,'\tvar out := preload("res://tests/fixtures/september19/hillside-surface-joins/profile_grade.gd").shape(trace, region, levels, descents)\n')
old="\t\t\tfor k in range(dpos.size() - 1):\n\t\t\t\t_claim_river_segment(base, m1, margins, river_levels,\n\t\t\t\t\tdpos[k], dpos[k + 1], dw[k], dw[k + 1], dlvl[k], dlvl[k + 1], 0.0)"
new="\t\t\tfor k in range(dpos.size() - 1):\n\t\t\t\tvar source_segment: int = d.bank_sources[k] if d.has(\"bank_sources\") else -1\n\t\t\t\tvar bank: float = 0.0 if source_segment<0 else WaterPlan.BANK_FEATHER*minf(bank_weights[source_segment],bank_weights[source_segment+1])\n\t\t\t\t_claim_river_segment(base, m1, margins, river_levels,\n\t\t\t\t\tdpos[k], dpos[k + 1], dw[k], dw[k + 1], dlvl[k], dlvl[k + 1], bank, tr.pond)"
assert s.count(old)==1
s=s.replace(old,new)
Path(__file__).with_name('candidate_field.gd').write_text('# ISOLATED GENERATED STUDY — see prepare.py; never loaded by production.\n'+s)
q=root/'docs/qa/2026-09-19-manual/114-hillside-surface-joins'
(q/'candidate-source.json').write_text(json.dumps({'WaterField_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'grade':.22},indent=2)+'\n')
