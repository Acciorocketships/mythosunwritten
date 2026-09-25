"""Arrival/physical-walk latency from the real graphical grass service."""
import json
import sys
from pathlib import Path

paths = [Path(name) for name in sys.argv[2:]]
traces = [[json.loads(line) for line in Path(str(path)+'.grass.jsonl').read_text().splitlines()]
          for path in paths]
# A tile observed with a nonempty canonical payload in either run is a real
# grass bed. This avoids treating intentionally empty water/path tiles as pop-in.
nonempty = {tile for rows in traces for row in rows for tile in row['known_nonempty']}
results = []
for path, rows in zip(paths, traces):
    report = json.loads(path.read_text())
    stream_rows = [json.loads(line) for line in Path(str(path)+'.jsonl').read_text().splitlines()]
    result = {'source': str(path), 'status': report['status'],
              'startup_seconds': report['startup_msec']/1000,
              'peak_static_mb': max(r.get('memory', 0) for r in stream_rows)/1e6,
              'peak_prepared_buffer_mb': max(r.get('prepared_bytes', 0) for r in rows)/1e6,
              'max_prepared_tiles': max(r.get('prepared_tiles', 0) for r in rows),
              'visits': []}
    for visit in report['visits']:
        site = visit['index']
        visible = [row for row in rows if row['site'] == site and row['phase'] == 'visible']
        first_foot = next((r['since_release_msec']/1000 for r in visible if r['underfoot_ready']), None)
        first_near = next((r['since_release_msec']/1000 for r in visible if not r['missing_near']), None)
        durations = dict(missing_underfoot=0., missing_nonempty_underfoot=0., missing_near=0., frozen=0.)
        for a,b in zip(rows, rows[1:]):
            if a['site'] != site or a['phase'] != 'walk' or b['phase'] != 'walk' or b['site'] != site:
                continue
            seconds = (b['msec']-a['msec'])/1000
            if not a['underfoot_ready']:
                durations['missing_underfoot'] += seconds
                if a['underfoot'] in nonempty:
                    durations['missing_nonempty_underfoot'] += seconds
            if a['missing_near']:
                durations['missing_near'] += seconds
            if a['frozen']:
                durations['frozen'] += seconds
        result['visits'].append({'id':visit['id'], 'ready_seconds':visit['ready_msec']/1000,
            'walk_meters':visit['walk_meters'], 'walk_frozen_seconds':visit['walk_frozen_seconds'],
            'first_observed_underfoot_seconds':first_foot, 'first_observed_near_seconds':first_near,
            'sampled_walk_seconds':durations, 'stats_after_30_seconds':visit['after_30_seconds']['stats']})
    results.append(result)
Path(sys.argv[1]).write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
