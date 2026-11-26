extends Node3D
## Local 2v2: player + supporting AI versus two AI opponents.

const ArenaBuilder := preload("res://scripts/arena_builder.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BallScript := preload("res://scripts/ball.gd")
const KickScript := preload("res://scripts/kick_controller.gd")
const CameraScript := preload("res://scripts/chase_camera.gd")
const GoalScript := preload("res://scripts/goal.gd")
const BotBrainScript := preload("res://scripts/bot_brain.gd")
const BotInput := preload("res://scripts/bot_input.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const InputHub := preload("res://scripts/input_hub.gd")
const OutfitStore := preload("res://scripts/visuals/outfit_store.gd")
const Field := preload("res://scripts/field_config.gd")
const DayStadium := preload("res://scripts/visuals/day_stadium.gd")
const ItemSystem := preload("res://scripts/items/item_system.gd")

@export var outfit_path := OutfitStore.SAVE_PATH

const SPAWN := Vector3(0.0, 0.02, Field.HALF_LENGTH*0.5)
const ALLY_SPAWN := Vector3(-8.0, 0.02, Field.HALF_LENGTH*0.62)
const BOT_SPAWN := Vector3(0.0, 0.02, -Field.HALF_LENGTH*0.5)
const BOT2_SPAWN := Vector3(8.0, 0.02, -Field.HALF_LENGTH*0.62)
const BALL_SPAWN := Vector3(0.0, 0.4, 0.0)

var player: CharacterBody3D
var bot: CharacterBody3D
var ally: CharacterBody3D
var enemy_second: CharacterBody3D
var teammates: Array[CharacterBody3D] = []
var opponents: Array[CharacterBody3D] = []
var ball: RigidBody3D
var camera: Camera3D
var kick: Node3D
var bot_kick: Node3D
var bot_brain: Node
var bot_input: RefCounted
var ally_input: RefCounted
var enemy_second_input: RefCounted
var ai_brains: Array[Node] = []
var ai_kicks: Array[Node3D] = []
var hud: CanvasLayer
var items: Node3D

var player_score := 0
var bot_score := 0
var _pending_reset := 0.0


func _ready() -> void:
	_build_environment()
	add_child(ArenaBuilder.new())
	_build_ball()
	_build_players()
	_build_camera()
	_build_kicks()
	_build_bot_brain()
	_build_goals()
	_build_hud()
	_build_items()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud.show_banner("MEGA BATTLE FOOTBALL", Color(0.65, 0.9, 1.0))
	_reset_round()


func _build_environment() -> void:
	DayStadium.add_daylight(self)


func _build_ball() -> void:
	ball = BallScript.new()
	ball.name = "Ball"
	ball.position = BALL_SPAWN
	add_child(ball)


func _build_players() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.character_look = OutfitStore.load_look(outfit_path)
	player.body_color = Color(0.18, 0.62, 1.0)
	player.position = SPAWN
	player.team_id = 0
	add_child(player)
	player.input = InputHub.new()
	player.ball = ball
	ally = _make_ai_player("Ally",ALLY_SPAWN,0)
	bot = _make_ai_player("Opponent",BOT_SPAWN,1)
	enemy_second = _make_ai_player("Opponent2",BOT2_SPAWN,1)
	teammates = [player,ally]
	opponents = [bot,enemy_second]
	for actor in [player,ally]:
		actor.opponents = opponents
		actor.opponent = bot
	for actor in opponents:
		actor.opponents = teammates
		actor.opponent = player


func _make_ai_player(actor_name: String, spawn: Vector3, team: int) -> CharacterBody3D:
	var actor := PlayerScript.new()
	actor.name = actor_name
	actor.team_id = team
	actor.body_color = Color(0.94,0.2,0.42) if team == 1 else Color(0.18,0.75,0.95)
	var team_look := load("res://assets/characters/pip.tres").duplicate() as Resource
	team_look.set("display_name",actor_name.to_upper())
	team_look.set("shirt_color",Color("ec328e") if team==1 else Color("16bce9"))
	team_look.set("shirt_secondary_color",Color("ff9d49") if team==1 else Color("18345f"))
	team_look.set("shorts_color",Color("342647"))
	team_look.set("socks_color",Color("ffffff"))
	team_look.set("boots_color",Color("ec328e") if team==1 else Color("16bce9"))
	team_look.set("shirt_pattern",1)
	actor.character_look = team_look
	actor.position = spawn
	actor.camera_relative = false
	actor.speed_multiplier = 1.0
	actor.position.y = 0.02
	add_child(actor)
	var actor_input := BotInput.new()
	actor.input = actor_input
	actor.ball = ball
	if actor_name == "Ally":
		ally_input = actor_input
	elif actor_name == "Opponent":
		bot_input = actor_input
	else:
		enemy_second_input = actor_input
	return actor


func _build_camera() -> void:
	camera = CameraScript.new()
	camera.name = "ChaseCamera"
	camera.target = player
	camera.input = player.input
	add_child(camera)
	player.camera = camera


func _build_kicks() -> void:
	kick = KickScript.new()
	kick.name = "PlayerKick"
	kick.player = player
	kick.camera = camera
	kick.ball = ball
	kick.input = player.input
	kick.teammates = [ally]
	kick.team_id = 0
	add_child(kick)
	player.kick = kick
	kick.kicked.connect(_on_player_kicked)
	kick.passed.connect(_on_player_passed)

	for actor in [ally,bot,enemy_second]:
		var ai_kick := KickScript.new()
		ai_kick.name = actor.name+"Kick"
		ai_kick.player = actor
		ai_kick.ball = ball
		ai_kick.input = actor.input
		ai_kick.show_preview = false
		ai_kick.use_aim_override = true
		add_child(ai_kick)
		actor.kick = ai_kick
		ai_kicks.append(ai_kick)
	bot_kick = ai_kicks[1]


func _build_bot_brain() -> void:
	for actor in [ally,bot,enemy_second]:
		var brain := BotBrainScript.new()
		brain.name = actor.name+"Brain"
		brain.body = actor
		brain.ball = ball
		brain.input = actor.input
		brain.team_id = actor.team_id
		brain.teammates = [player,ally] if actor.team_id == 0 else [bot,enemy_second]
		brain.opponents = [bot,enemy_second] if actor.team_id == 0 else [player,ally]
		brain.attack_z = -Field.HALF_LENGTH if actor.team_id == 0 else Field.HALF_LENGTH
		brain.own_z = Field.HALF_LENGTH if actor.team_id == 0 else -Field.HALF_LENGTH
		add_child(brain)
		ai_brains.append(brain)
	bot_brain = ai_brains[1]


func _build_goals() -> void:
	var far_goal := GoalScript.new()
	far_goal.name = "FarGoal"
	far_goal.position = Vector3(0, 0, -Field.HALF_LENGTH)
	far_goal.add_to_group("preview_goals")
	add_child(far_goal)
	far_goal.scored.connect(_on_player_goal)

	var near_goal := GoalScript.new()
	near_goal.name = "NearGoal"
	near_goal.position = Vector3(0, 0, Field.HALF_LENGTH)
	near_goal.rotation_degrees.y = 180.0
	near_goal.add_to_group("preview_goals")
	add_child(near_goal)
	near_goal.scored.connect(_on_bot_goal)


func _build_hud() -> void:
	hud = HudScript.new()
	hud.sweet_lo = kick.sweet_lo
	hud.sweet_hi = kick.sweet_hi
	add_child(hud)


func _physics_process(delta: float) -> void:
	hud.inventory=items.inventory_for(player)
	hud.boost_remaining=items.boost_remaining(player)
	hud.charge = kick.charge
	hud.aiming = kick.aiming
	hud.charging = kick.charging
	hud.sweet_hit = kick.charging and kick.charge >= kick.sweet_lo and kick.charge <= kick.sweet_hi
	hud.stamina = player.stamina
	hud.stamina_max = player.stamina_max
	hud.sprinting = player.sprinting
	hud.exhausted = player.exhausted
	hud.tackle_ready = 1.0 - clampf(player.tackle_cooldown_timer / player.tackle_cooldown, 0.0, 1.0)
	hud.player_score = player_score
	hud.bot_score = bot_score

	if ball.global_position.y < -4.0 or absf(ball.global_position.z) > Field.HALF_LENGTH + 4.0:
		ball.reset_to(BALL_SPAWN)

	if _pending_reset > 0.0:
		_pending_reset -= delta
		if _pending_reset <= 0.0:
			_reset_round()


func _on_player_goal() -> void:
	if _pending_reset > 0.0:
		return
	player_score += 1
	Juice.add_shake(1.1)
	Juice.hitstop(0.08, 0.12)
	hud.show_banner("GOAL!", Color(1.0, 0.84, 0.25))
	_pending_reset = 1.1


func _on_bot_goal() -> void:
	if _pending_reset > 0.0:
		return
	bot_score += 1
	Juice.add_shake(0.9)
	Juice.hitstop(0.08, 0.12)
	hud.show_banner("BOT SCORES", Color(1.0, 0.45, 0.4))
	_pending_reset = 1.1


func _on_player_kicked(_power: float, sweet: bool) -> void:
	hud.shots += 1
	player.play_kick_animation()
	if sweet:
		Juice.add_shake(0.2)


func _on_player_passed(_power: float, _sweet: bool) -> void:
	player.play_kick_animation()


func _reset_round() -> void:
	if items!=null:
		items.reset_round()
	ball.reset_to(BALL_SPAWN)
	player.reset_at(SPAWN, Vector3(0.0, 0.0, -1.0))
	ally.reset_at(ALLY_SPAWN, Vector3(0.0, 0.0, -1.0))
	bot.reset_at(BOT_SPAWN, Vector3(0.0, 0.0, 1.0))
	enemy_second.reset_at(BOT2_SPAWN, Vector3(0.0, 0.0, 1.0))
	for brain in ai_brains:
		brain.reset()
	hud.charge = 0.0


func _build_items() -> void:
	items=ItemSystem.new()
	items.ball=ball
	items.local_actor=player
	items.view_camera=camera
	hud.weapon_system=items
	items.aim_provider=func() -> Vector3: return Vector3(-sin(camera.yaw),0,-cos(camera.yaw))
	add_child(items)
	for actor in [player,ally,bot,enemy_second]:
		items.register_actor(actor,actor.team_id)
		actor.kick.inventory=items.inventory_for(actor)
	hud.inventory=items.inventory_for(player)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.keycode == KEY_F2:
			player_score = 0
			bot_score = 0
			hud.shots = 0
			_reset_round()
