# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Vitals = preload("../character_vitals.gd")
const Equipment = preload("../character_equipment.gd")
const Weapon = preload("../items/weapon.tres")
const Device = preload("../items/device.tres")
const Rod = preload("../items/fishing_rod.tres")
const Motor = preload("../character_motor.gd")
var failures: Array[String] = []
var actions: Array[String] = []
var defeats := 0
var body := CharacterBody3D.new()
var motor := Motor.new()
var direction := Vector3.FORWARD
var request: StringName
var enabled := true

func check(ok: bool, reason: String) -> void:
	if not ok: failures.append(reason); push_error(reason)

func _initialize() -> void: run.call_deferred()

func _physics_process(delta: float) -> bool:
	if motor.body != null: motor.step(delta, direction, false, false, false, enabled, false, request)
	if request != &"jetpack": request = &""
	return false

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var stats := Vitals.new()
	stats.defeated.connect(func(): defeats += 1)
	check(stats.configure(100, 100, 20, 5, 10), "Configure")
	stats.take_damage(12)
	check(stats.health == 100 and stats.shield == 8, "Shields take damage first")
	stats.take_damage(48)
	check(stats.health == 80 and stats.shield == 0, "Armour mitigates overflow")
	check(stats.try_spend(&"mana", 7) and stats.mana == 3 and stats.energy == 5, "Independent pools")
	check(not stats.try_spend(&"mana", 4) and stats.mana == 3, "Insufficient mana")
	check(not stats.configure(NAN) and not stats.try_spend(&"energy", -1), "Reject invalid amounts")
	check(stats.restore(&"shield", 1000) and stats.shield == 20, "Restoration capped")
	stats.take_damage(1000); stats.take_damage(5)
	check(stats.health == 0 and defeats == 1 and not stats.try_spend(&"mana", 1), "One defeat and no dead actor spending")
	stats.refill()
	check(stats.health == 100 and stats.mana == 10 and stats.energy == 5, "Respawn")

	var equipment := Equipment.new()
	root.add_child(equipment)
	equipment.used.connect(func(id: String, action: StringName): actions.append(id + "/" + action))
	for pair in [["blade", Weapon], ["scanner", Device], ["lake-rod", Rod]]:
		check(equipment.equip(pair[0], pair[1]) and equipment.use_item(), "Equip and use " + pair[0])
	check(actions == ["blade/attack","scanner/activate","lake-rod/cast"], "Dispatch correct item and verb")
	var rig := Skeleton3D.new()
	root.add_child(rig)
	rig.add_bone("hand.R")
	var prop := Node3D.new()
	var rod = Rod.duplicate()
	rod.model = PackedScene.new()
	rod.model.pack(prop); prop.free()
	check(equipment.equip("rod-2",rod,rig), "Attach a game prop")
	var attachment := rig.get_child(0) as BoneAttachment3D
	check(attachment.bone_name == "hand.R" and attachment.get_child_count() == 1, "Uses hand socket")
	var incompatible = rod.duplicate()
	incompatible.socket = "hand.L"
	check(not equipment.equip("other",incompatible,rig) and equipment.instance_id == "rod-2", "Failed switch preserves current item")
	equipment.unequip()
	check(rig.get_child_count() == 0 and not equipment.use_item(), "Unequip clears prop and action")

	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,1,100); collider.shape = box
	floor_body.add_child(collider); root.add_child(floor_body); floor_body.position.y = -0.5
	root.add_child(body); body.add_child(motor); motor.bind(body)
	await frames(40)
	request = &"slide"; await frames(3)
	check(motor.gait == "slide" and motor.crouched and motor.actual_speed > motor.run_speed, "Moving slide lowers collider")
	request = &"bullet_jump"; await frames(3)
	check(motor.gait == "bullet_jump" and not body.is_on_floor() and body.velocity.y > 0 and not motor.crouched, "Leap out of a slide")
	await frames(6)
	var vy := body.velocity.y
	request = &"bullet_jump"; await frames(2)
	check(body.velocity.y < vy, "Cannot chain impulse in midair")
	await frames(100)
	check(body.is_on_floor() and motor.gait == "run", "Restore ordinary movement on landing")
	direction = Vector3.ZERO
	request = &"jetpack"; await frames(35)
	check(motor.gait == "jetpack" and body.position.y > 0.5 and body.velocity.y <= motor.jet_climb_speed, "Jetpack climbs within speed cap")
	request = &""; await frames(3)
	check(motor.gait != "jetpack" and body.velocity.y < motor.jet_climb_speed, "Release ends thrust")
	enabled = false; request = &"jetpack"; await frames(95)
	check(body.is_on_floor() and motor.gait == "idle", "Revocation prevents thrust")
	print("GAMEPLAY SDK: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
