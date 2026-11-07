# Mega Battle Football — Project Plan & Progress

**Last updated:** 7 November 2026
**Current milestone:** M2 — 1v1 vs AI + tackles (in progress)
**Previous:** M1 — playable feel prototype ✅
**Engine:** Godot 4.7.2 stable · GDScript · Jolt physics · Forward+

---

## 1. What the game is

A 2v2–4v4 arcade football game in the spirit of *Super Battle Golf*: everyone
plays at the same time, the ball is a physics object, and the whole point is
finishing first by any means necessary. Nobody dies, nobody respawns — getting
blasted across the arena just costs you time and position.

**Pillars**

1. **No turns.** Every player is always live.
2. **A skill-based strike.** Charge, sweet spot, loft and curve.
3. **Sabotage over sport.** Items, friendly fire, multiball chaos.
4. **Readable chaos.** Chunky silhouettes, dot trajectories, gold sweet spots.

---

## 2. Locked design decisions

These came out of the design Q&A and are not up for re-litigation without a
playtest reason.

### Match

| Rule | Decision |
|---|---|
| Players | **2v2 – 4v4, humans only.** A match will not start below 2v2. No bots. |
| Session | **3 arenas × 2 min.** 1 point per goal. Cup = total points. Tie → sudden death. |
| Pitch | Walled arena, **no out of bounds**. Small goals. **No goalkeepers.** |
| Kickoff | Ball at centre, **item box at centre**, 1 s countdown, both teams on their halves, then a sprint scramble. |
| Camera | Chase cam behind your own player. |
| Hosting | Listen server (host player simulates). |
| Joining | **Room codes** first, quick-match later. |
| Look | Chunky low-poly cartoon, thick shapes, night stadium. |

### Hit model

No elimination, no respawns. Four tiers:

| Tier | Cause | Result |
|---|---|---|
| **Stagger** | normal tackle | 0.5 s stumble, lose the ball, stay on your feet |
| **Slip** | banana peels | 1.5 s sprawl, drop ball + item, get up where you fell |
| **Knockdown** | Giant Boot, heavy hits | 2 s ragdoll + slide, drop ball + item, get up where you land |
| **Launch** | Rocket, Orbital Strike, Ball Bomb | 2.5–3 s ragdoll, ~14 m/s horizontal / 4 m/s up knockback, bounces off walls, drop ball + item, get up where you land |

**Juggling:** a player already ragdolled can be hit again, but knockback is
**halved and has no upward launch** — no hard stunlock.

**Recovery:** stand up where you land, then **1 s of protection**.

**Loot on hit:** any knockdown drops both the ball and the carried item. Anyone
can take them, including the enemy team.

### Items

8 items, **one slot**, activated manually. **4 boxes** on the pitch, **12 s
respawn**, duplicates allowed. Knocked down → item drops.

| Item | Effect | On hit |
|---|---|---|
| **Rocket** | Straight projectile ~25 m, explodes | Launch |
| **Orbital Strike** | Designator, 1.5 s telegraph, sky beam, no range limit | Launch (hits you too) |
| **Ball Bomb** | 10 s, your kicks explode on impact | Launch, small radius |
| **Giant Boot** | 15 s, 2× kick power, sends players flying | Knockdown |
| **Banana Peels** | Drop 3 slicks | Slip |
| **Freeze Shot** | One kick freezes the first player hit | Frozen 2 s, drops ball |
| **Multiball** | Splits the ball into 3 for 20 s or until a goal | none |
| **Shield Bubble** | 4 s immunity, ball bounces off you | none |

**Item goals count.** A rocket that knocks the ball into the net is a legitimate
goal — including own goals.

### Arenas

| Arena | Gimmick |
|---|---|
| **The Cage** | Neutral, springy walls. The baseline. |
| **Beach** | Sand slows players 20 %, the ball dies fast. |
| **Ice Rink** | Almost no friction, everyone slides. |

Variety comes from physics parameters, not new art.

---

## 3. Roadmap

| # | Milestone | Est. | Status |
|---|---|---|---|
| **M0** | Setup: Godot, git, project, input, palette | 0.5 h | ✅ done |
| **M1** | **Sandbox feel prototype** — pitch, player, ball, dribble, kick, camera, goal, keeper, HUD, juice | 6–10 h | ✅ done |
| **M2** | **1v1 vs AI** — AI opponent, slide tackles, knockdowns, defences | 4–6 h | 🟡 in progress |
| **M3** | Match flow — 2 min timer, kickoff countdown, restart, local 2P | 3–5 h | ⬜ |
| **M4** | Items — 4 boxes, all 8 items, hit reactions, friendly fire, loot drop | 6–8 h | ⬜ |
| **M5** | Online 2v2 — listen server, room codes, prediction/interpolation | 10–15 h | ⬜ |
| **M6** | Arenas + cup flow — 3 arenas, rotation, scoring, sudden death, lobby gate | 4–6 h | ⬜ |
| **M7** | Presentation — animation, audio, UI polish, settings, cosmetics | ongoing | ⬜ |

**≈ 30–45 h to online 2v2.** M1 was the risk; it is now playable.

---

## 4. M1 — what actually exists

### Built

- 32 × 20 m walled arena: floor, mowing stripes, centre circle, penalty boxes,
  walls with glowing trim, bleachers, night sky, directional sun, SSAO + glow
- `CharacterBody3D` player with a chunky cartoon model (head, jersey, shorts,
  legs, boots, arms, visor)
- Camera-relative movement, acceleration/deceleration, smooth facing
- Sprint + stamina with an exhaustion state
- **Magnetic dribbling** — spring toward a point 0.55 m in front of the feet,
  driven by movement *intent*; the ball is trapped when you stand still and
  breaks free when kicked or hit
- **Charge kick** with power curve, loft, curve, sweet spot, cooldown, whiff
  protection (must be within range and roughly in front)
- **Trajectory preview** as a dotted bead arc + landing ring, gold inside the
  sweet spot
- Ball physics: CCD, bounce, rolling friction, Magnus-style curve force, speed
  trail ribbon
- Two goals with posts, crossbar, grid-shader net, backstop and detection area
- Scoring, GOAL banner, hit-stop, screen shake, auto reset
- Training keeper (sandbox only) that tracks the ball and blocks
- HUD: charge meter with sweet-spot band, stamina bar, goals/shots, control hint
- Headless test harness + screenshot tool

### Current tuning values

**Player** (`scripts/player.gd`)

| Value | Setting |
|---|---|
| Walk / sprint | 8.0 / 11.5 m/s |
| Accel / decel | 70 / 45 m/s² |
| Gravity | 26 m/s² |
| Stamina | 100 max · 14/s drain · 25/s regen · 0.5 s delay |
| Exhaustion | 1.2 s walk-only at 0 stamina; sprint needs > 10 |
| Dribble | 1.45 m radius · 11 grip · 7 m/s relative-speed limit |

**Kick** (`scripts/kick_controller.gd`)

| Value | Setting |
|---|---|
| Charge time | 0.75 s to full |
| Power | 7 m/s tap → 24 m/s full |
| Sweet spot | 80–95 % → 1.15× power |
| Loft | 11° + 4° with charge |
| Curve | up to 7 kN of lateral force, decaying over ~1.5 s |
| Range / cone | 2.0 m, dot > −0.1 |
| Cooldown | 0.25 s |

**Ball** (`scripts/ball.gd`)

| Value | Setting |
|---|---|
| Radius / mass | 0.22 m / 0.44 kg |
| Bounce / friction | 0.55 / 0.65 |
| Rolling friction | 6 m/s² on the ground |
| Damping | 0.04 linear, 0.35 angular |

**Camera** (`scripts/chase_camera.gd`)

| Value | Setting |
|---|---|
| Distance / pitch | 8.2 m / 20° |
| Follow lag | 0.12 s |
| Mouse sensitivity | 0.0028 |
| Pitch clamp | 6°–44° |

### Verified by automated tests

`tools/test_play.gd` (headless)

- Jolt is the active physics engine
- Full-power kick travels ~14 m and scores
- Goal area fires `scored`, banner shows, score increments
- Reset returns ball to centre and player to spawn

`tools/test_move.gd` (headless, scripted input)

- Sprint reaches ~9 m/s while dribbling, stamina drains at ~13.4/s
- Ball stays 0.7–1.2 m in front while running
- Ball is trapped (speed 0.0) when the player stops
- Kick registers (`shots = 1`) and launches the ball at 24 m/s

### Bugs found and fixed in M1

1. **Ball had no collision shape** — fell through the floor and the goal area
   never triggered. Caught by headless tests.
2. **Dribble deadlock** — pushing into a stationary ball froze the player.
   Fixed by driving the ball with movement intent instead of post-collision
   velocity.
3. **Ball rolled forever** — added constant rolling friction when grounded.
4. **Pitch too large** — 40 × 24 read as empty in a chase cam; reduced to
   32 × 20.
5. **Trajectory was unreadable** — a ribbon edge-on to the camera looks like a
   pole; replaced with billboard-friendly beads.

---

## 4b. M2 — 1v1 vs AI + tackles (in progress)

### Built

- **AI opponent** (red kit): defends the far goal, attacks the near goal
- AI behaviour loop: chase the loose ball, drive *through* the ball toward the
  goal, shoot inside 14 m, plant its feet and shoot when the ball is settled,
  slide tackle when the human has the ball
- **Human slide tackle** (Space / B): 0.45 s slide, up to 13.5 m/s, 1.55 m hit
  radius, 9 m/s knockback, 1.7 s knockdown, 1.1 s cooldown, 0.55 s recovery
  after a slide
- **Knockdown**: victim loses control, is pushed, gets up where it lands, then has
  1 s of protection. Works on both the human and the AI.
- Tackle **knocks the ball loose** (8 m/s push) as well as the player
- Per-team scoring: you attack the far goal, the bot attacks the near one
- HUD shows `YOU x — y BOT`, plus a tackle-cooldown bar
- **Keeper removed** — no goalkeepers in this game, by design

### AI tuning (`scripts/bot_brain.gd`)

| Value | Setting | Why |
|---|---|---|
| Think interval | 0.16 s + 0.06 jitter | Beatable reaction time |
| Speed | 94 % of the player | You can outrun it |
| Shoot range | 14 m | Shoots from sensible spots |
| Tackle chance | 45 % per decision | Misses often enough to punish |
| Aim error | ±0.10 rad | Shots can miss the frame |

### Bugs found and fixed in M2

1. **Dribble hold distance was inside the collision radius.** The magnet held the
   ball 0.55 m from the player, but player radius + ball radius = 0.58 m, so the
   bodies were permanently in contact. The physics fought the magnet, balls
   popped into the air and players got stuck. Now 0.78 m ahead + 0.22 m to the
   side.
2. **AI kick desync.** Driving the AI through the human charge/release input
   produced whiffs and stuck charges. Added `force_kick()` so the AI calls the
   kick directly.
3. **Ball fell through the floor inside the goals** — the floor ended exactly at
   the goal line. Now extends 2 m past each wall.
4. **Ball hidden behind the player** in the chase cam. Added a 0.9 m shoulder
   offset and a lateral dribble offset.

### Still open in M2

- Local 2-player (second controller/keyboard)
- Kickoff countdown and a match timer
- The AI can still lose the ball in wide areas and over-chase; needs playtest

---

## 5. Known gaps

Not bugs — just not built yet:

- No items, boxes, multiball, friendly fire, hit reactions beyond the slide
- No match flow: no timer, no kickoff countdown, no cup
- No second local player (the 1v1 opponent is the AI)
- No audio at all
- No character animation (the models slide)
- No menu, lobby, pause, settings or rebinding
- No console/controller hot-plug handling (device 0 is hardcoded)
- No ragdoll physics — knockdowns are a scripted tilt + knockback

---

## 6. Playtest checklist (needs a human at the keyboard)

### Attack

1. **Kick** — is 0.75 s to full charge right? Does a full-power shot feel violent?
2. **Ball weight** — football or beach ball?
3. **Dribbling** — is the ball now readable and controllable while sprinting?
4. **Camera** — is the shoulder offset better? Too far/close? Is the ball visible?
5. **Sweet spot** — are you hitting it deliberately, or always overcharging?
6. **Curve** — can you feel the bend, and is A/D the right input?

### Defence (this pass)

7. **Can you stop the bot?** Tackle it, or is it too slippery?
8. **Tackle feel** — is the slide too fast/slow, too long/short? Does the cooldown
   punish spamming?
9. **Knockdown** — is 1.7 s down + 1 s protection the right punishment, or does it
   feel like nothing?
10. **Can the bot score on you?** If it can't, defence is pointless. If it scores
    at will, it's too hard.
11. **Is defence fun?** Winning the ball should feel as good as shooting.

**Gate:** if you would not voluntarily play 1v1 for 5 minutes, fix that before
adding items.

---

## 7. Technical architecture

```
project.godot
scenes/main.tscn          single Node3D + main.gd (builds the sandbox)
scripts/
  main.gd                 world assembly, scoring, reset, environment
  arena_builder.gd        floor, markings, walls, trim, bleachers
  player.gd               movement, stamina, dribbling, tackles, knockdowns
  kick_controller.gd      charge/release, force_kick for AI, preview
  ball.gd                 RigidBody ball, curve force, rolling friction
  ball_trail.gd           speed ribbon
  chase_camera.gd         third-person shoulder camera
  goal.gd                 frame, net shader, detection area
  bot_brain.gd            AI decisions
  bot_input.gd            AI input source
  juice.gd                autoload: screen shake + hit-stop
  input_hub.gd            keyboard/mouse or gamepad input source
  ribbon.gd               immediate-mode ribbon helper
  ui/hud.gd               counters, banners
  ui/hud_painter.gd       charge meter, stamina bar, tackle bar
tools/
  capture.gd              screenshot
  test_play.gd            headless kick/goal/reset test
  test_move.gd            headless sprint/dribble/kick test
  test_tackle.gd          headless tackle/knockdown test
  test_bot.gd             headless AI test (bot plays alone)
  scripted_input.gd       fake input source
```

**Prototype choice:** gameplay objects are built procedurally in code rather
than in `.tscn` files. This made M1 fast and version-proof; convert the player,
ball and goal to scenes when artists or designers need to edit them.

### Netcode plan (M4)

- Server-authoritative physics, host = listen server
- 60 Hz input, 20 Hz snapshots
- Client-side prediction for your own player, reconciliation on correction
- The ball is simulated **only by the host** and interpolated on clients
- Room codes need a rendezvous service (`code → host IP:port`) plus NAT
  traversal / relay fallback. Budget real time for this — it is the most
  underestimated part of the project.

---

## 8. Top risks

| Risk | Mitigation |
|---|---|
| Kick doesn't feel good | M1 is tunable via exported values; tune before M2 |
| Physics netcode | Host-authoritative ball from day one, not retrofitted |
| Readability with 8 players + multiball | Team outlines, off-screen arrows, zoom-out during multiball |
| Room codes / NAT | Build the rendezvous service early, test across real networks |
| Scope creep | The locked rules in §2 are the firewall: no keepers, no bots, 8 items, 3 arenas |

---

## 9. Decision log

| Date | Decision |
|---|---|
| 7 Nov 2026 | Engine: Godot 4.7.2 + Jolt over browser/Unity |
| 7 Nov 2026 | 2v2–4v4 team football, not free-for-all |
| 7 Nov 2026 | Arena rotation with points, not a timed match |
| 7 Nov 2026 | **No death, no respawns** — ragdoll and recover only |
| 7 Nov 2026 | Rockets can score goals |
| 7 Nov 2026 | Juggling allowed but halved while down |
| 7 Nov 2026 | Multiball is a rare item, not a scheduled phase |
| 7 Nov 2026 | No goalkeepers; the training keeper is sandbox-only |
| 7 Nov 2026 | Friendly fire on, full |
| 7 Nov 2026 | Online-only matches, 2v2 minimum, no bots |
| 7 Nov 2026 | Chase cam over broadcast cam |
| 7 Nov 2026 | Generous stamina bar |
| 7 Nov 2026 | **No goalkeeper** — removed from the build entirely |
| 7 Nov 2026 | 1v1 vs AI added as the defensive testbed before online play |
| 7 Nov 2026 | Tackle = slide with knockdown, not a standing steal |
| 7 Nov 2026 | AI uses a direct `force_kick()` instead of faking charge input |
