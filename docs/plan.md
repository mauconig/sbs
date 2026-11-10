# Mega Battle Football — Project Plan & Progress

**Last updated:** 10 November 2026
**Current milestone:** Visual prototype - local kit shop and character polish
**Previous:** M1 — playable feel prototype ✅
**Engine:** Godot 4.7.2 stable · GDScript · Jolt physics · Compatibility renderer

**Active presentation work:** the Lavender Dome visual prototype is now the
default scene, using the Compatibility renderer. Press **B** or click **SHOP**
on the right to open the kit editor. The M2 sandbox and the
gameplay roadmap below are preserved; this visual phase adds no networking or
backend work.

## Task board - work one ID at a time

The active phase is the visual prototype and basic local movement. The older
milestones below record the broader game design; they do not expand the current
scope. Networking, items, backend work and advanced AI are deferred.

Each checkbox is one deliverable. Mark it done only after its acceptance check
passes; attach an actual Godot screenshot for visible changes. Start with the
first unchecked task in the active group. IDs are stable so we can request
individual tasks, for example `VIS-01` or `ANIM-04`.

### Completed foundations

- [x] BASE-01 - Import the supplied Meshy mesh as Pip's default in both scenes. Acceptance: both instantiate the same GLB with its 32-bone rig.
- [x] BASE-02 - Import the six supplied Mixamo clips. Acceptance: Godot loads walk, run, jump, kick, slide and charge on the base rig.
- [x] ANIM-01 - Author a natural idle. Acceptance: arms hang beside the thighs, feet stay planted, chest breathes; four-view render saved.
- [x] MOVE-01 - Double movement and animation speed. Acceptance: visual scene uses 5.4 / 8.4 units/s, gameplay uses 16 / 23, and imported clips advance at 2x.
- [x] MOVE-02 - Keep jumping active while walking or running. Acceptance: hold W, press Space, keep horizontal travel, land into walk/run; releasing W in air preserves the jump until landing.
- [x] ANIM-02 - Ground the supplied sweep. Acceptance: remove duplicate tilts and baked horizontal travel, keep the skinned surface near turf throughout the clip, finish the get-up and return to locomotion.
- [x] BASE-03 - Reduce the current characters by 25% and remove retired character assets and procedural builders. Acceptance: both scenes use only the Meshy model, with resized gameplay collision shapes.
- [x] MOVE-03 - Give the sweep an initial advantage and a recovery cost. Acceptance: in the same 0.5 s window it covers about 28% more ground than sprinting, brakes to zero, then ignores movement/jump input for 0.55 s before releasing control.

### Completed local customization

- [x] KIT-01 - Separate shirt, shorts, exposed legs, socks and boots into skinned meshes with clean seams. Shorts end at the two sculpted inner cuff loops instead of a flat height slice; the full cuff stays garment-colored. Legs share the head/arm skin material, including live color changes.
- [x] KIT-02 - Add a shop drawer to the right of the sandbox with a rotating live preview, front/back views and three kit presets. Opening it pauses movement, ball physics and kicking; closing restores the previous state.
- [x] KIT-03 - Give each clothing part independent primary/accent colors and solid, stripes, hoops, split and diagonal patterns. Rest-space UVs keep patterns attached during animation.
- [x] KIT-04 - Print a player name and two-digit shirt number on the back with configurable ink. The print follows the skinned mesh and does not appear on the front.
- [x] KIT-05 - Save only when Equip is pressed, discard uncommitted drafts on close, and load the equipped kit for the local player in sandbox and 1v1 without recoloring opponents. Validated with an isolated save and rendered shop captures.

### Active visual backlog - suggested order

- [ ] VIS-01 - Smooth the blank model's shading. Acceptance: silhouette is unchanged, visible faceting is reduced, normals look correct from four directions.
- [ ] VIS-02 - Paint the base skin material. Depends on VIS-01. Acceptance: an original warm skin palette reads consistently in arena and studio lighting.
- [ ] VIS-03 - Add the character's cartoon eyes. Depends on VIS-02. Acceptance: whites, purple pupils and highlights are readable from the gameplay camera.
- [ ] VIS-04 - Add eyebrows, nose and mouth. Depends on VIS-03. Acceptance: the face reads as determined at gameplay distance.
- [ ] VIS-05 - Build the rounded swept hairstyle. Acceptance: front, side and back silhouettes match the approved broad proportions and follow the head bone.
- [ ] VIS-06 - Add the striped pink jersey. Acceptance: clean panels, collar and sleeve trim deform through run, jump and sweep without detached geometry.
- [ ] VIS-07 - Add shorts, socks and shoes. Depends on VIS-06. Acceptance: colors and proportions form one coherent kit, soles meet turf in idle.
- [ ] VIS-08 - Add number 10 and an original crest. Depends on VIS-06. Acceptance: markings are legible and stay attached during animation.
- [ ] ANIM-03 - Synchronize walking and running foot speed with travel. Acceptance: side-on recording shows reduced foot sliding at both normal and sprint speeds in both scenes.
- [x] ANIM-04 - Tune gameplay jump takeoff and landing. Depends on MOVE-02. Acceptance: skeletal motion and physical height form one jump, with no extra lift or abrupt landing snap. Normal jump now reaches about 2.7 units, with controller-owned height and grounded source poses.
- [x] ANIM-07 - Add the forward sprint-jump dive. Acceptance: sprint + Space extends the arms, retains forward impulse after input release, lands and recovers in both scenes.
- [x] ANIM-08 - Keep kicks animated during locomotion. Acceptance: a distinct moving-kick clip preserves support-leg steps and forward travel, with feet on the turf.
- [ ] ANIM-05 - Align the kick contact frame with ball release. Acceptance: a side-on recording shows the foot meeting the ball when it launches.
- [ ] ANIM-06 - Add an authored celebration. Depends on VIS-04. Acceptance: arm raise, hop and happy expression play once and recover cleanly.
- [ ] VIS-09 - Create a second hairstyle. Depends on VIS-05. Acceptance: rounded curls produce a distinct readable silhouette on the shared rig.
- [ ] VIS-10 - Create a third hairstyle. Depends on VIS-05. Acceptance: short rounded spikes produce another distinct silhouette.
- [ ] VIS-11 - Assemble four finished character variants. Depends on VIS-08, VIS-09, VIS-10. Acceptance: four characters have distinct hair, palette, number and expression in one arena capture.
- [ ] ENV-01 - Refine purple beams and lavender wall panels. Acceptance: coherent repeating modules, no visible gaps, characters remain the focal point.
- [ ] ENV-02 - Refine turf and field markings. Acceptance: subtle green stripes and crisp aligned lines at the reference camera angle.
- [ ] ENV-03 - Refine orange goals and white nets. Acceptance: rounded frame corners, consistent net spacing and clean turf contact.
- [ ] ENV-04 - Refine the football surface. Acceptance: dark panels read clearly and the sphere has an appealing highlight and contact shadow.
- [ ] LIGHT-01 - Balance arena lighting. Acceptance: readable white and skin surfaces, soft lavender shadows and no clipped highlights in the same comparison shot.
- [ ] CAM-01 - Tune the initial arcade composition. Acceptance: foreground player and ball, nearby cast, goal and arena architecture are all visible at 16:9.
- [ ] UI-01 - Refine the scoreboard and energy bar. Acceptance: consistent outlines, bold legible numbers and clean scaling at 720p and 1080p.
- [ ] FX-01 - Add restrained landing and sweep dust. Depends on ANIM-02, ANIM-04. Acceptance: effects appear at ground contact and stop after the action.
- [ ] PERF-01 - Profile the finished visual scene at 1080p. Acceptance: record frame time, draw calls, triangle count and actual GPU; do not claim integrated-GPU results from an RTX test.
- [ ] QA-01 - Review the final prototype against the reference. Depends on VIS-11, LIGHT-01, CAM-01, UI-01. Acceptance: save a new camera capture, list remaining perceptual differences and confirm no Godot errors.

### Deferred gameplay backlog - activate after the visual phase

- [ ] GAME-01 - Add a one-second kickoff countdown; movement stays locked until GO.
- [ ] GAME-02 - Add the two-minute match clock; pause and round reset preserve the correct remaining time.
- [ ] GAME-03 - Add the end-of-match result screen and local restart.
- [ ] GAME-04 - Add a second local input slot; each controller operates only its own player.
- [ ] GAME-05 - Playtest the existing defensive bot; record wide-area chasing and dribble failures before changing behavior.
- [ ] GAME-06 - Add one reusable item pickup and inventory slot; verify pickup, use and drop before creating individual items.
- [ ] GAME-07 - Implement Rocket as the first item; verify player hits, ball hits and own goals locally.
- [ ] GAME-08 - Split each remaining item into its own task after GAME-07 is reviewed.
- [ ] NET-01 - Prototype host-authoritative local-network movement only; two clients must observe the same positions.
- [ ] NET-02 - Synchronize the host-owned ball and scoring; clients cannot create a second authoritative ball.
- [ ] NET-03 - Add local-player prediction and correction; record behavior with simulated latency.
- [ ] NET-04 - Add room-code joining and connection errors after the local-network prototype works.
- [ ] CUP-01 - Build one alternate arena using shared modules and explicit physics parameters.
- [ ] CUP-02 - Add three-arena rotation and cumulative points; verify a tie enters sudden death.

### Current verification

Use `tools/capture_prototype_actions.gd` for held movement + jump/sweep renders,
`tools/capture_sweep.gd` (and `-- --gameplay`) for sprint comparison, braking and
input lock during recovery,
`tools/capture_action_polish.gd` (and `-- --gameplay`) for high jumps, moving
kicks and forward dives with measured heights/distances,
`tools/capture_player_motion.gd` for the playable sandbox,
`tools/test_visual.gd` for presentation controls, and
`tools/test_meshy_animation.gd` for real bone movement. Visible existence of a
clip in AnimationPlayer is not sufficient proof that it animates correctly.

9 November verification: held walking/running jumps and sweep recovery pass in
the default scene; moving jump and sweep pass in the M2 sandbox. Blender checks
all 105 slide frames for ground contact and zero horizontal root travel.
Evidence: [running jump](action_jump_run.png), [grounded sweep](action_sweep.png),
[gameplay sweep](meshy_game_sweep.png).

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
| Look | Chibi characters, rounded silhouettes, bright purple-and-lavender indoor arena. |

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

These are the original product milestones, not an active schedule. Use the
individual task board above for current work; online play remains deferred.

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
| Walk / sprint | 16.0 / 23.0 m/s |
| Accel / decel | 140 / 90 m/s² |
| Gravity | 26 m/s² |
| Stamina | 100 max · 14/s drain · 25/s regen · 0.5 s delay |
| Exhaustion | 1.2 s walk-only at 0 stamina; sprint needs > 10 |
| Dribble | 1.45 m radius · 22 grip · 14 m/s relative-speed limit |

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

### Original M1 verification (historical tuning)

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
- **Human sweep / slide tackle** (Ctrl / B): 0.16 s burst at 2.4x sprint speed,
  0.32 s braking, then 0.55 s stationary recovery. Cooldown is 1.3 s.
  Hit radius is 1.55 m, knockback 9 m/s and knockdown 1.7 s.
- The imported sweep reaches the end of its slide when travel stops, then plays
  its get-up during recovery. Root travel is owned by the controller; ground
  contact is baked against the skinned mesh surface.
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
- The default Meshy character is still untextured; facial features and kit remain on the visual task board
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
