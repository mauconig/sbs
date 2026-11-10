"""Package the real sprint/sweep comparisons at the recorded simulation timing."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
for mode in ['prototype','gameplay']:
    paths = sorted((ROOT/'.godot'/f'sweep_{mode}').glob('*.png'))
    if not paths:
        raise SystemExit(f'Capture {mode} with tools/capture_sweep.gd first')
    frames, durations = [], []
    for index,path in enumerate(paths):
        with Image.open(path) as source:
            frame = source.convert('RGB').resize((800,450),Image.Resampling.LANCZOS)
        frames.append(frame.quantize(colors=128))
        tick = int(path.stem)
        next_tick = int(paths[index+1].stem) if index+1<len(paths) else tick+2
        durations.append(max(20,round((next_tick-tick)*1000/60)))
    output = ROOT/'docs'/('sweep_comparison.gif' if mode=='prototype' else 'sweep_comparison_gameplay.gif')
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=True,disposal=2)
    print('Saved',output,'frames',len(frames),flush=True)
