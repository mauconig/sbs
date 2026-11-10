extends RefCounted
## A short advantage over sprinting, paid for with braking and a planted get-up.
const BURST_TIME := 0.16
const BRAKE_TIME := 0.32
const RECOVERY_TIME := 0.55
const MOTION_TIME := BURST_TIME+BRAKE_TIME
const TOTAL_TIME := MOTION_TIME+RECOVERY_TIME
const COOLDOWN := 1.30
const SPEED_FACTOR := 2.4


static func distance_at(elapsed: float, sprint_speed: float) -> float:
	var time := clampf(elapsed,0.0,MOTION_TIME)
	var speed := sprint_speed*SPEED_FACTOR
	if time<=BURST_TIME:
		return speed*time
	var brake_phase := (time-BURST_TIME)/BRAKE_TIME
	return speed*(BURST_TIME+BRAKE_TIME/3.0*(1.0-pow(1.0-brake_phase,3.0)))
