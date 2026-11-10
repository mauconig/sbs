"""Package the real Godot idle/run capture into a small review GIF."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
frames_dir = ROOT / ".godot" / "meshy_motion_frames"
paths = sorted(frames_dir.glob("*.png"))
if len(paths) < 30:
    raise SystemExit("Run tools/capture_meshy_animation.gd before packaging")

with Image.open(paths[0]) as first:
    palette = first.convert("RGB").quantize(colors=192)
frames = []
for path in paths:
    with Image.open(path) as source:
        # Focus the review artifact on the player; the full arena capture stays
        # available as PNGs under .godot/meshy_motion_frames for comparison.
        focused = source.convert("RGB").crop((400, 195, 560, 435))
        focused = focused.resize((400, 600), Image.Resampling.LANCZOS)
        frames.append(focused.quantize(colors=192, dither=Image.Dither.NONE))

output = ROOT / "docs" / "meshy_animation.gif"
frames[0].save(
    output,
    save_all=True,
    append_images=frames[1:],
    duration=100,
    loop=0,
    optimize=True,
    disposal=1,
)
print("Saved", output, "from", len(frames), "Godot frames")
