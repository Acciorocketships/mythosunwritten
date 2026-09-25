"""Contact sheet: sheet.py OUT.png IN1 IN2 ... (2 columns, half size)."""
import sys
from PIL import Image
out, paths = sys.argv[1], sys.argv[2:]
ims = [Image.open(p).convert('RGB') for p in paths]
w, h = ims[0].size[0] // 2, ims[0].size[1] // 2
rows = (len(ims) + 1) // 2
sheet = Image.new('RGB', (w * 2, h * rows), 'white')
for i, im in enumerate(ims):
    sheet.paste(im.resize((w, h)), ((i % 2) * w, (i // 2) * h))
sheet.save(out)
