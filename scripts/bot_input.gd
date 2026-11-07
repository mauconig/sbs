extends RefCounted
## Input source used by the AI opponent. Same interface as InputHub.

var move := Vector2.ZERO
var sprint := false
var kick := false
var tackle := false


func move_vector() -> Vector2:
	return move


func look_vector() -> Vector2:
	return Vector2.ZERO


func sprint_held() -> bool:
	return sprint


func kick_held() -> bool:
	return kick


func tackle_held() -> bool:
	return tackle


func item_held() -> bool:
	return false
