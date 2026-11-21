# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Catch=preload("res://scripts/shore_catch.gd")
const Equipment=preload("res://addons/avatar/character_equipment.gd")
const Rod=preload("res://addons/avatar/items/fishing_rod.tres")
enum Phase {AWAY, READY, WINDUP, CAST, WAIT, BITE, FIGHT, LANDED, MISSED, AQUARIUM}
var phase:=Phase.AWAY
var fight:=Catch.new()
var equipment:=Equipment.new()
var home:Node
var walker:ShipWalker
var view:=Camera3D.new()
var pole:=Node3D.new()
var caught_model:Node3D
var line:=MeshInstance3D.new()
var float_root:=Node3D.new()
var panel:=PanelContainer.new()
var caption:=Label.new()
var detail:=Label.new()
var gauge:=ProgressBar.new()
var reach:=0.0
var timer:=0.0
var elapsed:=0.0
var aim:=0.0
var specimen:Dictionary={}
var outcome:=""
var selected:=0
var release_id:=""
var direction:=Vector3.FORWARD
var launch:=Vector3.ZERO
var water_y:=0.0
var hand_index:=-1
var speaker:=AudioStreamPlayer.new()
var sounds:Dictionary={}
var camera_pitch:=0.0
var camera_yaw:=0.0

func configure(scene:Node,overlay:CanvasLayer) -> void:
 home=scene;walker=home.walker
 view.fov=58;view.near=0.045;view.far=2400;add_child(view)
 add_child(equipment);add_child(pole);add_child(line);add_child(float_root);add_child(speaker)
 for frequency in [330,660,880]:
  var sound:=AudioStreamWAV.new()
  sound.format=AudioStreamWAV.FORMAT_16_BITS;sound.mix_rate=16000
  var pcm:=PackedByteArray();pcm.resize(2240)
  for i in 1120:
   pcm.encode_s16(i*2,roundi(3500*sin(TAU*frequency*i/16000.0)*sin(PI*i/1120.0)))
  sound.data=pcm;sounds[frequency]=sound
 var art:ShipInterior=home.art
 art.beam(pole,Vector3.DOWN*0.10,Vector3.UP*0.33,0.032,Color("bc8a59"))
 art.beam(pole,Vector3.UP*0.33,Vector3.UP*1.10,0.017,Color("1e5d60"))
 art.beam(pole,Vector3.UP*1.10,Vector3.UP*1.64,0.009,Color("e9c77c"))
 art.cylinder(pole,Vector3(0,0.15,0.06),0.065,0.06,Color("d3ae67")).rotation.z=PI/2
 var filament:=CylinderMesh.new();filament.height=1;filament.bottom_radius=0.007;filament.top_radius=0.007;filament.radial_segments=5
 line.mesh=filament;line.material_override=art.material(Color("d4e6d8"));line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 art.cylinder(float_root,Vector3.UP*0.065,0.060,0.13,Color("eeeacb"),0.05)
 art.cylinder(float_root,Vector3.UP*0.20,0.043,0.14,Color("f27754"),0.018)
 var ripple:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=0.23;ring.outer_radius=0.25;ring.rings=24;ring.ring_segments=5
 ripple.mesh=ring;ripple.material_override=art.material(Color("a3d8d0"));ripple.scale.y=0.16;float_root.add_child(ripple)
 overlay.add_child(panel);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 panel.add_theme_stylebox_override("panel",home.prompts.skin(Color("142d33ec"),10,15,10))
 var column:=VBoxContainer.new();panel.add_child(column)
 caption.add_theme_font_size_override("font_size",22);column.add_child(caption)
 detail.add_theme_font_size_override("font_size",16);detail.modulate=Color("c2d5ce");column.add_child(detail)
 gauge.custom_minimum_size=Vector2(214,7);gauge.show_percentage=false;column.add_child(gauge)
 close()

func cue(hz:int,pulse:float) -> void:
 if DisplayServer.get_name()!="headless":
  speaker.stream=sounds[hz];speaker.play()
 var pads:=Input.get_connected_joypads()
 if not pads.is_empty():Input.start_joy_vibration(pads[0],pulse,pulse*0.55,0.16)

func open_shore() -> void:
 if not equipment.equip("ship-field-rod",Rod):return
 camera_pitch=walker.pitch;camera_yaw=walker.yaw
 direction=home.flight.dock_basis(home.flight.berth).inverse()*Vector3.BACK
 walker.yaw=atan2(-direction.x,-direction.z)
 walker.pitch=-0.16;walker.pivot.rotation=Vector3(walker.pitch,walker.yaw,0)
 walker.visual.rotation.y=atan2(direction.x,direction.z)
 hand_index=walker.skeleton.find_bone(Rod.socket) if is_instance_valid(walker.skeleton) else -1
 if is_instance_valid(walker.motion):walker.motion.advance(0.12,0,true)
 var side:=direction.cross(Vector3.UP)
 var foot:=walker.global_position
 set_view(foot-direction*1.65+side*1.15+Vector3.UP*1.65,foot+direction*2.8+side*0.4+Vector3.UP*0.90,false)
 water_y=home.flight.GROUND_Y+home.flight.coast.SEA_Y
 walker.stationary=true;walker.attend(null);phase=Phase.READY
 aim=0;specimen={};outcome="";pole.show();panel.show();refresh()

func open_tank() -> void:
 var tank:Node3D=home.studio.aquarium
 set_view(tank.to_global(Vector3(0,1.27,1.35)),tank.to_global(Vector3(0,1.21,0)),true)
 view.fov=72
 walker.hide()
 if home.can_query_fish():home.avatar_client.read_fish()
 walker.stationary=true;phase=Phase.AQUARIUM;selected=0;release_id="";outcome="";panel.show();refresh()

func set_view(eye:Vector3,target:Vector3,aboard:bool) -> void:
 view.fov=58
 home.Exterior.configure_camera(view,aboard)
 view.global_position=eye;view.look_at(target);view.make_current()

func close() -> void:
 speaker.stop();speaker.stream=null
 if phase!=Phase.AWAY:
  walker.show();walker.camera.make_current();walker.stationary=false
  if phase!=Phase.AQUARIUM:
   walker.pitch=camera_pitch;walker.yaw=camera_yaw
 phase=Phase.AWAY;equipment.unequip();pole.hide();line.hide();float_root.hide();panel.hide()
 clear_catch()
 specimen={}

func clear_catch() -> void:
 if is_instance_valid(caught_model):
  caught_model.hide();caught_model.queue_free();caught_model=null

func control(event:InputEvent) -> void:
 if event.is_action_pressed("cancel_ship"):
  if phase==Phase.AQUARIUM and release_id!="":release_id="";refresh();return
  close();return
 if phase==Phase.AQUARIUM:
  var stock:Array=home.fish_stock()
  if stock.is_empty():return
  if release_id!="":
   if event.is_action_pressed("interact"):
    outcome=home.release_fish(release_id);release_id=""
   refresh();return
  if event.is_action_pressed("next_item") or event.is_action_pressed("ui_down"):
   if selected+1==stock.size() and home.can_export() and home.avatar_client.fish_next!="":
    home.avatar_client.read_fish(true);outcome="Loading more fish"
   else:selected=wrapi(selected+1,0,stock.size());outcome=""
  elif event.is_action_pressed("previous_item") or event.is_action_pressed("ui_up"):
   selected=wrapi(selected-1,0,stock.size());outcome=""
  elif event.is_action_pressed("interact"):
   var row:Dictionary=stock[selected]
   if row.get("account",false):
    if row.place!="tank" and home.tank_full():outcome="Aquarium full"
    else:home.avatar_client.display_fish(row.id,row.place!="tank");outcome=""
   elif row.place in ["tank","bag"]:
    var place:String="tank" if row.place=="bag" else "bag"
    outcome=home.move_fish(row.id,place)
  elif event.is_action_pressed("decorate") and stock[selected].place=="bag":
   release_id=stock[selected].id
  elif event.is_action_pressed("pick_item"):
   if not stock[selected].get("account",false):home.export_fish(stock[selected])
  refresh();return
 if phase in [Phase.READY,Phase.MISSED] and event.is_action_pressed("fish_reel"):
  var foot:=walker.global_position;var side:=direction.cross(Vector3.UP)
  set_view(foot-direction*1.65+side*1.15+Vector3.UP*1.65,foot+direction*2.8+side*0.4+Vector3.UP*0.90,false)
  phase=Phase.WINDUP;timer=0;outcome="";refresh()
 elif phase==Phase.WINDUP and event.is_action_released("fish_reel") and equipment.use_item():
  reach=lerpf(4.0,17.0,clampf(timer/1.1,0,1))
  specimen=Catch.specimen(home.flight.berth,reach);phase=Phase.CAST;timer=0
  launch=pole.to_global(Vector3.UP*1.64);line.show();float_root.show();cue(330,0.15);refresh()
 elif phase==Phase.BITE and event.is_action_pressed("fish_hook"):
  fight.start(specimen,reach);phase=Phase.FIGHT;cue(660,0.5);refresh()
 elif phase==Phase.WAIT and event.is_action_pressed("fish_hook"):
  miss("Too early · the float was still on the surface")
 elif phase==Phase.LANDED:
  if event.is_action_pressed("interact"):
   outcome=home.keep_fish(specimen)
   if outcome=="":phase=Phase.READY;specimen={};outcome="In the livewell"
  elif event.is_action_pressed("pick_item"):
   phase=Phase.READY;specimen={};outcome="Released into the water"
  if phase==Phase.READY:clear_catch();line.hide()
  refresh()

func miss(reason:String) -> void:
 phase=Phase.MISSED;outcome=reason;line.hide();float_root.hide();specimen={};cue(330,0.2);refresh()

func tick(dt:float) -> void:
 if phase==Phase.AWAY:return
 if phase==Phase.AQUARIUM:return
 elapsed+=dt
 if phase==Phase.WAIT:timer-=dt
 else:timer+=dt
 var side:=direction.cross(Vector3.UP)
 var stick:=Input.get_axis("look_left","look_right")+Input.get_axis("rotate_left","rotate_right")
 aim=lerpf(aim,clampf(stick,-1,1),1-exp(-dt*7))
 if is_instance_valid(walker.motion):walker.motion.advance(dt,0,true)
 var hand:=walker.global_position+Vector3.UP*0.84+side*0.26+direction*0.18
 if hand_index>=0 and is_instance_valid(walker.skeleton):
  var bones:Dictionary=walker.pose.bones
  var target:=walker.position+Vector3.UP*0.89+side*(0.17+aim*0.09)+direction*0.29
  if bones.has("upper_arm.R") and bones.has("forearm.R"):
   walker.pose.reach(bones["upper_arm.R"],bones["forearm.R"],hand_index,target,side-Vector3.UP)
  if bones.has("hand.L") and bones.has("upper_arm.L") and bones.has("forearm.L"):
   walker.pose.reach(bones["upper_arm.L"],bones["forearm.L"],bones["hand.L"],target+Vector3.UP*0.09+direction*0.07-side*0.06,-side-Vector3.UP)
  hand=walker.skeleton.to_global(walker.skeleton.get_bone_global_pose(hand_index).origin)
 pole.global_position=hand
 var inclination:=0.72 if phase!=Phase.WINDUP else lerpf(0.72,-0.40,clampf(timer/1.1,0,1))
 pole.quaternion=Quaternion(Vector3.UP,(Vector3.UP+direction*inclination+side*aim*0.44).normalized())
 if phase==Phase.LANDED and is_instance_valid(caught_model):
  var tip:=pole.to_global(Vector3.UP*1.64)
  caught_model.position=tip+Vector3.DOWN*0.70+side*(0.08*sin(elapsed*4))
  caught_model.rotation=Vector3(0,walker.yaw+0.18*sin(elapsed*5),1.05+0.12*sin(elapsed*7))
  stretch_line(tip,caught_model.position)
 if phase in [Phase.CAST,Phase.WAIT,Phase.BITE,Phase.FIGHT]:
  var span:=fight.distance if phase==Phase.FIGHT else reach
  var dest:=walker.position+direction*span+side*(fight.surge*fight.direction*1.6 if phase==Phase.FIGHT else 0.0)
  dest.y=water_y+0.03+0.035*sin(elapsed*4)
  if phase==Phase.CAST:
   var u:=minf(timer/0.66,1)
   dest=launch.lerp(dest,u)+Vector3.UP*(2.8*sin(PI*u))
   if u>=1:phase=Phase.WAIT;timer=randf_range(1.6,4.2);cue(330,0.1)
  elif phase==Phase.WAIT:
   if timer<=0:phase=Phase.BITE;timer=0;cue(880,0.65)
  elif phase==Phase.BITE:
   dest.y-=0.16+0.09*sin(elapsed*15)
   if timer>1.45:miss("The fish let go");return
  else:
   var result:=fight.advance(dt,Input.get_action_strength("fish_reel"),aim)
   if result=="caught":
    phase=Phase.LANDED;float_root.hide()
    caught_model=home.studio.make_fish(self,specimen)
    var grip:=pole.global_position
    set_view(grip+side*1.45-direction*0.75+Vector3.UP*0.56,grip+direction*0.65+Vector3.UP*0.62,false)
    tick(0);cue(880,0.35);return
   if result!="":miss(result);return
  float_root.position=dest
  var tip:=pole.to_global(Vector3.UP*1.64)
  stretch_line(tip,dest)
 refresh()

func stretch_line(tip:Vector3,end:Vector3) -> void:
 line.position=(tip+end)*0.5
 line.quaternion=Quaternion(Vector3.UP,(end-tip).normalized())
 line.scale.y=tip.distance_to(end)

func refresh() -> void:
 if phase==Phase.AWAY:return
 var pad:bool=home.prompts.gamepad
 var reel:="RT" if pad else "Space"
 var hook:="LT" if pad else "R"
 var accept:="A" if pad else "F"
 var alt:="Y"
 var back:="B" if pad else "Esc"
 var text:=""
 gauge.visible=phase in [Phase.WINDUP,Phase.FIGHT]
 match phase:
  Phase.READY,Phase.MISSED:
   caption.text=outcome if outcome!="" else str(Catch.WATERS[home.flight.berth])
   text="Hold %s to cast · %s Leave"%[reel,back]
  Phase.WINDUP:
   caption.text="Cast distance · %d m"%roundi(lerpf(4,17,minf(timer/1.1,1)))
   gauge.value=minf(timer/1.1,1)*100;text="Release "+reel+" to cast"
  Phase.CAST:caption.text="Casting";text=""
  Phase.WAIT:caption.text="Watch the float";text="Set the hook when it dips"
  Phase.BITE:caption.text="Bite!";text=hook+"  Set hook"
  Phase.FIGHT:
   caption.text="%0.1f m   ·   %s"%[fight.distance,("Ease off!" if fight.tension>0.83 else ("Pulling right" if fight.direction>0 else "Pulling left"))]
   gauge.value=clampf(fight.tension,0,1)*100
   text=reel+"  Reel   ·   "+("RS" if pad else "Q / E")+"  Angle rod"
  Phase.LANDED:
   caption.text=Catch.title(specimen);text=(outcome+"   " if outcome!="" else "")+accept+"  Keep   ·   "+alt+"  Release"
  Phase.AQUARIUM:
   var stock:Array=home.fish_stock()
   if stock.is_empty():
    caption.text="Aquarium";text="Livewell empty · Fish the shores of Echo Orchard or Table Isle"
   else:
    selected=clampi(selected,0,stock.size()-1)
    var row:Dictionary=stock[selected]
    caption.text="%d / %d   %s"%[selected+1,stock.size(),Catch.title(row)]
    text="%s · %s\n"%[Catch.WATERS[int(row.site)],{"tank":"Aquarium","bag":"Livewell","inventory":"Profile inventory","sending":"Inventory transfer"}.get(row.place,"")]
    text+=("LB / RB" if pad else "[ / ]")+"  Browse"
    if row.place!="sending":text+="   "+accept+("  Into aquarium" if row.place!="tank" else ("  To inventory" if row.get("account",false) else "  To livewell"))
    if not row.get("account",false) and row.place!="tank" and home.can_export():text+="   Y  "+("Retry transfer" if row.place=="sending" else "To inventory")
    if row.place=="bag":text+="   "+("X" if pad else "Tab")+"  Release"
   text+="   "+back+"  Close"
   if release_id!="":text="Release this fish?   "+accept+"  Release   "+back+"  Cancel"
   if outcome!="":text+="\n"+outcome
   elif home.can_query_fish() and home.avatar_client.fish_error!="":text+="\n"+home.avatar_client.fish_error
 detail.text=text
 panel.reset_size();panel.position=Vector2(24,panel.get_viewport_rect().size.y-panel.size.y-22)
