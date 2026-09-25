"""Instrument the unchanged pass-114 candidate without modifying production."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[4]
p=root/'tests/fixtures/september19/hillside-surface-joins/candidate_field.gd'
s=p.read_text().replace('extends Object\n','extends Object\nstatic var stage_observer := Callable()\n')
for label,needle in [
 ('seed','\t_seed_ponds(source_context, owned, base, m1, levels, ground, queue)\n'),
 ('relax','\t_relax_fill(owned, base, m1, levels, ground, rivers, queue)\n'),
 ('contain','\t_retain_source_connected_fill(levels, m1, source_indices)\n'),
 ('smooth','\t_smooth_fill_surface(owned, base, m1, levels, ground, rivers, water_ceilings)\n'),
 ('grade','\t_reconcile_connected_surface(levels, ground, m1, FILL_STEP)\n'),
 ('crest','\t_support_wet_cliff_crests(owned, base, levels, ground, m1, FILL_STEP)\n')]:
 assert s.count(needle)==1,(label,s.count(needle))
 hook=f'\tif stage_observer.is_valid(): stage_observer.call("{label}",{{"base":base,"size":m1,"rows":rows,"levels":levels,"ground":ground,"rivers":rivers}})\n'
 s=s.replace(needle,needle+hook)
Path(__file__).with_name('observed_field.gd').write_text(s)
q=root/'docs/qa/2026-09-19-manual/115-hillside-fill-stages'
(q/'input-hashes.json').write_text(json.dumps({str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()},indent=2)+'\n')
