"""Regenerate isolated adapters from frozen predecessors, never production."""
from pathlib import Path
import hashlib,json
here=Path(__file__).resolve().parent;root=here.parents[3]
old=here.parent/'hillside-native-reaches';grade=here.parent/'hillside-fill-stages'
s=(old/'reach_plan.gd').read_text()
needle='\ttrace.pond = river_for(_owner(route.terminal_owner),0).pond\n'
assert s.count(needle)==1
s=s.replace(needle,needle+'''\tvar receiver_stations := PackedInt32Array()
\tfor i in range(1,route.nodes.size()):
\t\tif route.nodes[i].owner != route.nodes[i-1].owner: receiver_stations.append(i)
\ttrace.set_meta("receiver_stations",receiver_stations)
''')
(here/'reach_plan.gd').write_text(s)
(here/'long_reach_plan.gd').write_text((old/'long_reach_plan.gd').read_text().replace('hillside-native-reaches/reach_plan.gd','hillside-mouth-contact/reach_plan.gd'))
(here/'candidate_field.gd').write_text((grade/'eight_candidate.gd').read_text().replace('hillside-surface-joins/profile_grade.gd','hillside-mouth-contact/profile_grade.gd'))
inputs=[old/'reach_plan.gd',old/'long_reach_plan.gd',grade/'eight_candidate.gd',here/'profile_grade.gd']
(root/'docs/qa/2026-09-19-manual/116-hillside-mouth-contact/source-inputs.json').write_text(json.dumps({str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},indent=2)+'\n')
