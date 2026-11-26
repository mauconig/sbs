extends RefCounted
## Shared pitch and goal dimensions for gameplay and the visual sandbox.

# Published approximation from creative director Pierre Tarno's GamesRadar interview.
# Keep world units in metres; both playable scenes use this same footprint.
const LENGTH := 94.0
const WIDTH := 60.0
const HALF_LENGTH := LENGTH * 0.5
const HALF_WIDTH := WIDTH * 0.5
const GOAL_WIDTH := 8.0
const GOAL_HEIGHT := 3.5
const GOAL_DEPTH := 1.8
const WALL_HEIGHT := 12.0
const WALL_THICKNESS := 0.3
const CENTER_CIRCLE_RADIUS := 9.15
const PENALTY_WIDTH := 32.0
const PENALTY_DEPTH := 12.0
const GOAL_AREA_WIDTH := 16.0
const GOAL_AREA_DEPTH := 5.5
const KEEPER_HALF_WIDTH := 8.0
const KEEPER_DEPTH := 12.0


static func in_keeper_area(at: Vector3, team: int) -> bool:
	var own_end := 1.0 if team == 0 else -1.0
	var depth := HALF_LENGTH - at.z * own_end
	return absf(at.x) <= KEEPER_HALF_WIDTH and depth >= -0.5 and depth <= KEEPER_DEPTH
