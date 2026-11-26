# Mega Battle Football — Project Plan & Progress

**Last updated:** 14 November 2026
**Current milestone:** Visual overhaul - soft "party game" look (reference: Super Battle Golf). Gameplay is frozen during this pass.
**Previous:** Bazooka - football + two item slots, held lock-on launcher and physical ragdolls ✅
**Engine:** Godot 4.7.2 stable · GDScript · Jolt physics · Compatibility renderer

**Presentation:** the Sunline Park visual playground remains the default scene.
Press **F8** to enter local gameplay. The visual sandbox stays separate from the
2v2 match and has no networking or backend systems.

## Task board - work one ID at a time

The active phase is the **visual overhaul** (see "Visual direction" and the "Active visual
board" below). Gameplay, items, networking, backend work and advanced AI are frozen until the
visual pass is approved; the existing gameplay sections are kept as a record.

Each checkbox is one deliverable. Mark it done only after its acceptance check
passes; attach an actual Godot screenshot for visible changes. Start with the
first unchecked task in the active group. IDs are stable so we can request
individual tasks, for example `VIS-01` or `ANIM-04`.

### Active gameplay pass

- [x] GAME-01 - Use one shared 94 × 60 m field and 8 × 3.5 m goals in the match and visual sandbox; resize field lines, arena bounds, goals and resets together. Pitch dimensions follow the approximate size reported by Rematch creative director Pierre Tarno, rather than an exact measurement of its game assets.
- [x] GAME-02 - Replace the tall jump with a 0.6 m hop. The hop clears a sweep only through actual height; carriers cannot hop, sweep or dive.
- [x] GAME-03 - Sprint + Space in the own-goal save zone starts a lateral keeper dive. A/D selects direction, the ball path assists aim, clean contact catches, and a miss has recovery. Bots use the same action.
- [x] GAME-04 - Build local 2v2 with one human, a support AI and two opposing AIs. Only the nearest defender chases; the second covers a lane or the goal.
- [x] GAME-05 - Hold RMB / left trigger to aim. A highlighted teammate selects a pass; otherwise aim at the goal to shoot. Hold/release LMB / X to charge and fire. RMB displays the shot trajectory before charging; releasing RMB hides the trajectory and retains a pending charge's direction. Trace shots against arena and goal-frame colliders.
- [x] GAME-06 - Give goalposts and crossbars physical colliders in both arenas. Confirm match and sandbox scenes load in Godot 4.7.2 and run the movement-rules scene.

Manual playtesting remains useful for tuning keeper timing, pass selection and team spacing.

### Football pace direction

The football foundation should feel physical and deliberate, with the existing chibi models. Items provide the arcade disruption. Movement values below are our initial tuning, not claimed copies of Rematch's internal settings.

- [x] PACE-01 - Use 6 m/s running and 9 m/s sprinting for the human, all AI players and sandbox. Reduce acceleration to 20 m/s² and braking to 26 m/s² in the match. Slow skeletal locomotion cadence with the new pace. A full-pitch sprint takes at least 10.4 seconds before fatigue; sandbox movement stays direct.
- [x] PACE-02 - Sprint drains a full stamina budget in about 3.6 seconds; regeneration waits 1.1 seconds and replenishes at 18 units/s. Exhaustion blocks sprint until at least 28% has recovered. The sandbox energy bar displays actual stamina.
- [x] PACE-03 - Expand both stadium shells, roofs, goal positions, field markings, camera barriers, kickoff positions and keeper zones with the shared 94 × 60 m field. Preserve the scene's close third-person presentation.
- [x] PASS-01 - Replace toggle/crosshair passing with held target selection and a world-space teammate circle. Include aim-cone selection and nearest aligned receiver. A pending pass keeps its receiver when RMB is released; losing a receiver while aiming cancels that pass rather than converting it into a shot.
- [x] PASS-02 - Use the same passing in sandbox and match, including the kicking animation and possession release. Reduce rolling resistance so low passes remain useful across the wider pitch.
- [ ] PACE-04 - Playtest the new 2v2 pacing; tune support distance, shot power, sprint duration and recovery from observed matches.
- [ ] PACE-05 - Align locomotion stride rate and foot contacts with the new movement speeds before claiming final animation polish.

### Aiming, shot power and shared meters

- [x] AIM-01 - RMB controls live aim and the trajectory preview; LMB controls charge/release. Support normal shots when no teammate is highlighted. LMB alone can still shoot, with no trajectory preview.
- [x] AIM-02 - Releasing RMB during an LMB charge preserves its direction and curve. Further camera movement does not redirect that charge; holding RMB again resumes live aim. Releasing LMB fires the stored action.
- [x] SHOT-01 - Share one launch-velocity calculation between physics and preview. Keep 8–40 m/s power and raise elevation progressively with `angle = 4° + 13° × charge²`: controlled medium shots stay lower; full power launches at 17° and can clear the crossbar from about 14 m, then rebound from the clear wall above the goal. Verify real travel beyond 25 m in 0.75 s, goals at medium power, high misses at full power, frame impacts and close-range full-power goals. Releasing RMB retains horizontal direction while continued charging still increases speed and height. Ground passes remain low.
- [x] HUD-01 - Use the playground's exact cream frame, dark extrusion, pink/orange gradient and lightning stamina strip in both modes. Remove the previous match charge/stamina/readiness bars. Put a segmented vertical power meter just right of screen center with matching styling and a sweet-spot marker.
- [x] SHOT-02 - Prevent the presentation sandbox from automatically collecting a fast shot merely because it passes within pickup range; use the match's control-speed limit.

### Daytime stadium and scoreboard

- [x] ARENA-01 - Replace the opaque indoor shell in both scenes with the same transparent 12 m rebound enclosure. Include all four sides, closed corners and panels above both goals; preserve the scoring openings. Ball physics and trajectory previews use the actual wall colliders.
- [x] ARENA-02 - Build Sunline Park outside the enclosure: tiered cyan/pink seating, aisles, concourses, seat canopies, stadium boards, floodlight structures and perimeter apron. Keep the pitch open to a blue daytime sky with shared soft daylight in both scenes. Use batched geometry.
- [x] HUD-02 - Share the centered blue score / timer and 2V2 / pink score layout between both modes, keeping the playground's bold font, dark outlines and layered panels. Match scores update live; the timer retains the existing presentation value until the match-clock task is implemented.
- [x] ARENA-03 - Verify physical rebounds on both side walls, both ends, walls above the goals and both far corners in each scene; verify open goal mouths and normal scoring. Capture and inspect the updated match and playground.

### Map pickups, football slot and bazooka

- [x] ITEM-01 - Match the diagram in both modes: four amber mystery spawners at world `(x,z)=(±20,±24)` and four cyan small boost pads at `(±24,±6)`. The long axis of the supplied diagram maps to world Z.
- [x] ITEM-02 - Show three slots: permanent football first, then two consumable item slots. Pickups fill an empty item slot without replacing existing items; spawners recharge in 12 seconds.
- [x] ITEM-03 - Wheel cycles all three slots. Only the football slot permits shooting or passing, including when an item slot is empty. F drops the selected consumable; the football cannot be consumed or dropped. Zoom remains Page Up/Down and sandbox expressions use G.
- [x] ITEM-04 - Share the three-card HUD, football/bazooka icons, selection outline and RMB/LMB hints in both scenes. Drops keep the existing pickup/owner delays and 30-second lifetime.
- [x] ITEM-05 - Replace the old straight Rocket with a visible held bazooka. Hold RMB (controller left trigger) over an opponent to acquire a 0.4-second lock within 48 m; LMB press (controller X) fires only with a valid lock. Early clicks consume nothing and do not queue a shot. Solid walls prevent acquisition.
- [x] BAZOOKA-01 - Add an original launcher mesh, two-arm skeletal carry/aim grip, torso/hand recoil and muzzle flash. AI equips, visibly aims and fires held bazookas before returning to football.
- [x] BAZOOKA-02 - Keep the locked target after firing; steer the 25 m/s missile in three dimensions for up to 8 seconds, including against moving/airborne targets. Swept contacts stop at arena geometry, players or the ball. Add a short cosmetic exhaust trail and burst.
- [x] RAGDOLL-01 - Use 13 native PhysicalBone3D bodies and limited joints on the existing skinned skeleton. Bazooka blasts produce 3D launch velocity based on impact position. Disable the movement capsule while physics drives the model, follow the body with the third-person camera, then recover where it lands with a short get-up and match protection.
- [x] RAGDOLL-02 - Share ragdoll reactions with playground actors. Pause physical bodies while the playground/shop pauses; preserve velocities on resume. Reset clears live simulations and restores the original skeleton pose and actor collision.
- [x] BOOST-01 - Small pads restore 25 stamina, capped at 100, and grant +20% normal running/sprint speed for 2.5 s. Further pickups refresh the duration without stacking speed. Pads recharge after 4 s. HUD shows the remaining boost time.
- [x] ITEM-06 - Pause the shared pickup/projectile system when the playground pauses or the shop opens. Round reset clears inventories, dropped items, active boosts and projectiles, and restores spawners.
- [ ] ITEM-07 - Implement the next item as a separate task after reviewing Bazooka; the other seven remain planned.

Verification: run `tools/test_items.tscn` with the normal renderer. Covers permanent football + two item slots, wheel/F, pickup/full inventory, drops, capped stamina and real speed boost/expiry, item-selected shot/pass isolation, real RMB/LMB input, wall occlusion, required lock, early-click cancellation, controller trigger/X, 3D homing, recoil, native-bone launch/rotation/recovery, impact-height response, sandbox parity, pause/resume and round reset. Run `tools/test_movement_rules.tscn` for the existing football, arena and keeper regression checks. Capture and inspect hold/aim/fire, airborne, grounded and recovered poses in both scenes.

Pitch source: [GamesRadar interview with creative director Pierre Tarno](https://www.gamesradar.com/games/sports/rematchs-creative-director-dreamed-of-sloclaps-football-pivot-for-over-8-years-now-his-kids-get-to-see-him-working-on-a-game-about-kicking-a-ball-rather-than-kicking-heads-in/).

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

### Visual direction (reference: Super Battle Golf)

**Goal:** the game must read as a soft, chunky, cozy "party game" in the same visual family as
Super Battle Golf (SBG) — pastel colour, warm soft light, matte rounded shapes, clean rounded UI.
We borrow the *style family*, never SBG's logo, characters, icons, UI layouts or assets. Our
characters stay our own. The stadium stays; only its look changes.

**SBG in short** (Brimstone / Oro Interactive, Steam, Feb 2026, ~500k sold): 1–8 players play
golf simultaneously, no turns — a race to the hole. Random items from purple "?" briefcases
(homing rocket launcher, landmines, shield, coffee speed boost, golf cart, orbital laser…),
a 3–4 slot hotbar, F to drop, items lie physically on the ground with an "E Name" prompt.
Vertical charge meter beside the character and an adjustable shot angle. These mechanics are
recorded for later; **this pass is visual only**.

**Gap analysis** (SBG screenshots vs. `cocoa_in_game.png`):

| Area | SBG reference look | Our build today | Main fix |
|---|---|---|---|
| Palette | Pastel, medium saturation, natural greens, creams | Neon green turf, loud pink/cyan stands | One shared soft palette |
| Light | Warm sun, strong sky ambient, soft bluish shadows, distance haze | Linear tonemap, weak flat ambient, no fog | Tonemap + ambient + haze |
| Sky | Gradient with big chunky 3D clouds | Plain procedural sky | Batched cloud clusters |
| Characters | Lit by the scene, matte, flat "sticker" faces, chunky shoes | Unshaded shader with a fake key light, 3D purple eyes and teeth | Lit toon shader + decal faces |
| Turf | Subtle stripes, natural tone variation | Flat neon stripes | Softer turf shader |
| UI | Rounded bold white font with soft shadow, rounded hotbar, almost no text | Condensed Barlow, dark panels, wall of control hints | Rounded font, contextual hints |
| Pickups | Glowing purple "?" case, real 3D items on the ground | Amber cube on a dark disc | Original case + integrated pads |

Sources: [Destructoid items](https://www.destructoid.com/all-items-in-super-battle-golf-and-how-they-work/),
[GamesCreed review](https://www.gamescreed.com/review/super-battle-golf-review),
[GamesHedge guide](https://www.gameshedge.com/?p=83147),
[PC Gamer](https://www.pcgamer.com/games/sports/that-golf-game-with-orbital-death-lasers-sold-100k-copies-in-two-days-we-made-super-battle-golf-together-in-4-5-months-and-are-so-happy),
[GamesRadar](https://www.gamesradar.com/games/sports/this-usd8-indie-game-blowing-up-on-steam-is-like-mario-golf-mixed-with-super-smash-bros-and-its-already-sold-500-000-copies-with-95-percent-positive-reviews-less-like-friendslop-and-more-like-friendsouffle),
[Attack on City update](https://www.gamedeveloper.com/press-release/super-battle-golf-attack-on-city-update-launches-july-16th-with-new-city-biome-teams-mode-items-and-a-free-weekend).

### Active visual board - work in order

Every phase ends with a before/after capture from the `cocoa_in_game.png` camera, shown for
approval before the next phase starts. Both the match and the sandbox must change together.

**Phase 0 - Palette**

- [ ] PAL-01 - Add `scripts/visuals/palette.gd` (`class_name Palette`, constants only): natural turf greens (~`7cbf5a`/`6fb24f`), cream `fbf3df`, slate ink `2f3a4f`, soft blue team `5aa9e6`, coral team `f2786b`, amber accent `f7b84b`, pickup violet `9b7be0`. Acceptance: files touched in later phases read colours from `Palette` instead of local hex literals; team colours in `main.gd` come from it.

**Phase A - Light and atmosphere** (`scripts/visuals/day_stadium.gd` `add_daylight`, shared by both modes)

- [x] ATM-01 - Replace the linear tonemap with Filmic/AgX (whatever Compatibility supports in 4.7), raise sky-sourced ambient to ~0.6–0.8, warm stronger sun (~1.0) with soft shadows. Acceptance: shadows read light and bluish, whites do not clip, same comparison shot in both modes. Done 14 Nov: Filmic (exposure 1.08), cool ambient `b9d3ec` at 0.62, warm sun `ffe9cc` at 1.25 with 0.72 shadow opacity, cool fill 0.22, slight desaturation; kit-shop preview got its own key/fill.
- [x] ATM-02 - Add light depth haze toward sky blue. Acceptance: far stands soften without fogging the pitch. Done: depth fog 45→260 m, sky unaffected.
- [x] ATM-03 - Add chunky batched 3D cloud clusters around the stadium with a soft unlit shader. Acceptance: clouds visible from the gameplay camera, no shadow casting, frame time change recorded. Done: 11 clusters, one MultiMesh, fog/shadow disabled; camera far raised to 400 m. Sandbox frame time unchanged (~2 ms median on RTX 3080).

**Phase B - Pitch and stadium, softened**

- [ ] PITCH-01 - Rework `assets/materials/turf.gdshader`: natural greens, subtler stripes, low-frequency tone patches, high roughness and no specular. Acceptance: no neon read at the reference angle.
- [ ] PITCH-02 - Cream field lines in both builders (`arena_builder.gd`, `stadium_visual.gd`). Acceptance: lines crisp and aligned, not pure white.
- [ ] PITCH-03 - Restyle `day_stadium.gd` stands: dusty blue / coral / cream seats in larger, lower-contrast blocks, cream roof, slate columns, softer boards. Acceptance: characters remain the focal point.
- [ ] PITCH-04 - Add a ring of rounded trees and low hills behind the stands. Acceptance: horizon no longer looks empty; batched geometry.
- [ ] PITCH-05 - Unify goals in both modes (`goal.gd`, `stadium_visual.gd`): rounded cream/white frame and a clearly readable net. Acceptance: identical goals in match and sandbox.
- [ ] PITCH-06 - Use the existing unused `scripts/visuals/football_visual.gd` ball in `scripts/ball.gd`, without the blue emission. Acceptance: panels read clearly, contact shadow visible, physics unchanged.

**Phase C - Characters**

- [x] CHAR-01 - Convert `assets/materials/character_surface.gdshader` from unshaded/fake key light to a lit soft toon ramp (2–3 tones) that receives scene light and shadows, soft rim, no plastic highlight; retune gloss in `character_surface.gd`. Acceptance: characters sit in the scene's light from four directions. Done 14 Nov: custom `light()` wrapped/banded ramp, warm skin terminator, faint rim. `scripts/visuals/mesh_smoothing.gd` rebuilds the flat-shaded Meshy body with smooth area-weighted normals at load (cached), keeping UV/UV2/bones.
- [x] CHAR-02 - Retired: the 3D face meshes no longer exist (see CHAR-03), so there is nothing to match.
- [x] CHAR-03 - Painted faces: eyes, brows and mouth are drawn by the skin shader itself in head-bone space (no extra meshes or textures). `scripts/visuals/face_paint.gd` feeds the animated/ragdolled head transform, expression, blink and eye colour every pose update. Five expressions: Neutral, Happy, Determined (gritted grin), Surprised, Celebrating (^^ eyes). The Meshy eye/brow/mouth assets are no longer referenced (`eye_assembly.gd`, `mouth_assembly.gd`, `default_eyes.tscn`, `default_mouth.tscn` are unused). Check with `tools/capture_faces.gd` (`--angle=35`, `--blink`).
- [ ] CHAR-04 - Try chunkier proportions (slightly larger rounded head, fatter shoes) via bone scaling. Acceptance: animations, ragdoll and collision unaffected (`test_meshy_animation`, `test_items`).
- [ ] CHAR-05 - Pastel team kits from `Palette`. Acceptance: teams distinguishable at a glance in a 2v2 capture.

**Phase D - Clean rounded UI**

- [ ] UI-02 - Add an OFL-licensed rounded heavy font (e.g. Fredoka or Nunito Black) as a project Theme and replace the Barlow preloads in the HUD files (`hud_painter`, `scoreboard`, `item_inventory_hud`, `arcade_hud`, `kit_shop`, `pickup_pad`, `item_system`, `shape_library`); fix `hud.gd` Labels that use Godot's default font. Shirt print may keep Barlow. Acceptance: one font family across all HUDs.
- [ ] UI-03 - White text with soft shadows instead of hard dark outlines; rounded scoreboard and meters in the new palette. Acceptance: legible at 720p and 1080p.
- [ ] UI-04 - Remove the wall of control hints (`hud.gd`, `arcade_hud.gd`); show short contextual hints only (e.g. "[F] Drop") and the full list on F1. Acceptance: bottom-left free of text in normal play.
- [ ] UI-05 - Restyle item slots (`item_inventory_hud.gd`): rounder translucent cards, number under each card, item name above the selected one. Acceptance: same functionality, new look in both modes.
- [ ] UI-06 - Restyle the kit shop (`kit_shop.gd`) with cream backgrounds and the new font/palette. Acceptance: preview, presets and equip still work.

**Phase E - Pickups**

- [ ] PICK-01 - Replace the amber cube in `pickup_pad.gd` with an original violet "?" case that floats and glows softly. Acceptance: readable from mid-pitch, cooldown still visible.
- [ ] PICK-02 - Boost pads as ground-integrated chevrons instead of a dark disc. Acceptance: visible but not cluttering the turf.

**Phase F - Polish and review**

- [ ] FX-01 - Add restrained landing and sweep dust. Depends on ANIM-02, ANIM-04. Acceptance: effects appear at ground contact and stop after the action.
- [ ] FX-02 - Cream ball trail and soft sparks matching the palette (`ball_trail.gd`, `item_system.gd`). Acceptance: no neon additive colours left.
- [ ] FX-03 - Optional thin character outline only if characters still blend into the background after Phase C.
- [ ] PERF-01 - Profile the finished visual scene at 1080p. Acceptance: record frame time, draw calls, triangle count and actual GPU; do not claim integrated-GPU results from an RTX test.
- [ ] QA-01 - Review against the visual direction. Depends on all phases above. Acceptance: new capture beside the SBG reference shots, list remaining differences, no Godot errors; `test_movement_rules` and `test_items` still pass.

### Animation backlog (unchanged)

- [ ] ANIM-03 - Synchronize walking and running foot speed with travel. Acceptance: side-on recording shows reduced foot sliding at both normal and sprint speeds in both scenes.
- [x] ANIM-04 - Tune gameplay jump takeoff and landing. Depends on MOVE-02. Acceptance: skeletal motion and physical height form one jump, with no extra lift or abrupt landing snap. Normal jump now reaches about 2.7 units, with controller-owned height and grounded source poses.
- [x] ANIM-07 - Add the forward sprint-jump dive. Acceptance: sprint + Space extends the arms, retains forward impulse after input release, lands and recovers in both scenes.
- [x] ANIM-08 - Keep kicks animated during locomotion. Acceptance: a distinct moving-kick clip preserves support-leg steps and forward travel, with feet on the turf.
- [ ] ANIM-05 - Align the kick contact frame with ball release. Acceptance: a side-on recording shows the foot meeting the ball when it launches.
- [ ] ANIM-06 - Add an authored celebration. Depends on CHAR-03. Acceptance: arm raise, hop and happy sticker expression play once and recover cleanly.

### Retired visual tasks (superseded 14 Nov 2026)

VIS-01…VIS-11 (purple 3D eyes, striped pink jersey, number 10 crest, hairstyle series), ENV-01…ENV-04,
LIGHT-01, CAM-01 and UI-01 are retired: they targeted the old neon pink/cyan look. Their useful
parts live on in the PAL/ATM/PITCH/CHAR/UI/PICK tasks above. IDs are not reused.

### Deferred gameplay backlog - activate after the visual phase

- [ ] GAME-01 - Add a one-second kickoff countdown; movement stays locked until GO.
- [ ] GAME-02 - Add the two-minute match clock; pause and round reset preserve the correct remaining time.
- [ ] GAME-03 - Add the end-of-match result screen and local restart.
- [ ] GAME-04 - Add a second local input slot; each controller operates only its own player.
- [ ] GAME-05 - Playtest the existing defensive bot; record wide-area chasing and dribble failures before changing behavior.
- [x] GAME-06 - Add reusable item pickups with permanent football + two consumable slots; verify pickup, wheel selection, use and drop.
- [x] GAME-07 - Implement lock-on Bazooka as the first item; verify held weapon, homing, physical player hits, ball impulse and recovery locally.
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

A football game with Rematch-inspired physical play, chibi characters and disruptive items. The current local prototype is 2v2. Positioning, ball control, stamina and passing form the foundation; items add the arcade layer. Nobody dies or respawns: impacts cost time and field position.

**Pillars**

1. **No turns.** Every player is always live.
2. **A skill-based strike.** Charge, sweet spot, loft and curve.
3. **Football first.** Deliberate movement, passing lanes and meaningful stamina; items add disruption.
4. **Readable chaos.** Chunky silhouettes, dot trajectories, gold sweet spots.

---

## 2. Locked design decisions

These original decisions are archived. The active local gameplay pass above supersedes the old player count, pitch size and no-goalkeeper rules.

### Match

| Rule | Decision |
|---|---|
| Players | Local prototype: **one human + one AI teammate vs two AI opponents**. Online 2v2 remains deferred. |
| Session | **3 arenas × 2 min.** 1 point per goal. Cup = total points. Tie → sudden death. |
| Pitch | Shared **94 × 60 m** walled arena using Rematch's publicly reported approximate pitch size; **8 × 3.5 m** goals. Keeper dives are active in local gameplay. |
| Kickoff | Ball at centre, **item box at centre**, 1 s countdown, both teams on their halves, then a sprint scramble. |
| Camera | Chase cam behind your own player. |
| Hosting | Listen server (host player simulates). |
| Joining | **Room codes** first, quick-match later. |
| Look | Soft "party game" style in the Super Battle Golf family: pastel palette, warm soft light with haze and chunky clouds, matte lit-toon chibi characters with flat sticker faces, rounded clean UI. Transparent rebound walls and the outdoor daylight stadium stay. |

### Hit model

No elimination, no respawns. Four tiers:

| Tier | Cause | Result |
|---|---|---|
| **Stagger** | normal tackle | 0.5 s stumble, lose the ball, stay on your feet |
| **Slip** | banana peels | 1.5 s sprawl, drop ball + item, get up where you fell |
| **Knockdown** | Giant Boot, heavy hits | 2 s ragdoll + slide, drop ball + item, get up where you land |
| **Launch** | Bazooka (implemented); Orbital Strike, Ball Bomb (planned) | Physical ragdoll, 3D blast launch, arena collisions, drop ball and recover at landing; automatic item drops remain planned |

**Current re-hit behavior:** a nearby blast adds 35% launch velocity to a live
ragdoll, capped at 28 m/s total. A downed player cannot be acquired as a new
homing target. Further stunlock tuning remains a separate playtest task.

**Recovery:** stand up where you land, then **1 s of protection**.

**Loot on hit (planned):** automatically drop carried items on knockdown.
Currently an accepted bazooka hit releases the football; item drops use F.

### Items

The current build has **Bazooka** and **three visible slots**: permanent football
first and two consumable slots. Wheel selects; football actions work only in the
football slot. Hold **RMB** to aim and acquire a player lock, then press **LMB** to
fire. Controller uses **left trigger + X**. **F** drops a selected item; E no longer
fires. Lock takes **0.4 s**, requires an opponent within **48 m** and clear line of
sight. A launched missile keeps its player target independently of mouse release
or inventory selection, steers at **25 m/s** and expires safely after **8 s**.
There are **4 boxes**, **12 s respawn**, and duplicates are allowed. Round resets
clear held items. The remaining seven items and automatic loot drops on knockdown
are planned separately.

Bazooka impacts use a **3 m blast** and a **13-body physical ragdoll**, including
real vertical launch based on explosion height. The model tumbles, collides with
the arena, settles, and gets up at the landing point. Football possession releases
on an accepted hit; nearby loose balls receive the existing blast impulse. Match
recovery grants **1 s protection**. Sweeps retain their existing authored animation.

Four small cyan pads restore **25 stamina** and give **+20% run/sprint speed for
2.5 s**, with **4 s respawn**. The speed bonus refreshes without stacking.

| Item | Effect | On hit |
|---|---|---|
| **Bazooka** | Hold aim to lock; fire a player-homing missile | Physical launch and recovery |
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
| **M2** | Local 2v2 gameplay — AI support/defence, keeper dives, passing, larger arena | Current | ✅ implemented; manual tune pass open |
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

## 4b. M2 — previous 1v1 implementation (superseded)

The 1v1 setup below is historical. Current local gameplay creates one human, one supporting AI and two opposing AIs, with contextual keeper saves.

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
- No second local human player; current 2v2 uses three local AI players
- No audio at all
- The default Meshy character is still untextured; facial features and kit remain on the visual task board
- No menu, lobby, pause, settings or rebinding
- No console/controller hot-plug handling (device 0 is hardcoded)
- No ragdoll physics — knockdowns are a scripted tilt + knockback
- `tools/test_visual.gd` fails its "Default model must be 25% smaller" check (max axis 1.7–1.9) because the Cocoa hair reaches ~2.0 m; independent of the 14 Nov look pass. The sandbox lock step in `test_items` is timing-sensitive and can fail intermittently (passes on re-run).

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

**Gate:** playtest the local 2v2 for five minutes and tune spacing, save timing
and passing before adding items.

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
| 14 Nov 2026 | Visual direction: soft party-game look in the Super Battle Golf style family (no copied assets); gameplay frozen during the visual pass; the stadium stays and is restyled |
