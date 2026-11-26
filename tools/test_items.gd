extends Node
## Shared pickups, three-slot controls, real lock/fire input and native ragdolls.
const MainScene := preload("res://scenes/main.tscn")
const SandboxScene := preload("res://scenes/visual_prototype.tscn")
const ScriptedInput := preload("res://tools/scripted_input.gd")
const Inventory := preload("res://scripts/items/item_inventory.gd")
var _failed := false

func _ready() -> void:
 _run.call_deferred()

func _run() -> void:
 var inventory := Inventory.new()
 _require(inventory.slots.size()==3 and inventory.selected_item()==&"ball","Three slots start with permanent football")
 _require(inventory.add(&"bazooka") and inventory.add(&"bazooka") and not inventory.add(&"bazooka"),"Two consumable slots cannot overflow")
 _require(inventory.take_selected().is_empty() and inventory.slots[0]==&"ball","Football cannot be consumed")
 inventory.cycle(-1)
 _require(inventory.selected==2,"Wheel wraps across all three slots")
 inventory.select_slot(1)
 _require(inventory.selected==1,"Direct selection permits empty consumable slots")
 inventory.select_slot(3)
 _require(inventory.selected==1,"Direct selection rejects invalid slots")
 inventory.clear()
 _require(inventory.selected_item()==&"ball" and inventory.slots[1].is_empty(),"Round reset preserves football")
 await _test_match()
 await _test_sandbox()
 if not _failed:
  print("ITEM SYSTEM PASS: 3 slots, 1-3/keypad/wheel/F, kick isolation, painted face/launcher, pickups/boosts, required lock, RMB/LMB, homing in 3D, physical ragdoll/airborne launch/recovery, sandbox and pause")
 get_tree().quit(1 if _failed else 0)

func _test_match() -> void:
 var main := MainScene.instantiate()
 get_tree().root.add_child(main)
 await _frames(6)
 for brain in main.ai_brains: brain.set_physics_process(false)
 for actor in [main.player,main.ally,main.bot,main.enemy_second]:
  actor.input=ScriptedInput.new()
  actor.kick.input=actor.input
 main.items._ai_timer=999.0
 main.camera.set_process(false)
 main.camera.set_physics_process(false)
 main.player.set_physics_process(false)
 var inventory=main.items.inventory_for(main.player)
 _require(main.items.spawners.size()==4 and main.items.boost_pads.size()==4,"Four item and four boost pads")
 for index in 2:
  main.player.position=main.items.spawners[index].position
  await _frames(2)
 _require(inventory.slots[0]==&"ball" and inventory.slots[1]==&"bazooka" and inventory.slots[2]==&"bazooka","Pickups fill only consumable slots")
 main.player.position=main.items.spawners[2].position
 await _frames(2)
 _require(main.items.spawners[2].cooldown==0.0,"Full inventory leaves pickup available")
 main.player.position=Vector3(0,0.02,5)
 var old_distance: float=main.camera.distance
 _wheel(MOUSE_BUTTON_WHEEL_DOWN)
 _require(inventory.selected==1,"Wheel selects bazooka")
 _wheel(MOUSE_BUTTON_WHEEL_UP)
 _require(inventory.selected==0 and main.camera.distance==old_distance,"Football selection does not zoom camera")
 for key in [KEY_3,KEY_2,KEY_1]:
  _key(key,true)
  _key(key,false)
  _require(inventory.selected==key-KEY_1,"Number keys directly select the matching match slot")
 _key(KEY_KP_3,true)
 _key(KEY_KP_3,false)
 _require(inventory.selected==2,"Numeric keypad also selects slots")
 _key(KEY_1,true)
 _key(KEY_1,false)
 _require(not main.items.drop_selected(main.player),"Football cannot be dropped")
 inventory.selected=1
 _key(KEY_F,true)
 _key(KEY_F,false)
 _require(inventory.slots[1].is_empty() and main.items.dropped_items.size()==1,"F drops selected bazooka")
 var drop=main.items.dropped_items[0]
 _require(not main.items.try_collect(drop,main.player),"Drop has owner protection")
 drop.advance(0.3)
 _require(main.items.try_collect(drop,main.ally),"Other players can collect dropped loot")
 main.player.position=main.items.boost_pads[0].position
 main.player.stamina=40
 await _frames(2)
 _require(main.player.stamina==65 and main.items.boost_remaining(main.player)>2.4,"Boost restores 25 stamina and lasts 2.5 seconds")
 main.player.position=main.items.boost_pads[1].position
 main.player.stamina=95
 await _frames(2)
 _require(main.player.stamina==100 and main.player.pickup_speed_multiplier==1.2,"Boost caps stamina and never stacks")
 main.player.set_physics_process(true)
 main.player.input.move=Vector2(0,1)
 main.player.input.sprinting=true
 await _frames(50)
 _require(main.player.velocity.length()>10.5 and main.player.velocity.length()<10.9,"Boost really increases sprint to 10.8m/s")
 main.player.input.move=Vector2.ZERO
 main.player.input.sprinting=false
 await _frames(185)
 _require(main.items.boost_remaining(main.player)==0.0 and main.player.pickup_speed_multiplier==1.0,"Boost expires")
 main.items.reset_round()
 main.player.reset_at(Vector3(0,0.02,6),Vector3.FORWARD)
 main.bot.reset_at(Vector3(0,0.02,-6),Vector3.BACK)
 main.ally.reset_at(Vector3(-20,0.02,10),Vector3.FORWARD)
 main.enemy_second.reset_at(Vector3(20,0.02,-20),Vector3.BACK)
 main.bot.protection=0
 main.ball.reset_to(Vector3(0,0.23,5))
 await _frames(5)
 main.ball.claim_by(main.player)
 inventory.add(&"bazooka")
 inventory.selected=1
 _require(not main.kick.force_kick(1,Vector3.FORWARD) and not main.kick.force_pass(main.ally,0.5),"Selected item blocks direct shot and pass")
 main.player.input.pass_aim=true
 main.player.input.kick=true
 await _frames(10)
 _require(not main.kick.charging and not main.kick.aiming and main.ball.carrier==main.player,"Item selection blocks football preview and charging")
 main.player.input.kick=false
 main.player.input.pass_aim=false
 inventory.selected=2
 await _frames(2)
 _require(not main.kick.force_kick(1,Vector3.FORWARD),"Empty item slot still cannot kick")
 inventory.selected=0
 await _frames(2)
 _require(main.kick.force_kick(0.4,Vector3.FORWARD),"Football slot restores shooting")
 main.ball.reset_to(Vector3(22,0.23,20))
 await _frames(4)
 inventory.selected=1
 main.camera.position=main.player.position+Vector3(0,2.3,5)
 main.camera.look_at(main.bot.position+Vector3.UP*0.7)
 # Use real InputHub mouse state to exercise RMB aim + LMB press.
 var live=load("res://scripts/input_hub.gd").new()
 main.player.input=live
 main.kick.input=live
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 await _frames(2)
 _require(not main.items.use_selected(main.player,main.bot),"Cannot fire without a completed lock")
 _require(not main.items._valid_target(main.player,main.ally),"Lock targets opponents, never teammates")
 var wall := StaticBody3D.new()
 wall.collision_layer=1
 var shape := BoxShape3D.new()
 shape.size=Vector3(3,4,0.2)
 var collider := CollisionShape3D.new()
 collider.shape=shape
 wall.add_child(collider)
 main.add_child(wall)
 wall.position=Vector3(0,2,0)
 await _frames(2)
 _mouse(MOUSE_BUTTON_RIGHT,true)
 await _frames(28)
 _require(main.items.locked_target==null,"Cannot lock through a solid wall")
 _mouse(MOUSE_BUTTON_RIGHT,false)
 wall.queue_free()
 await _frames(3)
 var controller=load("res://scripts/input_hub.gd").new()
 controller.device=0
 main.player.input=controller
 main.kick.input=controller
 _joy_aim(1.0)
 await _frames(28)
 _require(main.items.locked_target==main.bot,"Controller left trigger acquires the same lock")
 _joy_fire(true)
 await _frames(2)
 _require(inventory.slots[1].is_empty() and get_tree().get_nodes_in_group("item_projectiles").size()==1,"Controller X fires a locked bazooka")
 _joy_fire(false)
 _joy_aim(0.0)
 for projectile in get_tree().get_nodes_in_group("item_projectiles"): projectile.queue_free()
 inventory.add(&"bazooka")
 main.player.input=live
 main.kick.input=live
 await _frames(3)
 _mouse(MOUSE_BUTTON_RIGHT,true)
 await _frames(6)
 _mouse(MOUSE_BUTTON_LEFT,true)
 await _frames(2)
 _require(get_tree().get_nodes_in_group("item_projectiles").is_empty() and inventory.slots[1]==&"bazooka","Early click neither fires nor consumes item")
 _mouse(MOUSE_BUTTON_LEFT,false)
 await _frames(26)
 _require(main.items.locked_target==main.bot and main.player._visual.bazooka.visible,"RMB acquires enemy lock and displays held launcher")
 _require(main.player._visual.bazooka._gun.has_node("SuppliedLauncher"),"The supplied Meshy launcher replaces primitive weapon geometry")
 _require(main.player._visual.face_paint!=null and main.player._visual.face_paint.call("_material")!=null,"The match character's face is painted on the skin")
 _mouse(MOUSE_BUTTON_RIGHT,false)
 await _frames(2)
 _require(main.items.locked_target==null,"Releasing RMB clears unfired lock")
 _mouse(MOUSE_BUTTON_RIGHT,true)
 await _frames(27)
 _mouse(MOUSE_BUTTON_LEFT,true)
 await _frames(2)
 var projectiles=get_tree().get_nodes_in_group("item_projectiles")
 _require(projectiles.size()==1 and inventory.slots[1].is_empty(),"Locked LMB click launches one missile and consumes one item")
 _require(main.player._visual.bazooka._fire_time>0 and main.player._visual.bazooka.recoil_amount>0,"Firing animates launcher recoil")
 var missile=projectiles[0]
 _require(missile.target==main.bot,"Missile stores the locked player")
 main.player.input=ScriptedInput.new()
 main.kick.input=main.player.input
 _mouse(MOUSE_BUTTON_LEFT,false)
 _mouse(MOUSE_BUTTON_RIGHT,false)
 var old_direction: Vector3=missile.direction
 main.bot.position.x=2.4
 main.bot.position.y=1.0
 main.bot.velocity.y=0
 for frame in 48:
  await _frames(1)
  if frame==4 and is_instance_valid(missile):
   _require(missile.direction.distance_to(old_direction)>0.02,"Missile steers toward moving target in flight")
  if main.bot._visual.ragdoll_active: break
 _require(main.bot._visual.ragdoll_active and main.bot.collision_layer==0,"Impact starts jointed physical ragdoll and disables capsule")
 var rag=main.bot._visual.ragdoll
 _require(rag.bodies.size()==13 and rag.bodies[0].is_simulating_physics(),"Native PhysicalBone bodies are actually simulating")
 var head_before: Vector3=rag.bodies[2].global_position
 var hips_before: Vector3=rag.bodies[0].global_position
 await _frames(18)
 _require(rag.bodies[0].global_position.distance_to(hips_before)>0.4,"Blast causes real airborne translation")
 _require((rag.bodies[2].global_position-rag.bodies[0].global_position).distance_to(head_before-hips_before)>0.03,"Ragdoll bones rotate rather than holding static animation")
 await _frames(420)
 _require(not rag.active and main.bot.collision_layer==2 and main.bot.knocked_out==0,"Ragdoll lands and recovers to normal control")
 _require(main.bot._visual._motion_rig.top_level==false,"Recovery reattaches visual to actor")
 # Impact height must affect launch, not a flat fixed knockback.
 main.bot.protection=0
 main.bot.reset_at(Vector3(10,2.0,0),Vector3.BACK)
 main.bot.protection=0
 main.items.explode_at(Vector3(10,1.5,0),main.player)
 var lifted: float=main.bot._visual.ragdoll.bodies[0].linear_velocity.y
 _require(lifted>15,"Blast below an airborne player launches them upwards")
 main.bot.reset_at(Vector3(10,0.03,0),Vector3.BACK)
 main.bot.protection=0
 main.items.explode_at(Vector3(10,2,0),main.player)
 _require(main.bot._visual.ragdoll.bodies[0].linear_velocity.y<lifted-10,"Blast above player produces different vertical force")
 main._reset_round()
 _require(not main.bot._visual.ragdoll_active and inventory.selected_item()==&"ball","Round reset clears live physics and returns football slot")
 main.ally.reset_at(Vector3(0,0.02,6),Vector3.FORWARD)
 main.bot.reset_at(Vector3(0,0.02,-7),Vector3.BACK)
 main.ball.reset_to(Vector3(25,0.23,20))
 main.items.inventory_for(main.ally).add(&"bazooka")
 main.items._update_ai_items()
 await _frames(30)
 _require(main.ally._visual.bazooka.visible and main.ally.item_aiming,"AI visibly equips and aims before firing")
 main.items._update_ai_items()
 await _frames(2)
 _require(main.items.inventory_for(main.ally).selected==0 and get_tree().get_nodes_in_group("item_projectiles").size()==1,"AI fires its locked bazooka and returns to football")
 main.queue_free()
 await get_tree().process_frame

func _test_sandbox() -> void:
 var sandbox := SandboxScene.instantiate()
 get_tree().root.add_child(sandbox)
 await _frames(5)
 sandbox.items._ai_timer=999.0
 var actor=sandbox.characters[0]
 var target=sandbox.characters[2]
 var inventory=sandbox.items.inventory_for(actor)
 actor.position=sandbox.items.spawners[0].position
 await _frames(2)
 _require(inventory.slots[1]==&"bazooka" and inventory.selected==0,"Sandbox pickups preserve football selection")
 sandbox._set_paused(true)
 var cooldown: float=sandbox.items.spawners[0].cooldown
 await _frames(10)
 _require(sandbox.items.spawners[0].cooldown==cooldown and not sandbox.items.use_selected(actor,target),"Shop/pause freezes pickups and cannot fire")
 _key(KEY_3,true)
 _key(KEY_3,false)
 _require(inventory.selected==0,"Paused or shop input cannot change equipment")
 sandbox._set_paused(false)
 var old_action: int=actor.animation
 for key in [KEY_2,KEY_3,KEY_1]:
  _key(key,true)
  _key(key,false)
  _require(inventory.selected==key-KEY_1,"Number keys select the matching sandbox slot")
 _require(actor.animation==old_action,"Number keys no longer trigger sandbox animation demonstrations")
 actor.position=Vector3(0,0,5)
 target.position=Vector3(0,0,-7)
 sandbox.characters[1].position=Vector3(20,0,-12)
 sandbox.characters[3].position=Vector3(-20,0,-12)
 sandbox.ball.reset_to(Vector3(20,0.23,20))
 sandbox._carrier_index=-1
 sandbox._camera_yaw=0
 inventory.selected=1
 _mouse(MOUSE_BUTTON_RIGHT,true)
 await _frames(32)
 _require(sandbox.items.locked_target==target,"Sandbox uses the same RMB lock")
 _mouse(MOUSE_BUTTON_LEFT,true)
 await _frames(2)
 _require(inventory.slots[1].is_empty(),"Sandbox uses the same LMB firing")
 _mouse(MOUSE_BUTTON_LEFT,false)
 _mouse(MOUSE_BUTTON_RIGHT,false)
 for frame in 70:
  await _frames(1)
  if target.ragdoll_active: break
 _require(target.ragdoll_active,"Sandbox actor has the same physical ragdoll")
 await _frames(6)
 sandbox._set_paused(true)
 await _frames(2)
 var hip: Vector3=target.ragdoll.bodies[0].global_position
 await _frames(12)
 _require(target.ragdoll.bodies[0].global_position.distance_to(hip)<0.01,"Shop/pause freezes live ragdoll physics")
 sandbox._set_paused(false)
 await _frames(440)
 _require(not target.ragdoll_active and sandbox._action_timers[2]==0,"Sandbox ragdoll settles and recovers")
 inventory.selected=0
 await _frames(2)
 _require(sandbox.kick_controller.inventory==inventory,"Sandbox kick controller follows selected character inventory")
 sandbox.queue_free()
 await get_tree().process_frame

func _frames(count: int) -> void:
 for frame in count:
  await get_tree().physics_frame
  await get_tree().process_frame

func _mouse(button: MouseButton,pressed: bool) -> void:
 var event := InputEventMouseButton.new()
 event.button_index=button
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func _wheel(button: MouseButton) -> void:
 _mouse(button,true)
 _mouse(button,false)

func _joy_aim(value: float) -> void:
 var event := InputEventJoypadMotion.new()
 event.device=0
 event.axis=JOY_AXIS_TRIGGER_LEFT
 event.axis_value=value
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func _joy_fire(pressed: bool) -> void:
 var event := InputEventJoypadButton.new()
 event.device=0
 event.button_index=JOY_BUTTON_X
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func _key(code: Key,pressed: bool) -> void:
 var event := InputEventKey.new()
 event.keycode=code
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func _require(condition: bool,message: String) -> void:
 if not condition:
  _failed=true
  push_error(message)
  get_tree().quit(1)
