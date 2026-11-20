# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerCharacterMotor
extends Node
## Optional third-person simulation. Caller owns input, camera, identity and spawn.
## Call step once from the CharacterBody3D's _physics_process. +Y up, metres.
@export var walk_speed := 1.5
@export var run_speed := 4.4
@export var sprint_speed := 6.2
@export var crouch_speed := 1.05
@export var acceleration := 24.0
@export var braking := 32.0
@export var run_threshold := 2.4
@export var gravity := 20.0
@export var jump_speed := 6.0
@export var standing_height := 1.8
@export var crouch_height := 1.4
@export var radius := 0.27
@export var slide_speed := 7.5
@export var slide_duration := 0.65
@export var bullet_speed := 9.0
@export var bullet_lift := 7.2
@export var jet_acceleration := 15.0
@export var jet_climb_speed := 4.5
var _mobility: StringName
var _remaining := 0.0
var _heading := Vector3.ZERO
var body: CharacterBody3D
var collider: CollisionShape3D
var crouched := false
var actual_speed := 0.0
var gait := "idle"
var coyote := 0.0
var jump_buffer := 0.0
var landed := false

## Map a radial stick once: dead zone then linear travel, never magnitude squared.
static func stick_direction(value: Vector2, dead_zone := 0.18, outer_dead_zone := 0.20) -> Vector2:
	var inner := clampf(dead_zone,0.0,0.95)
	var full := maxf(inner+0.01,1.0-clampf(outer_dead_zone,0.0,0.95))
	var amount := value.length()
	if amount<=inner:return Vector2.ZERO
	return value.normalized()*clampf(inverse_lerp(inner,full,amount),0.0,1.0)

func bind(character: CharacterBody3D) -> void:
	body=character
	collider=CollisionShape3D.new()
	var capsule := CapsuleShape3D.new();capsule.radius=radius;capsule.height=standing_height
	collider.shape=capsule;collider.position.y=standing_height*0.5
	body.add_child(collider)
	body.floor_snap_length=0.32;body.floor_constant_speed=true
	body.floor_stop_on_slope=true;body.floor_max_angle=deg_to_rad(46)

func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new();shape.radius=radius;shape.height=standing_height-0.04
	query.shape=shape;query.transform=body.global_transform
	query.transform.origin+=Vector3.UP*(standing_height*0.5+0.02)
	query.collision_mask=body.collision_mask;query.exclude=[body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func reset() -> void:
	_mobility = &""
	_remaining = 0.0
	body.velocity=Vector3.ZERO;actual_speed=0.0;gait="idle";coyote=0.0;jump_buffer=0.0

func step(delta: float, direction: Vector3, wants_sprint := false, wants_crouch := false, jump_pressed := false, enabled := true, wants_walk := false, mobility: StringName = &"") -> void:
	if not is_instance_valid(body) or delta<=0:return
	var on_floor := body.is_on_floor()
	landed=false
	direction.y=0;direction=direction.limit_length()
	if not enabled:
		direction=Vector3.ZERO;jump_pressed=false;wants_sprint=false
		jump_buffer=0.0
		_mobility = &""
	elif mobility == &"bullet_jump" and on_floor and not direction.is_zero_approx() and (not crouched or can_stand()):
		_mobility = &"bullet_jump"
		_remaining = 0.64
		_heading = direction.normalized()
		body.velocity.y = bullet_lift
	elif mobility == &"slide" and on_floor and actual_speed > walk_speed:
		_mobility = &"slide"
		_remaining = slide_duration
		_heading = Vector3(body.velocity.x, 0, body.velocity.z).normalized()
	elif mobility == &"jetpack" and (not crouched or can_stand()):
		_mobility = &"jetpack"
	elif _mobility == &"jetpack" or _remaining <= 0.0 or (_mobility == &"slide" and not on_floor):
		_mobility = &""
	if _mobility == &"slide" or (wants_crouch and _mobility == &""):crouched=true
	elif crouched and can_stand():crouched=false
	var height := crouch_height if crouched else standing_height
	(collider.shape as CapsuleShape3D).height=height;collider.position.y=height*0.5
	if _mobility != &"":
		_step_mobility(delta, direction, on_floor)
		return
	gait="crouch" if crouched else "sprint" if wants_sprint else "walk" if wants_walk or direction.length()*run_speed<=walk_speed else "run"
	var speed := crouch_speed if crouched else sprint_speed if wants_sprint else walk_speed if wants_walk else run_speed
	# Gentle stick travel is a walk; full stick is the usual game jog.
	var target := direction*speed
	var horizontal := Vector2(body.velocity.x,body.velocity.z)
	horizontal=horizontal.move_toward(Vector2(target.x,target.z),(braking if direction.is_zero_approx() else acceleration)*delta)
	body.velocity.x=horizontal.x;body.velocity.z=horizontal.y
	coyote=0.10 if on_floor else maxf(0,coyote-delta)
	jump_buffer=0.12 if jump_pressed and enabled else maxf(0,jump_buffer-delta)
	if jump_buffer>0 and coyote>0 and not crouched:
		body.velocity.y=jump_speed;coyote=0;jump_buffer=0
	elif on_floor:body.velocity.y=-0.1
	else:body.velocity.y-=gravity*delta
	_move_and_measure(on_floor)
	if actual_speed<0.08:gait="idle"
	elif crouched:gait="crouch"
	# Do not slow a running clip almost to a stop for partial stick travel or
	# acceleration. Choose the gait from actual travel; speed stays continuous.
	elif actual_speed<=run_threshold:gait="walk"
	elif wants_sprint and actual_speed>run_speed+0.2:gait="sprint"
	else:gait="run"

## Slide and bullet_jump are edge requests. Jetpack is held while thrust is available.
func _step_mobility(delta: float, direction: Vector3, was_on_floor: bool) -> void:
	var horizontal := Vector3(body.velocity.x, 0, body.velocity.z)
	match _mobility:
		&"slide":
			var progress := clampf(_remaining / maxf(slide_duration, 0.001), 0.0, 1.0)
			horizontal = _heading * lerpf(walk_speed, slide_speed, progress)
			body.velocity.y = -0.1
		&"bullet_jump":
			horizontal = _heading * bullet_speed
			body.velocity.y -= gravity * delta
		&"jetpack":
			horizontal = horizontal.move_toward(direction * run_speed, acceleration * delta)
			body.velocity.y = minf(jet_climb_speed, body.velocity.y + jet_acceleration * delta)
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z
	_move_and_measure(was_on_floor)
	coyote = 0.0
	jump_buffer = 0.0
	gait = _mobility
	if _mobility != &"jetpack": _remaining -= delta
	if (_mobility == &"slide" and actual_speed < 0.08) or (_mobility == &"bullet_jump" and (landed or body.is_on_wall() or body.is_on_ceiling())):
		_remaining = 0.0

func _move_and_measure(was_on_floor: bool) -> void:
	body.move_and_slide()
	var real := body.get_real_velocity() - body.get_platform_velocity()
	actual_speed = Vector2(real.x, real.z).length()
	landed = not was_on_floor and body.is_on_floor()
