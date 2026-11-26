extends RefCounted
## Shared movement tuning for the gameplay match and visual sandbox.

const GRAVITY := 26.0
const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.0
const ACCELERATION := 20.0
const DECELERATION := 26.0
const DIVE_SPEED := 9.0
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 28.0 # About 3.6 seconds of uninterrupted sprint.
const STAMINA_REGEN := 18.0
const STAMINA_DELAY := 1.1
const STAMINA_RESTART := 28.0
const EXHAUSTION_TIME := 1.2
const LOCOMOTION_ANIMATION_RATE := 0.5
const DIVE_JUMP_SPEED := 4.0
const NORMAL_JUMP_SPEED := 5.58 # 0.60 m apex at 26 m/s^2 gravity.
const NORMAL_JUMP_DURATION := 2.0 * NORMAL_JUMP_SPEED / GRAVITY
const KEEPER_DIVE_SPEED := 9.0
const KEEPER_DIVE_DURATION := 0.62
