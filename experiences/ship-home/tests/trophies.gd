# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:Array[String]=[]
var home
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func press() -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_B;e.pressed=down;root.push_input(e,true)
func reply(row:Dictionary) -> void:
 var client=home.avatar_client
 client._packet({"id":str(client.serial),"result":{"items":[] if row.is_empty() else [row],"next":null}})
func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 var client=home.avatar_client
 client.unavailable.disconnect(home._identity_lost);client.disconnect_host()
 home.store.directory="user://trophy-test-"+str(Time.get_ticks_usec())
 home._load_profile("alex");home._pause(false)
 home.walker.position=home.trophies.POS+Vector3(0,-1.03,-0.83)
 check(home._station()=="trophies","Controller can reach separate trophy shelf")
 press();check(home.store.trophy_key=="","Offline profile gains no trophy")
 client.trophies_supported=true;client.profile_id="alex"
 for shape in ["cup","medal","plaque"]:
  press()
  check(home.trophies.pending,"Read on interact")
  var row={"key":"org.test.game/"+shape,"shape":shape,"earned":true,"title":shape.capitalize()}
  reply(row)
  check(home.store.trophy_key==row.key and home.facilities.results("trophy-case")[0].key==row.key,"Show only verified trophy")
  check(home.trophies.mesh_root!=null and home.trophies.mesh_root.find_children("*","MeshInstance3D",true,false).size()>0,"Renderable "+shape)
 home._load_profile("alex")
 check(home.trophies.shown.is_empty() and home.trophies.pending,"Reload revalidates pin")
 reply({});check(home.trophies.shown.is_empty() and home.store.trophy_key=="","Withdrawn trophy disappears")
 home.trophies.read(true)
 var stale=str(client.serial)
 home._load_profile("bea")
 client._packet({"id":stale,"result":{"items":[{"key":"org.test.game/cup","earned":true,"shape":"cup","title":"Cup"}]}})
 check(home.trophies.shown.is_empty() and home.store.trophy_key=="","Late reply cannot equip another profile")
 print("GAME TROPHIES ", "PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
