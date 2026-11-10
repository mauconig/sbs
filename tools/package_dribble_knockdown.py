"""Package the rendered possession and sweep-contact validation into review images."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
files = sorted((ROOT / '.godot/dribble_knockdown_frames').glob('*.png'))
if len(files) < 139:
    raise RuntimeError('Run tools/capture_dribble_knockdown.tscn to record all scenarios first')
frames = [Image.open(path).convert('RGB').resize((800, 450)) for path in files]
palette_source = Image.new('RGB', (800, 450 * 4))
for row, index in enumerate([15, 35, 62, 124]):
    palette_source.paste(frames[index], (0, row * 450))
palette = palette_source.quantize(colors=112)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
indexed[0].save(ROOT / 'docs/dribble_knockdown.gif', save_all=True,
                append_images=indexed[1:], loop=0, duration=34, disposal=2)
sheet = Image.new('RGB', (1600, 1350), '#252034')
for tile, index in enumerate([16, 36, 51, 62, 84, 124]):
    sheet.paste(frames[index], ((tile % 2) * 800, (tile // 2) * 450))
sheet.save(ROOT / 'docs/dribble_knockdown_review.png')
print('REVIEW', len(frames), 'frames -> docs/dribble_knockdown.gif and docs/dribble_knockdown_review.png')
