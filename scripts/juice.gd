extends Node
## Global "juice" service: screen shake requests and hit-stop.

var shake := 0.0

var _hitstop_until := 0
var _hitstop_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func hitstop(duration: float, scale: float = 0.06) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = scale
	_hitstop_scale = scale
	_hitstop_until = Time.get_ticks_msec() + int(duration * 1000.0)


func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.4)
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0
		_hitstop_until = 0
