"""Native screenshot differences plus independent opaque/receiver controls.
Usage: python september12_visibility_diff.py <receiver-final directory>
"""
from pathlib import Path
import json
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
summary = {}
for site in sorted(root.iterdir()):
    if not (site / 'opaque').is_dir():
        continue
    subprocess.run([sys.executable, str(Path(__file__).with_name('september10_pixel_diff.py')),
                    str(site / 'before'), str(site / 'after'), str(site / 'diff')],
                   check=True, stdout=subprocess.DEVNULL)
    controls = {}
    canvas = Image.new('RGB', (1716, 1119), '#202329')
    draw = ImageDraw.Draw(canvas)
    for row, angle in enumerate([0, -8, 8]):
        key = f'{site.name}_{angle}'
        opaque = np.array(Image.open(site / 'opaque' / f'{key}.png'))[:, :, :3].astype(int)
        before = np.array(Image.open(site / 'before' / f'{key}.png'))[:, :, :3]
        after = np.array(Image.open(site / 'after' / f'{key}.png'))[:, :, :3].astype(int)
        receiver = np.array(Image.open(site / f'receiver_{angle}.png'))[:, :, :3]
        assert opaque.max() > 0 and before.max() > 0 and after.max() > 0, f'Invalid wholly black capture: {key}'
        missing = receiver.max(2) == 0
        difference = np.abs(opaque - after).max(2)
        controls[key] = {
            'no_receiver_pixels': int(missing.sum()),
            'changed_no_receiver': int(((difference > 0) & missing).sum()),
            'changed_no_receiver_over_20': int(((difference > 20) & missing).sum()),
            'no_receiver_max_difference': int(difference[missing].max()) if missing.any() else 0,
        }
        for column, phase in enumerate(['before', 'after', 'diff']):
            suffix = '_diff' if phase == 'diff' else ''
            image = Image.open(site / phase / f'{key}{suffix}.png').convert('RGB')
            image.thumbnail((572, 345))
            canvas.paste(image, (column * 572, row * 373 + 28))
            draw.text((column * 572 + 8, row * 373 + 8), f'{phase} | yaw {angle}', fill='white')
    canvas.save(site / 'judging.png')
    (site / 'receiver-validation.json').write_text(json.dumps(controls, indent=2) + '\n')
    summary[site.name] = {
        'difference': json.loads((site / 'diff' / 'metrics.json').read_text()),
        'receiver_control': controls,
    }
(root / 'pixel-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps({name: entry['receiver_control'] for name, entry in summary.items()}, indent=2))
