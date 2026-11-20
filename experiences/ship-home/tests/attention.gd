# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	printerr(message)
	quit(1)

func run() -> void:
	var home = load("res://main.tscn").instantiate()
	root.add_child(home)
	var fixture := OS.get_environment("SHIP_TEST_DESCRIPTOR")
	if not fixture.is_empty():
		var descriptor = JSON.parse_string(FileAccess.get_file_as_string(fixture))
		if not home.walker.install_avatar(descriptor):
			fail("Could not load the SDK fixture")
			return
	else:
		var deadline := Time.get_ticks_msec() + 25000
		while home.profile.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
	var walker = home.walker
	var avatar = walker.visual
	if not avatar.has_method("set_attention") or not avatar._face_bindings.has("gaze_left"):
		fail("The ship did not receive the directional eye controls")
		return
	walker.set_physics_process(false)
	walker.position = Vector3(-2.55, 0.08, 2.45)
	avatar.rotation.y = PI
	home._process(0.1)
	avatar._process(2)
	if home._station() != "workbench" or avatar._face_values.gaze_right <= 0.1 or avatar._head.offset.is_equal_approx(Quaternion.IDENTITY):
		fail("Workbench activation and avatar attention disagree")
		return
	home._pause(true)
	home._process(0.1)
	avatar._process(2)
	if avatar._turn != Vector2.ZERO or avatar._gaze != Vector2.ZERO:
		fail("Attention did not release on pause")
		return
	home._pause(false)
	avatar.rotation.y = 0
	home._process(0.1)
	if avatar._attention != Vector2.ZERO:
		fail("Avatar turned toward a station behind its shoulders")
		return
	walker.position = Vector3(0, 0.08, 0)
	home._process(0.1)
	if not home._station().is_empty() or avatar._attention != Vector2.ZERO:
		fail("An unavailable station retained focus")
		return
	print("SHIP_ATTENTION_OK workbench, pause, rear target, exit")
	quit()
