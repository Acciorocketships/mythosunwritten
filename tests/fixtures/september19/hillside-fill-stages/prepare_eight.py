"""Isolated Euclidean-neighbor grade study; production remains unchanged."""
from pathlib import Path
root=Path(__file__).resolve().parents[4]
p=root/'scripts/terrain/water/WaterField.gd';s=p.read_text().replace('class_name WaterField\n','')
a=s.index('static func _reconcile_connected_surface(');b=s.index('\nstatic func ',a+1)
f=s[a:b]
old='[Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]'
assert f.count(old)==2
f=f.replace(old,'[Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]')
f=f.replace('MAX_GRADE * step','MAX_GRADE * step * Vector2(direction).length()')
needle='\t\t\tvar next := nz * columns + nx'
assert f.count(needle)==2
f=f.replace(needle,'\t\t\tif direction.x != 0 and direction.y != 0 and (not is_finite(levels[z*columns+nx]) or levels[z*columns+nx] <= ground[z*columns+nx] + EPS or not is_finite(levels[nz*columns+x]) or levels[nz*columns+x] <= ground[nz*columns+x] + EPS): continue\n'+needle)
s=s[:a]+f+s[b:]
Path(__file__).with_name('eight_field.gd').write_text('# ISOLATED STUDY — no production references.\n'+s)

# The native study retains pass 114's profile/bank provenance and substitutes
# only the same grade operation exercised by the frozen replay.
candidate=(root/'tests/fixtures/september19/hillside-surface-joins/candidate_field.gd').read_text()
a=candidate.index('static func _reconcile_connected_surface(')
b=candidate.index('\nstatic func ',a+1)
Path(__file__).with_name('eight_candidate.gd').write_text(candidate[:a]+f+candidate[b:])
