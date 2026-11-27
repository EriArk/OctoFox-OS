# SPDX-License-Identifier: GPL-3.0-or-later
# Run with a window and the handheld renderer. Move the left stick during flight.
extends SceneTree

var started := Time.get_ticks_msec()
var previous_time := started
var previous_phase := ""
var longest_flight_frame := 0
var steered := false

func _initialize() -> void:
 change_scene_to_file.call_deferred("res://transit.tscn")

func _process(_delta:float) -> bool:
 var now:=Time.get_ticks_msec()
 var elapsed:=now-started
 var gap:=now-previous_time
 previous_time=now
 if elapsed>90000:
  push_error("Destination did not open within 90 seconds")
  quit(1)
  return false
 var scene:=root.get_node_or_null("Transit")
 if not is_instance_valid(scene) or scene.phase=="idle":
  if is_instance_valid(current_scene) and current_scene.name=="ShipHome" and not previous_phase.is_empty():
   print("Ship Home opened after %d ms. Longest interactive frame %d ms. Steering observed %s."%[elapsed,longest_flight_frame,steered])
   quit(0 if steered and longest_flight_frame<2000 else 1)
  return false
 var phase:String=scene.phase
 if phase=="flight" and previous_phase=="flight":longest_flight_frame=maxi(longest_flight_frame,gap)
 if phase=="flight" and is_instance_valid(scene.flight) and scene.flight.drift.length()>0.02:steered=true
 if phase!=previous_phase:print("%d ms: %s -> %s (frame %d ms)"%[elapsed,previous_phase,phase,gap])
 if phase=="error":quit(1)
 previous_phase=phase
 return false
