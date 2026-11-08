# SPDX-License-Identifier: GPL-3.0-only
extends CharacterBody3D

var visual: Node3D
var skeleton: Skeleton3D
var sword: Node3D
var bases := {}
var facing := Vector3(0, 0, 1)
var clock := 0.0
var dash_left := 0.0
var cooldown := 0.0
var attack_left := 0.0
var attack_cooldown := 0.0
var invulnerable := 0.0
var enabled := true
var animator: AnimationPlayer
var pending_hit := false
var mixamo := false

func _ready() -> void:
	visual = get_node("PlayerVisual")
	skeleton = find_skeleton(visual)
	animator = find_animator(visual)
	mixamo = animator != null
	var bone_names := ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"]
	if mixamo:
		bone_names = ["RightArm", "RightForeArm", "RightHand"]
	for bone in bone_names:
		var index := skeleton.find_bone(bone)
		bases[bone] = skeleton.get_bone_pose_rotation(index)
	if animator:
		prepare_animations()
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animator.play("Idle")
		animator.advance(0)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "RightHand"
	skeleton.add_child(hand)
	sword = load("res://Assets/PolygonDungeon/Prefabs/Weapons/SM_Wep_Straightsword_01.tscn").instantiate()
	for child in sword.get_children():
		child.free()
	hand.add_child(sword)
	sword.rotation_degrees = Vector3(90, 0, 0)
	# Mixamo skeletons commonly use centimeter-scale armature nodes.
	sword.scale = Vector3.ONE * 1.35 / skeleton.global_basis.get_scale().x
	if not mixamo:
		pose(0)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null

func find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_animator(child)
		if found:
			return found
	return null

func prepare_animations() -> void:
	for name_key in animator.get_animation_list():
		var clip: Animation = animator.get_animation(name_key)
		if name_key in ["Idle", "Walking", "Running"]:
			clip.loop_mode = Animation.LOOP_LINEAR
		# Keep hip height/bob, but prevent clip translation moving the mesh
		# away from the physics capsule. The controller owns world movement.
		for track in range(clip.get_track_count()):
			if clip.track_get_type(track) == Animation.TYPE_POSITION_3D and str(clip.track_get_path(track)).ends_with(":Hips"):
				for key in range(clip.track_get_key_count(track)):
					var value: Vector3 = clip.track_get_key_value(track, key)
					value.x = 0
					value.z = 0
					clip.track_set_key_value(track, key, value)

func animate_character(delta: float, moving: bool) -> void:
	if not animator:
		pose(sin(clock * 13) if moving else 0)
		return
	var clip := "Running" if moving else "Idle"
	if moving and Input.is_action_pressed("walk"):
		clip = "Walking"
	if animator.current_animation != clip:
		animator.play(clip, 0.12)
	skeleton.clear_bones_global_pose_override()
	animator.advance(delta)
	# Apply the sword-arm layer after Mixamo updates the rest of the body.
	var phase := 1.0 - attack_left / 0.38 if attack_left > 0 else 0.0
	var sweep := 0.0
	if attack_left > 0:
		sweep = lerpf(-1.3, 1.5, smoothstep(0.12, 0.7, phase)) * sin(PI * phase)
	var arm := skeleton.find_bone("RightArm")
	var forearm := skeleton.find_bone("RightForeArm")
	skeleton.set_bone_pose_rotation(forearm, skeleton.get_bone_pose_rotation(forearm) * Quaternion(Vector3.RIGHT, -0.45 - absf(sweep) * 0.3))
	var aim := Vector3(0.45, -0.75, 0.3)
	if attack_left > 0:
		var arc := lerpf(-0.8, 2.4, smoothstep(0.08, 0.8, phase))
		var extended := Vector3(cos(arc), 0.1, sin(arc))
		aim = aim.lerp(extended, sin(PI * phase))
	var arm_pose := skeleton.get_bone_global_pose(arm)
	arm_pose.basis = Basis(Quaternion(arm_pose.basis.y.normalized(), aim.normalized())) * arm_pose.basis
	skeleton.set_bone_global_pose_override(arm, arm_pose, 1.0, true)

func bone(name_key: String, axis: Vector3, angle: float) -> void:
	skeleton.set_bone_pose_rotation(skeleton.find_bone(name_key), bases[name_key] * Quaternion(axis, angle))

func pose(stride: float) -> void:
	bone("LeftUpperArm", Vector3.FORWARD, -1.15 + stride * 0.2)
	bone("RightUpperArm", Vector3.FORWARD, 1.0 - sin(attack_left / 0.38 * PI) * 1.6)
	bone("LeftLowerArm", Vector3.RIGHT, -0.25)
	bone("RightLowerArm", Vector3.RIGHT, -0.65)
	bone("LeftUpperLeg", Vector3.RIGHT, stride * 0.45)
	bone("RightUpperLeg", Vector3.RIGHT, -stride * 0.45)

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	clock += delta
	cooldown = maxf(cooldown - delta, 0)
	attack_cooldown = maxf(attack_cooldown - delta, 0)
	attack_left = maxf(attack_left - delta, 0)
	invulnerable = maxf(invulnerable - delta, 0)
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := Vector3(input.x + input.y, 0, input.y - input.x).normalized()
	if direction.length_squared() > 0.01:
		facing = direction
	if Input.is_action_just_pressed("dash") and cooldown <= 0:
		dash_left = 0.18
		cooldown = 0.8
		invulnerable = 0.3
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		attack_left = 0.38
		attack_cooldown = 0.46
		pending_hit = true
	if pending_hit and attack_left <= 0.25:
		pending_hit = false
		get_parent().strike()
	var speed := 3.5 if Input.is_action_pressed("walk") else 7.0
	var motion := facing * 23 if dash_left > 0 else direction * speed
	dash_left = maxf(dash_left - delta, 0)
	velocity.x = motion.x
	velocity.z = motion.z
	if not is_on_floor():
		velocity.y -= 25 * delta
	else:
		velocity.y = 0
	move_and_slide()
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), delta * 16)
	animate_character(delta, direction.length_squared() > 0)
	if not mixamo:
		visual.position.y = absf(sin(clock * 13)) * 0.06 if direction.length_squared() > 0 else sin(clock * 2) * 0.015
	if position.y < -8:
		get_parent().respawn()
