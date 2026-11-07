extends Node3D
## Sandbox scene: builds the pitch, ball, player, camera, goals and keeper.
## This is the M1 "feel test" — no match flow, no items yet.

const ArenaBuilder := preload("res://scripts/arena_builder.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BallScript := preload("res://scripts/ball.gd")
const KickScript := preload("res://scripts/kick_controller.gd")
const CameraScript := preload("res://scripts/chase_camera.gd")
const GoalScript := preload("res://scripts/goal.gd")
const KeeperScript := preload("res://scripts/keeper_dummy.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const InputHub := preload("res://scripts/input_hub.gd")

const SPAWN := Vector3(0.0, 1.0, 7.0)
const BALL_SPAWN := Vector3(0.0, 0.4, 2.0)
const KEEPER_Z := -15.1

var player: CharacterBody3D
var ball: RigidBody3D
var camera: Camera3D
var kick: Node3D
var hud: CanvasLayer
var keeper: Node3D

var _pending_reset := 0.0


func _ready() -> void:
	_build_environment()
	add_child(ArenaBuilder.new())
	_build_ball()
	_build_player()
	_build_camera()
	_build_kick()
	_build_goals()
	_build_keeper()
	_build_hud()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud.show_banner("MEGA BATTLE FOOTBALL", Color(0.65, 0.9, 1.0))


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.03, 0.06, 0.13)
	sky_material.sky_horizon_color = Color(0.18, 0.24, 0.38)
	sky_material.ground_bottom_color = Color(0.02, 0.03, 0.05)
	sky_material.ground_horizon_color = Color(0.12, 0.16, 0.26)
	sky.sky_material = sky_material
	environment.sky = sky

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.04
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.06, 0.09, 0.16)
	environment.fog_density = 0.008
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.4

	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -42.0, 0.0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 12, 0)
	fill.light_energy = 1.6
	fill.omni_range = 40.0
	fill.light_color = Color(0.55, 0.75, 1.0)
	add_child(fill)


func _build_ball() -> void:
	ball = BallScript.new()
	ball.name = "Ball"
	ball.position = BALL_SPAWN
	add_child(ball)


func _build_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = SPAWN
	add_child(player)
	player.input = InputHub.new()
	player.ball = ball


func _build_camera() -> void:
	camera = CameraScript.new()
	camera.name = "ChaseCamera"
	camera.target = player
	camera.input = player.input
	add_child(camera)
	player.camera = camera


func _build_kick() -> void:
	kick = KickScript.new()
	kick.name = "Kick"
	kick.player = player
	kick.camera = camera
	kick.ball = ball
	kick.input = player.input
	add_child(kick)
	player.kick = kick
	kick.kicked.connect(_on_kicked)


func _build_goals() -> void:
	var far_goal := GoalScript.new()
	far_goal.name = "FarGoal"
	far_goal.position = Vector3(0, 0, -16.0)
	add_child(far_goal)
	far_goal.scored.connect(_on_scored)

	var near_goal := GoalScript.new()
	near_goal.name = "NearGoal"
	near_goal.position = Vector3(0, 0, 16.0)
	near_goal.rotation_degrees.y = 180.0
	add_child(near_goal)
	near_goal.scored.connect(_on_scored)


func _build_keeper() -> void:
	keeper = KeeperScript.new()
	keeper.name = "TrainingKeeper"
	keeper.position = Vector3(0, 0, KEEPER_Z)
	add_child(keeper)
	keeper.ball = ball


func _build_hud() -> void:
	hud = HudScript.new()
	hud.sweet_lo = kick.sweet_lo
	hud.sweet_hi = kick.sweet_hi
	add_child(hud)


func _physics_process(delta: float) -> void:
	hud.charge = kick.charge
	hud.sweet_hit = kick.charging and kick.charge >= kick.sweet_lo and kick.charge <= kick.sweet_hi
	hud.stamina = player.stamina
	hud.stamina_max = player.stamina_max
	hud.sprinting = player.sprinting
	hud.exhausted = player.exhausted

	if ball.global_position.y < -4.0 or absf(ball.global_position.z) > 26.0:
		ball.reset_to(BALL_SPAWN)

	if _pending_reset > 0.0:
		_pending_reset -= delta
		if _pending_reset <= 0.0:
			_reset_round()


func _on_scored() -> void:
	hud.goals += 1
	Juice.add_shake(1.1)
	Juice.hitstop(0.08, 0.12)
	hud.show_banner("GOAL!", Color(1.0, 0.84, 0.25))
	_pending_reset = 1.1


func _on_kicked(_power: float, sweet: bool) -> void:
	hud.shots += 1
	if sweet:
		Juice.add_shake(0.2)


func _reset_round() -> void:
	ball.reset_to(BALL_SPAWN)
	player.global_position = SPAWN
	player.velocity = Vector3.ZERO
	player.stamina = player.stamina_max
	kick.charging = false
	kick.charge = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.keycode == KEY_R:
			_reset_round()
