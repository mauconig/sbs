extends RefCounted
## Shared movement tuning for the gameplay match and visual sandbox.

const GRAVITY := 26.0
const WALK_SPEED := 12.8
const SPRINT_SPEED := 18.4
const ACCELERATION := 112.0
const DECELERATION := 72.0
const DIVE_SPEED := 28.8
const DIVE_JUMP_SPEED := 8.0
const NORMAL_JUMP_SPEED := 9.2951600309 # sqrt(0.6) of the previous 12.0 impulse.
const NORMAL_JUMP_DURATION := 2.0 * NORMAL_JUMP_SPEED / GRAVITY
