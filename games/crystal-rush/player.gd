# SPDX-License-Identifier: GPL-3.0-only
extends CharacterBody3D

var speed := 7.0
var dash_time := 0.0
var dash_cooldown := 0.0
var invulnerable := 0.0
var facing := Vector3.FORWARD
var visual: Node3D
var enabled := false

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	dash_cooldown = maxf(0, dash_cooldown - delta)
	invulnerable = maxf(0, invulnerable - delta)
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := Vector3(input.x, 0, input.y)
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0:
		dash_time = 0.18
		dash_cooldown = 1.2
		invulnerable = 0.3
	if dash_time > 0:
		dash_time -= delta
		velocity.x = facing.x * 24
		velocity.z = facing.z * 24
	else:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 24 * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 9
	move_and_slide()
	position.x = clampf(position.x, -21.0, 21.0)
	position.z = clampf(position.z, -21.0, 21.0)
	if visual:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), delta * 14)
		visual.visible = invulnerable <= 0 or int(invulnerable * 20) % 2 == 0
	if position.y < -10:
		position = Vector3(0, 2, 0)
