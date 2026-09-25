"""Summarize independent input, physics, readiness and camera observations."""
from pathlib import Path
from collections import Counter
import json
import statistics
import sys

root = Path(sys.argv[1])
rows = json.loads((root / 'movement.json').read_text())
summary = []
for row in rows:
    samples = row['samples']
    timings = sorted(s['camera_us'] / 1000 for s in samples)
    stopped = [s for s in samples[15:] if s['step'] < .01]
    contacts = Counter(c['collider'] for s in stopped for c in s['collisions'])
    result = {
        'spot': row['spot'], 'bubble': row['bubble'],
        'implementation': row.get('implementation', 'baseline'),
        'camera_median_ms': statistics.median(timings),
        'camera_p95_ms': timings[int(len(timings)*.95)],
        'camera_max_ms': max(timings),
        'total_motion_m': sum(s['step'] for s in samples),
        'stopped_ticks': len(stopped),
        'frozen_ticks': sum(s['frozen'] for s in samples),
        'stopped_contacts': contacts.most_common(6),
    }
    if 'wall_us' in samples[0]:
        wall = sorted(s['wall_us']/1000 for s in samples)
        result.update(wall_interval_p95_ms=wall[int(len(wall)*.95)],
                      wall_interval_max_ms=max(wall),
                      intervals_over_100ms=sum(w>100 for w in wall))
    result['zero_requested_motion_ticks'] = sum(
        all(float(v) == 0 for v in s['input'].strip('()').split(',')) for s in samples)
    summary.append(result)
print(json.dumps(summary, indent=2))
(root / 'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
