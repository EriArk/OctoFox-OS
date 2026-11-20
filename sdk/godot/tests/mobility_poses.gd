# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Presenter = preload("../avatar_presenter.gd")
const Motion = preload("../avatar_locomotion.gd")
var failures: Array[String] = []

func check(ok: bool, reason: String) -> void:
	if not ok: failures.append(reason); push_error(reason)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var descriptor := ""
	var captures := ""
	var sequence := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="): descriptor = arg.trim_prefix("--descriptor=")
		if arg == "--sequence": sequence = true
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	if descriptor.is_empty(): push_error("Pass --descriptor=path to an SDK avatar fixture"); quit(1); return
	var avatar = Presenter.from_descriptor(JSON.parse_string(FileAccess.get_file_as_string(descriptor)))
	if avatar == null: quit(1); return
	root.add_child(avatar)
	var motion := Motion.new()
	root.add_child(motion)
	if not motion.bind(avatar): push_error("Could not bind avatar"); quit(1); return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(1.80,0.95,1.45)
	camera.look_at(Vector3(0,0.44,0)); camera.fov = 34
	var light := DirectionalLight3D.new()
	root.add_child(light); light.rotation_degrees = Vector3(-43,24,0)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#c7d7d5")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.75
	root.add_child(world)
	var rig := motion.target
	var pelvis := rig.find_bone("pelvis")
	var thigh := rig.find_bone("thigh.L")
	var rest := rig.get_bone_rest(thigh)
	for action in ["slide","jetpack","bullet_jump"]:
		for i in 30: motion.advance(1.0/60,0,true,false,true)
		var idle := rig.get_bone_pose_rotation(thigh)
		var phases: Array[Quaternion] = []
		for i in 42:
			motion.advance(1.0/60,7,true,action=="slide",action=="slide",action)
			phases.append(rig.get_bone_pose_rotation(pelvis))
			if i == (10 if action == "bullet_jump" else 18):
				check(motion.current == "mobility/" + action, "Dedicated clip: " + action)
				check(idle.angle_to(rig.get_bone_pose_rotation(thigh)) > 0.16, "Distinct leg pose: " + action)
				check(rig.get_bone_rest(thigh).is_equal_approx(rest), "Preserve bind pose")
				if not captures.is_empty():
					await process_frame; await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(captures+"/"+action+".png")==OK,"Capture pose")
			if sequence and not captures.is_empty() and i % 3 == 0:
				await process_frame; await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(captures+"/%s-%02d.png" % [action,i])==OK,"Capture sequence")
		if action == "bullet_jump":
			check(phases[10].angle_to(phases[24]) > 1.0, "Rotate the body through the leap")
		var previous := motion.current
		motion.advance(1.0/60,0,true,false,true)
		check(motion.current == "Idle" and motion.current != previous, "Blend back to grounded stance")
	print("MOBILITY POSES: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
