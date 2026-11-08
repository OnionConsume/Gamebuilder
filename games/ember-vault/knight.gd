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

func _ready() -> void:
	visual = get_node("Character_Hero_Knight_Female")
	skeleton = visual.get_node("GeneralSkeleton")
	for bone in ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"]:
		var index := skeleton.find_bone(bone)
		bases[bone] = skeleton.get_bone_pose_rotation(index)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "RightHand"
	skeleton.add_child(hand)
	sword = load("res://Assets/PolygonDungeon/Prefabs/Weapons/SM_Wep_Straightsword_01.tscn").instantiate()
	for child in sword.get_children():
		child.queue_free()
	hand.add_child(sword)
	sword.rotation_degrees = Vector3(90, 0, 0)
	sword.scale = Vector3.ONE * 1.35
	pose(0)

func bone(name_key: String, axis: Vector3, angle: float) -> void:
	skeleton.set_bone_pose_rotation(skeleton.find_bone(name_key), bases[name_key] * Quaternion(axis, angle))

func pose(stride: float) -> void:
	bone("LeftUpperArm", Vector3.FORWARD, -1.15 + stride * 0.2)
	bone("RightUpperArm", Vector3.FORWARD, 1.0 - sin(attack_left / 0.3 * PI) * 1.6)
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
		attack_left = 0.3
		attack_cooldown = 0.42
		get_parent().strike()
	var motion := facing * 23 if dash_left > 0 else direction * 7
	dash_left = maxf(dash_left - delta, 0)
	velocity.x = motion.x
	velocity.z = motion.z
	if not is_on_floor():
		velocity.y -= 25 * delta
	move_and_slide()
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), delta * 16)
	pose(sin(clock * 13) if direction.length_squared() > 0 else 0)
	visual.position.y = absf(sin(clock * 13)) * 0.06 if direction.length_squared() > 0 else sin(clock * 2) * 0.015
	if position.y < -8:
		get_parent().respawn()
