"""Package native Godot renders for review. Requires Pillow; not a game dependency."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
paths = sorted((root / ".godot" / "visual_motion_frames").glob("*.png"))
assert len(paths) == 288, "Run tools/capture_motion.gd before packaging"
with Image.open(paths[0]) as first:
    palette = first.convert("RGB").quantize(colors=256)
frames = []
for path in paths:
    with Image.open(path) as source:
        frames.append(source.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE))
frames[0].save(root / "docs" / "animation_preview.gif", save_all=True,
               append_images=frames[1:], duration=33, loop=0, optimize=True, disposal=1)
print("Saved docs/animation_preview.gif")
