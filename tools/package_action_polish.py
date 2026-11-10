"""Package real Godot captures at their recorded physics-frame timing."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
for mode in ['prototype','gameplay']:
    paths = sorted((ROOT/'.godot'/f'polish_{mode}').glob('*.png'))
    if not paths:
        raise SystemExit(f'Capture {mode} first')
    frames, durations = [], []
    for index, path in enumerate(paths):
        tick = int(path.stem)
        with Image.open(path) as source:
            frame = source.convert('RGB').resize((800,450),Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(frame)
        draw.rectangle((0,0,800,26),fill='#221633')
        label = 'HIGH JUMP' if tick<90 else 'MOVING KICK' if tick<145 else 'SPRINT + SPACE: FORWARD DIVE' if tick<235 else 'RECOVERY'
        draw.text((12,8),label,fill='white')
        frames.append(frame.quantize(colors=160))
        next_tick = int(paths[index+1].stem) if index+1<len(paths) else tick+2
        durations.append(max(20,round((next_tick-tick)*1000/60)))
    output = ROOT/'docs'/('action_polish.gif' if mode=='prototype' else 'action_polish_gameplay.gif')
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=True,disposal=2)
    print('Saved',output,'frames',len(frames),'duration_ms',sum(durations))

    sheet = Image.new('RGB',(1200,720),'#221633')
    for index,tick in enumerate([108,114,122,186,198,212]):
        path = min(paths,key=lambda item: abs(int(item.stem)-tick))
        with Image.open(path) as source:
            crop = source.convert('RGB').crop((300,110,660,410)).resize((400,334),Image.Resampling.LANCZOS)
        x,y=(index%3)*400,(index//3)*360
        sheet.paste(crop,(x,y+26))
        ImageDraw.Draw(sheet).text((x+12,y+8),f'{"Moving kick" if index<3 else "Dive"} - frame {path.stem}',fill='white')
    sheet.save(ROOT/'docs'/f'action_polish_{mode}_poses.png')
