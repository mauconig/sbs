extends RefCounted
## Scripted input used by the headless tests.

var move := Vector2.ZERO
var sprinting := false
var kick := false
var tackle := false
var jump := false


func move_vector() -> Vector2:
	return move


func look_vector() -> Vector2:
	return Vector2.ZERO


func sprint_held() -> bool:
	return sprinting


func kick_held() -> bool:
	return kick


func tackle_held() -> bool:
	return tackle


func jump_held() -> bool:
	return jump


func item_held() -> bool:
	return false
