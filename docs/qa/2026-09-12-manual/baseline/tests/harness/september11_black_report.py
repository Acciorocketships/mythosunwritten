"""Classify completed orbit runs; clean runs are reproduction attempts, not fixes."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageChops, ImageDraw

root = Path(__file__).resolve().parents[2] / 'docs/qa/2026-09-11-manual/04-black'
summary = {}
for path in sorted(root.glob('*/orbit.json')):
    rows = json.loads(path.read_text())
    summary[path.parent.name] = {
        'sampled_frames': len(rows),
        'last_sampled_tick': max((r['tick'] for r in rows), default=-1),
        'partial_frames': sum(r['partial'] for r in rows),
        'whole_black_readbacks': sum(r['black_fraction'] >= .95 for r in rows),
        'max_black_fraction': max((r['black_fraction'] for r in rows), default=0),
    }
(root / 'reproduction-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
gpu_summary = {}
for path in sorted(root.glob('*/gpu-frames.json')):
    rows = json.loads(path.read_text())
    anomalous = [r for r in rows if r['black'] > 184 or r['invalid']]
    gpu_summary[path.parent.name] = {
        'frames':len(rows),
        'contiguous_frames': [r['frame'] for r in rows] == list(range(len(rows))),
        'max_black_samples':max((r['black'] for r in rows),default=0),
        'max_invalid_samples':max((r['invalid'] for r in rows),default=0),
        'max_invalid_rgb_samples':max((r.get('invalid_rgb',0) for r in rows),default=0) if all('invalid_rgb' in r for r in rows) else None,
        'complete_sample_counts':all(r['samples']==9216 for r in rows),
        'scene_frame_identity':{
            'matched':sum(r.get('tag_matches') is True for r in rows),
            'mismatched':sum(r.get('tag_matches') is False and r.get('expected_tick',-1)>=0 for r in rows),
            'unmapped':sum('tag_matches' in r and r.get('expected_tick',-1)<0 for r in rows),
            'unmarked':sum('tag_matches' not in r for r in rows),
        },
        'excluded_reason':'Stale alternating HDR images and wholly black viewport/UI readbacks.' if path.parent.name=='gpu-original-short' else None,
        'anomalies':anomalous,
    }
(root / 'gpu-summary.json').write_text(json.dumps(gpu_summary,indent=2)+'\n')

# The HDR preview uses one documented tone curve and marks nonfinite values
# magenta. Its differences are diagnostic, not final-frame colour acceptance.
current = root / 'gpu-current/gpu-frames.json'
if current.exists():
    current_rows = {r['frame']:r for r in json.loads(current.read_text())}
    pairs = []
    panels = []
    for source in ('gpu-original','gpu-original-repeat'):
        for before in json.loads((root/source/'gpu-frames.json').read_text()):
            frame = before['frame']
            a_path, b_path = root/source/f'gpu-{frame:05d}.png', root/'gpu-current'/f'gpu-{frame:05d}.png'
            if not (a_path.exists() and b_path.exists() and frame in current_rows):
                continue
            after = current_rows[frame]
            assert before['camera'] == after['camera'], (source,frame)
            a,b = Image.open(a_path).convert('RGB'),Image.open(b_path).convert('RGB')
            av,bv = np.asarray(a),np.asarray(b)
            invalid = np.all(av == [255,0,255],axis=2)|np.all(bv == [255,0,255],axis=2)
            delta = np.abs(av.astype(np.int16)-bv.astype(np.int16))
            pairs.append({'source':source,'frame':frame,'same_camera':True,
                          'before_black':before['black'],'after_black':after['black'],
                          'before_invalid':before['invalid'],'after_invalid':after['invalid'],
                          'invalid_marker_pixels':int(invalid.sum()),
                          'finite_preview_mean_rgb_delta':float(delta[~invalid].mean())})
            panels.append((frame,a,b,ImageChops.difference(a,b).point(lambda x:min(255,x*4))))
    if panels:
        contact = Image.new('RGB',(1152,len(panels)*242),'#20242b')
        labels = ImageDraw.Draw(contact)
        for row,(frame,a,b,diff) in enumerate(panels):
            for column,(name,picture) in enumerate((('Archived',a),('Current',b),('Preview difference x4',diff))):
                labels.text((column*384+8,row*242+4),f'{name} | HDR frame {frame}',fill='white')
                contact.paste(picture.resize((384,216),Image.Resampling.NEAREST),(column*384,row*242+24))
        contact.save(root/'gpu-pairs.png')
        (root/'gpu-pairs.json').write_text(json.dumps(pairs,indent=2)+'\n')

# Fresh embedded failures have an independent scene marker, unlike the earlier
# unmarked diagnostics. Compare only the matching camera and marker values.
failure_path = root/'embedded-first-failure/verified-failure.json'
repeat_path = root/'embedded-current-repeat/gpu-frames.json'
if failure_path.exists() and repeat_path.exists():
    current_rows = {r['frame']:r for r in json.loads(repeat_path.read_text())}
    embedded_pairs = []
    sheet = Image.new('RGB',(1152,484),'#20242b')
    labels = ImageDraw.Draw(sheet)
    for index,before in enumerate(json.loads(failure_path.read_text())['fresh_anomalies']):
        frame = before['frame']
        after = current_rows[frame]
        assert before['camera'] == after['camera']
        assert before['rendered_tick'] == after['rendered_tick']
        assert before['tag_matches'] and after['tag_matches']
        a = Image.open(root/'embedded-first-failure'/f'gpu-{frame:05d}.png').convert('RGB')
        b = Image.open(root/'embedded-current-repeat'/f'gpu-{frame:05d}.png').convert('RGB')
        av,bv = np.asarray(a),np.asarray(b)
        invalid = np.all(av==[255,0,255],axis=2)|np.all(bv==[255,0,255],axis=2)
        delta = np.abs(av.astype(np.int16)-bv.astype(np.int16))
        embedded_pairs.append({'frame':frame,'camera':before['camera'],
            'rendered_tick':before['rendered_tick'],'same_verified_pose':True,
            'before_black':before['black'],'after_black':after['black'],
            'before_invalid_rgb':before['invalid_rgb'],'after_invalid_rgb':after['invalid_rgb'],
            'invalid_preview_pixels_excluded':int(invalid.sum()),
            'finite_preview_mean_rgb_delta':float(delta[~invalid].mean()),
            'finite_preview_changed_over_20_fraction':float((delta.max(axis=2)[~invalid]>20).mean())})
        diff = ImageChops.difference(a,b).point(lambda x:min(255,x*4))
        for column,(name,picture) in enumerate((('Original failure',a),('Current',b),('HDR preview difference x4',diff))):
            labels.text((column*384+8,index*242+4),f'{name} | frame {frame}',fill='white')
            sheet.paste(picture.resize((384,216),Image.Resampling.NEAREST),(column*384,index*242+24))
    sheet.save(root/'embedded-failure-pairs.png')
    (root/'embedded-failure-pairs.json').write_text(json.dumps(embedded_pairs,indent=2)+'\n')

metrics = []
sheet = Image.new('RGB', (1440, 4*300), '#20242b')
draw = ImageDraw.Draw(sheet)
for index, tick in enumerate((0, 180, 360, 540)):
    a = Image.open(root / f'window-metal/{tick:04d}.png').convert('RGB')
    b = Image.open(root / f'window-vulkan/{tick:04d}.png').convert('RGB')
    assert a.size == b.size
    delta = np.abs(np.asarray(a).astype(np.int16)-np.asarray(b).astype(np.int16))
    metrics.append({'tick':tick,'mean_rgb_delta':float(delta.mean()),
                    'changed_over_20_percent':float((delta.max(axis=2)>20).mean()*100)})
    difference = ImageChops.difference(a,b).point(lambda x:min(x*4,255))
    for column, (label, picture) in enumerate((('Metal',a),('Vulkan',b),('Difference ×4',difference))):
        draw.text((column*480+10,index*300+8), f'{label} | orbit tick {tick}', fill='white')
        sheet.paste(picture.resize((480,270)),(column*480,index*300+28))
sheet.save(root / 'driver-comparison.png')
(root / 'driver-comparison.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps({'runs':summary,'driver_pairs':metrics},indent=2))
