# SPDX-License-Identifier: GPL-3.0-only
extends Node3D

const PREFABS := "res://Assets/PolygonDungeon/Prefabs/"
const ROOM_CENTERS := [Vector3(0, 0, 0), Vector3(0, 0, -40), Vector3(0, 0, -80)]
const ROOM_NAMES := ["I  /  THE CINDER ATRIUM", "II  /  HALL OF THE FORGOTTEN", "III  /  THE EMBER THRONE"]
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var room_label: Label
var status: Label
var hint: Label
var health := 5
var room_index := 0
var paused := false
var won := false
var dead := false
var enemies: Array[Node3D] = []
var enemy_hp := {}
var seals := 0
var clock := 0.0
var slash: MeshInstance3D
var slash_left := 0.0
var checkpoint := Vector3(0, 0.3, 8)
var zoom := 28.0

func _ready() -> void:
	setup_input()
	build_lighting()
	world = Node3D.new()
	world.name = "DungeonArchitecture"
	add_child(world)
	build_map()
	build_player()
	build_ui()
	spawn_guardians()
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture")
	elif "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--bake" in OS.get_cmdline_user_args():
		call_deferred("bake_map")
	elif "--physics-test" in OS.get_cmdline_user_args():
		call_deferred("physics_test")

func setup_input() -> void:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "dash": [KEY_SPACE, KEY_SHIFT], "attack": [KEY_J, KEY_F]}
	for action in keys:
		InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)

func build_lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	var env: Environment = environment.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("100e20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8485b2")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("e8b591")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	add_child(camera)
	camera.current = true
	camera.position = Vector3(23, 30, 23)
	camera.look_at(Vector3.ZERO)

func mat(color: Color, emission := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	if emission:
		result.emission_enabled = true
		result.emission = color
	return result

func cube(at: Vector3, size: Vector3, color: Color, solid := false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat(color)
	(parent if parent else world).add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func strip_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or child is CollisionPolygon3D:
			child.free()
		else:
			strip_collision(child)

func character_visual(asset: String) -> Node3D:
	# Prefabs have CharacterBody3D roots. Keep only the skeleton as a visual,
	# otherwise a nested body collides with and lifts the player controller.
	var source: Node3D = load(PREFABS + "Characters/" + asset + ".tscn").instantiate()
	var visual := Node3D.new()
	visual.name = asset
	var skeleton: Skeleton3D = source.get_node("GeneralSkeleton")
	own_nodes(skeleton, null)
	skeleton.owner = null
	source.remove_child(skeleton)
	visual.add_child(skeleton)
	strip_collision(visual)
	source.free()
	return visual

func prop(asset: String, at: Vector3, turn := 0.0, size := Vector3.ONE, collision := false) -> Node3D:
	var node: Node3D = load(PREFABS + asset + ".tscn").instantiate()
	if not collision:
		strip_collision(node)
	world.add_child(node)
	node.position = at
	node.rotation_degrees.y = turn
	node.scale = size
	return node

func tint_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var replacement: StandardMaterial3D = original.duplicate()
				replacement.albedo_color = color
				node.set_surface_override_material(surface, replacement)
	for child in node.get_children():
		tint_meshes(child, color)

func build_map() -> void:
	var lava := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	lava.mesh = plane
	lava.position = Vector3(0, -3, -40)
	var shader := ShaderMaterial.new()
	shader.shader = load("res://lava.gdshader")
	lava.material_override = shader
	world.add_child(lava)
	for index in range(3):
		build_room(ROOM_CENTERS[index], index)
	for center_z in [-20, -60]:
		cube(Vector3(0, -0.31, center_z), Vector3(5, 1, 16), Color("211e2c"), true)
		for z in range(-7, 8, 5):
			prop("Environments/Floors/SM_Env_Tiles_01", Vector3(-2.5, 0, center_z + z - 0.5))
		for side in [-1, 1]:
			cube(Vector3(side * 2.8, 0.25, center_z), Vector3(0.35, 0.7, 16), Color("5e463e"), true)
			for z in [-5, 5]:
				brazier(Vector3(side * 2.8, 0.6, center_z + z), Color("ff783a"), 0.6)

func build_room(center: Vector3, index: int) -> void:
	cube(center + Vector3(0, -1.12, 0), Vector3(31, 2.6, 26), Color("24212a"), true)
	for x in range(-15, 15, 5):
		for z in range(-12, 13, 5):
			var tile := "SM_Env_Tiles_01" if (x + z) % 3 else "SM_Env_Tiles_02"
			var floor_tile := prop("Environments/Floors/" + tile, center + Vector3(x, 0, z))
			tint_meshes(floor_tile, Color("7b7487"))
	for side in [-1, 1]:
		for x in range(-15, 15, 5):
			if x == -5 or x == 0:
				continue
			var rear: bool = side == -1
			prop("Environments/Walls/SM_Env_Wall_01", center + Vector3(x, 0, side * 12.8), 0, Vector3(1, 0.72 if rear else 0.16, 1))
			cube(center + Vector3(x + 2.5, 0.5, side * 12.8), Vector3(5, 1, 0.4), Color("53443d"), true)
		for z in range(-12, 13, 5):
			prop("Environments/Walls/SM_Env_Wall_01", center + Vector3(side * 15, 0, z), -90, Vector3(1, 0.4 if side == -1 else 0.15, 1))
		cube(center + Vector3(side * 15.3, 0.5, 0.5), Vector3(0.5, 1, 26), Color("53443d"), true)
		for z in [-9, 9]:
			prop("Environments/Walls/SM_Env_Wall_Pillar_Large_Broken_01", center + Vector3(side * 12, 0, z), 0, Vector3.ONE * 0.6)
			cube(center + Vector3(side * 12, 0.8, z), Vector3(1.3, 1.6, 1.3), Color("393137"), true).visible = false
			brazier(center + Vector3(side * 9.5, 0.2, z), Color("ff833c"))
		prop("Environments/Misc/SM_Env_Statue_01", center + Vector3(side * 9, 0.2, -10), 0, Vector3.ONE * 0.75)
		prop("Props/SM_Prop_Wall_Banner_01", center + Vector3(side * 7.5, 2.8, -12.3), 0, Vector3.ONE * 0.7)
		for z in [-5, 3]:
			prop("Props/SM_Prop_Barrel_01", center + Vector3(side * 13.3, 0.2, z), z * 17, Vector3.ONE * 0.9)
		prop("Props/SM_Prop_Chest_01", center + Vector3(side * 11.8, 0.2, 5), 90 * side)
	for z in [-12.8, 12.8]:
		for side in [-1, 1]:
			prop("Environments/Walls/SM_Env_Wall_Pillar_Large_Broken_01", center + Vector3(side * 3.8, 0.1, z), 0, Vector3.ONE * 0.55)
			brazier(center + Vector3(side * 3.6, 0.2, z + (-1 if z > 0 else 1)), Color("53d6d0"), 0.65)
	# A brass inlaid ritual circle gives each arena a readable focal point.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.3
	torus.outer_radius = 4.4
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = center + Vector3(0, 0.22, 0)
	ring.scale.y = 0.08
	ring.material_override = mat(Color("b58e4c"), true)
	world.add_child(ring)
	prop("Environments/Floors/SM_Env_Tiles_Rune_01", center + Vector3(-2.5, 0.04, -2.5))
	if index == 1:
		for side in [-1, 1]:
			for z in [-6, 0, 6]:
				prop("Props/SM_Prop_Coffin_01", center + Vector3(side * 9, 0.2, z), 90 * side)
			prop("Props/SM_Prop_Candle_Stand_01", center + Vector3(side * 7, 0.2, 0))
	if index == 2:
		prop("Environments/Misc/SM_Env_Statue_03", center + Vector3(0, 0.2, -8), 0, Vector3.ONE * 1.4)
		brazier(center + Vector3(-3, 0.2, -7), Color("53d6d0"))
		brazier(center + Vector3(3, 0.2, -7), Color("53d6d0"))

func brazier(at: Vector3, color: Color, size := 1.0) -> void:
	prop("Props/SM_Prop_Brazier_01", at, 0, Vector3.ONE * size)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 1.1 * size, 0)
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 7 * size
	world.add_child(light)
	var particles := GPUParticles3D.new()
	particles.position = at + Vector3(0, 0.65 * size, 0)
	particles.amount = 14
	particles.lifetime = 0.7
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 6, 4))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 15
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.8
	process.gravity = Vector3(0, 0.5, 0)
	process.scale_min = 0.06 * size
	process.scale_max = 0.2 * size
	process.color = color
	particles.process_material = process
	var spark := SphereMesh.new()
	spark.radius = 0.7
	spark.height = 1.4
	spark.material = mat(color, true)
	particles.draw_pass_1 = spark
	world.add_child(particles)

func build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Knight"
	player.set_script(load("res://knight.gd"))
	player.floor_snap_length = 0.35
	var character := character_visual("Character_Hero_Knight_Female")
	player.add_child(character)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.35
	collider.shape = shape
	collider.position.y = 0.9
	player.add_child(collider)
	player.position = checkpoint
	add_child(player)
	slash = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.8
	ring.outer_radius = 2.0
	ring.rings = 24
	ring.ring_segments = 4
	slash.mesh = ring
	slash.material_override = mat(Color("ffd78a"), true)
	slash.scale.y = 0.1
	slash.visible = false
	add_child(slash)

func spawn_guardians() -> void:
	for room in range(3):
		for offset in [Vector3(-5, 0.2, -2), Vector3(5, 0.2, -4), Vector3(0, 0.2, -7)]:
			var enemy := character_visual("Character_Skeleton_Knight")
			var skeleton: Skeleton3D = enemy.get_node("GeneralSkeleton")
			for bone_name in ["LeftUpperArm", "RightUpperArm"]:
				var bone_index := skeleton.find_bone(bone_name)
				var rotation := skeleton.get_bone_pose_rotation(bone_index)
				skeleton.set_bone_pose_rotation(bone_index, rotation * Quaternion(Vector3.FORWARD, -1.15 if bone_name == "LeftUpperArm" else 1.15))
			enemy.position = ROOM_CENTERS[room] + offset
			enemy.set_meta("room", room)
			add_child(enemy)
			enemies.append(enemy)
			enemy_hp[enemy.get_instance_id()] = 2

func label(value: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.035, 0.065, 0.92)
	style.border_color = Color("9d7845")
	style.border_width_left = 3
	style.content_margin_left = 22
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	content.add_child(label("E M B E R   V A U L T", 30, Color("f1d49d")))
	room_label = label("", 16, Color("b79eb8"))
	content.add_child(room_label)
	status = label("", 19, Color("f2a888"))
	content.add_child(status)
	hint = label("WASD / ARROWS  Move     LMB / J  Sword     SPACE / SHIFT  Dash     ESC  Pause     R  Restart", 16, Color("e0caaa"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(30, -40)
	root.add_child(hint)

func strike() -> void:
	slash_left = 0.18
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if enemy.position.distance_to(player.position) < 3.0:
			var id := enemy.get_instance_id()
			enemy_hp[id] -= 1
			if enemy_hp[id] <= 0:
				enemies.remove_at(i)
				enemy_hp.erase(id)
				enemy.queue_free()
				seals += 1
			else:
				enemy.position += (enemy.position - player.position).normalized() * 1.3

func respawn() -> void:
	health -= 1
	player.position = checkpoint
	player.velocity = Vector3.ZERO
	player.invulnerable = 2

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.physical_keycode == KEY_ESCAPE and not won and not dead:
			paused = not paused
			player.enabled = not paused

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(16, zoom - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(44, zoom + 2)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	room_index = clampi(roundi(-player.position.z / 40), 0, 2)
	room_label.text = ROOM_NAMES[room_index]
	status.text = "VITALITY  " + "◆ ".repeat(maxi(health, 0)) + "    /    SEALS  %d / 9" % seals
	if paused or won or dead:
		hint.text = "PAUSED  /  Escape to continue" if paused else ("THE VAULT IS SILENT.  You escaped.  /  R to replay" if won else "YOUR EMBER FADES.  /  R to try again")
		return
	if health <= 0:
		dead = true
		player.enabled = false
		return
	camera.position = camera.position.lerp(player.position + Vector3(23, 30, 23), 1 - exp(-delta * 5))
	camera.size = lerpf(camera.size, zoom, 1 - exp(-delta * 8))
	camera.look_at(player.position + Vector3(0, 0.6, 0))
	checkpoint = ROOM_CENTERS[room_index] + Vector3(0, 0.3, 8)
	for enemy in enemies:
		if int(enemy.get_meta("room")) != room_index:
			continue
		var direction := player.position - enemy.position
		direction.y = 0
		if direction.length() > 1.0:
			enemy.position += direction.normalized() * 2.3 * delta
			enemy.rotation.y = atan2(direction.x, direction.z)
		if direction.length() < 1.4 and player.invulnerable <= 0:
			health -= 1
			player.invulnerable = 1.4
			player.position += direction.normalized() * 1.2
	slash_left = maxf(slash_left - delta, 0)
	slash.visible = slash_left > 0
	slash.position = player.position + Vector3(0, 0.7, 0)
	if seals == 9 and player.position.distance_to(Vector3(0, 0.3, -88)) < 3:
		won = true
		player.enabled = false
	if not paused:
		hint.text = "WASD  Move  /  LMB or J  Sword  /  Space  Dash    •    Defeat the guardians; claim 9 seals and reach the final statue."

func capture() -> void:
	player.enabled = false
	var directory := ProjectSettings.globalize_path("res://../../generated/previews")
	DirAccess.make_dir_recursive_absolute(directory)
	for room in range(3):
		player.position = ROOM_CENTERS[room] + Vector3(0, 0.3, 7)
		camera.position = ROOM_CENTERS[room] + Vector3(23, 30, 23)
		camera.look_at(ROOM_CENTERS[room])
		for i in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("ember-vault-%d.png" % room))
	zoom = 13
	for i in range(25):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("ember-vault-knight.png"))
	print("EMBER_VAULT_CAPTURE_OK")
	get_tree().quit()

func smoke_test() -> void:
	assert(enemies.size() == 9)
	assert(player.skeleton.find_bone("RightHand") >= 0)
	Input.action_press("right")
	var start := player.position
	for i in range(20):
		await get_tree().physics_frame
	Input.action_release("right")
	assert(player.position.distance_to(start) > 0.5)
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	assert(player.cooldown > 0)
	for i in range(9):
		player.position = enemies[0].position
		strike()
		strike()
		if enemies.is_empty():
			break
	assert(enemies.is_empty() and seals == 9)
	player.position = Vector3(0, 0.3, -88)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(won)
	print("EMBER_VAULT_SMOKE_OK: assets, sword attachment, movement, dash, combat, victory")
	get_tree().quit()

func physics_test() -> void:
	# Remove combat interference while checking the controller's floor contact.
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	assert(not player.visual is CollisionObject3D, "Imported visual must not be a physics body")
	for frame in range(120):
		await get_tree().physics_frame
		if frame % 30 == 0:
			print("PHYSICS frame=", frame, " y=", player.position.y, " velocity=", player.velocity, " floor=", player.is_on_floor())
	assert(absf(player.position.y - 0.18) < 0.1, "Idle character must settle on the floor")
	assert(player.is_on_floor(), "Idle character lost floor contact")
	# Walk and dash on every chamber and both bridges, including their seams.
	for start_z in [5.0, -20.0, -40.0, -60.0, -80.0, -12.0, -27.0, -52.0, -67.0]:
		player.position = Vector3(0, 0.4, start_z)
		player.velocity = Vector3.ZERO
		Input.action_press("forward")
		Input.action_press("right")
		for frame in range(12):
			await get_tree().physics_frame
		Input.action_press("dash")
		for frame in range(16):
			await get_tree().physics_frame
		Input.action_release("dash")
		Input.action_release("forward")
		Input.action_release("right")
		for frame in range(6):
			await get_tree().physics_frame
		assert(player.is_on_floor(), "Lost floor while traversing room/bridge")
		assert(absf(player.position.y - 0.185) < 0.1, "Unexpected vertical displacement")
	assert(health == 5, "Traversal unexpectedly triggered a fall/respawn")
	print("EMBER_VAULT_PHYSICS_OK")
	get_tree().quit()

func own_nodes(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own_nodes(child, owner_node)

func bake_map() -> void:
	own_nodes(world, world)
	var packed := PackedScene.new()
	assert(packed.pack(world) == OK)
	assert(ResourceSaver.save(packed, "res://dungeon_layout.tscn") == OK)
	print("EMBER_VAULT_BAKE_OK")
	get_tree().quit()
