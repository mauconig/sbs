# ⚽ Mega Battle Football

A 2v2–4v4 arcade football game where nobody dies, everyone plays at once, and the
ball can be hit into the net with a rocket. Currently at **M1: the playable feel
prototype** — one player, one ball, two goals and a training keeper.

![prototype screenshot](docs/screenshot.png)

## Run it

Godot **4.7.2** (installed via `winget install GodotEngine.GodotEngine`).

```bat
run.bat
```

Or open the project folder in the Godot editor and press F5.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Run | WASD / arrows | Left stick |
| Sprint | Shift | RB / RT |
| Charge kick | Hold left mouse | Hold X |
| Curve the kick | A / D while charging | Left stick X while charging |
| Aim | Move the mouse | Right stick |
| Zoom camera | Mouse wheel | — |
| Reset | R | — |
| Release mouse | Esc | — |

**Kick rules:** 0.75 s to full charge. 7 m/s at a tap, 24 m/s at full power.
Charging inside the **80–95 % sweet spot** gives 1.15× power, a gold trajectory
and a hit-stop. Overcharging past 95 % gives max power but no bonus — the meter
turns red.

## What is already in this build

- 32 × 20 m walled arena with markings, bleachers and night-stadium lighting
- `CharacterBody3D` player: camera-relative movement, sprint with generous
  stamina (100 max, 14/s drain, 25/s regen), smooth turning
- **Magnetic dribbling**: the ball is pulled to a point in front of your feet and
  trapped when you stand still; it breaks free when hit or kicked
- **Charge kick** with loft, curve and screen shake
- Dotted trajectory preview + landing ring
- Two goals with net, posts and detection areas; score, banner, auto-reset
- Training keeper that tracks the ball and blocks shots
- HUD: charge meter with sweet-spot band, stamina bar, goals/shots counters

## Tuning knobs

Everything that matters is an `@export` on these scripts:

| File | Knobs |
|---|---|
| `scripts/player.gd` | walk/sprint speed, acceleration, stamina, dribble radius and grip |
| `scripts/kick_controller.gd` | charge time, min/max power, sweet spot, loft, curve, kick range |
| `scripts/ball.gd` | mass, bounce (physics material), curve decay, rolling friction |
| `scripts/chase_camera.gd` | distance, pitch, mouse sensitivity, follow lag |
| `scripts/arena_builder.gd` | arena size, wall height, goal width |

Change values while the game is running is not supported yet — edit and restart,
or open the project in the editor and tweak the exported values on the running
scene.

## Project layout

```
project.godot
scenes/main.tscn          entry point (a single Node3D + main.gd)
scripts/
  main.gd                 builds the sandbox, owns scoring/reset
  arena_builder.gd        floor, markings, walls, bleachers
  player.gd               movement, stamina, dribbling
  kick_controller.gd      charge/release, curve, trajectory preview
  ball.gd                 physics ball, curve force, rolling friction
  ball_trail.gd           speed trail
  chase_camera.gd         third-person camera
  goal.gd                 frame, net shader, detection area
  keeper_dummy.gd         sandbox-only training keeper
  juice.gd                autoload: screen shake + hit-stop
  input_hub.gd            keyboard/mouse or gamepad input source
  ribbon.gd               immediate-mode ribbon helper
  ui/hud.gd, ui/hud_painter.gd
tools/
  capture.gd              renders a screenshot
  test_play.gd            headless: kick, goal detection, reset
  test_move.gd            headless: sprint, dribble, stamina, kick
  scripted_input.gd       fake input for tests
```

## Dev commands

```bat
godot --headless --path . --script tools/test_play.gd
godot --headless --path . --script tools/test_move.gd
godot --path . --script tools/capture.gd --resolution 1600x900
```

## Design (locked decisions)

- 2v2–4v4, humans only, no match starts below 2v2
- 3 arenas × 2 min, 1 point per goal, cup by total, sudden death on a tie
- Walled arena, no out of bounds, small goals, no goalkeepers
- Stagger → Slip → Knockdown → Launch. **Nobody dies or respawns.**
- Getting hit while down is possible but knockback is halved
- Items: Rocket, Orbital Strike, Ball Bomb, Giant Boot, Banana Peels, Freeze Shot,
  Multiball, Shield Bubble. One slot, dropped when knocked down, friendly fire on
- Multiball is a rare item: 3 balls for 20 s or until a goal
- Listen-server netcode, room codes

## Next milestone (M2)

Local 1v1: second player, slide tackles, the four hit tiers, kickoff restarts and
a match timer.
