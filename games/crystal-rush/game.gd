# SPDX-License-Identifier: GPL-3.0-only
extends Node3D

const TOTAL := 12
const PLAYER_SCRIPT = preload("res://player.gd")
var player: CharacterBody3D
var camera: Camera3D
var portal: Node3D
var arena: Node3D
var crystals: Array[Node3D] = []
var enemies: Array[Node3D] = []
var collected := 0
var health := 3
var elapsed := 0.0
var state := "title"
var paused := false
var score_label: Label
var health_label: Label
var time_label: Label
var dash_bar: ProgressBar
var objective: Label
var overlay: PanelContainer
var headline: Label
var message: Label
var button: Button

func _ready() -> void:
	setup_inputs()
	build_world()
	build_ui()
	reset_run()
	show_overlay("CRYSTAL RUSH", "Recover 12 energy crystals. Return to the central beacon.\nSentinels hunt you. Dash through them to destroy them.\n\nWASD / arrows  •  Move     Space  •  Jump     Shift  •  Dash\nEscape  •  Pause     R  •  Restart", "START EXPEDITION")
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")

func setup_inputs() -> void:
	var bindings := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "dash": [KEY_SHIFT]}
	for action in bindings:
		InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func material(color: Color, glow := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.65
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.5
	return result

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = at
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = size
		collision.shape = collider
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("080f20")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a4c5ed")
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("bbd6ff")
	sun.shadow_enabled = true
	add_child(sun)
	box(self, Vector3(0, -0.5, 0), Vector3(44, 1, 44), Color("17263c"), true)
	for i in range(-10, 11):
		box(self, Vector3(i * 2, 0.012, 0), Vector3(0.025, 0.02, 44), Color("233a51"))
		box(self, Vector3(0, 0.012, i * 2), Vector3(44, 0.02, 0.025), Color("233a51"))
	for edge in [-22, 22]:
		box(self, Vector3(edge, 0.3, 0), Vector3(0.25, 0.6, 44), Color("49dec1"))
		box(self, Vector3(0, 0.3, edge), Vector3(44, 0.6, 0.25), Color("49dec1"))
	for x in [-17, 17]:
		for z in [-17, 17]:
			box(self, Vector3(x, 1.5, z), Vector3(1, 3, 1), Color("334e69"), true)
			box(self, Vector3(x, 3.05, z), Vector3(1.1, 0.15, 1.1), Color("49dec1"))
	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	var visual := Node3D.new()
	player.add_child(visual)
	player.visual = visual
	var body_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.8
	body_mesh.mesh = body
	body_mesh.position.y = 0.9
	body_mesh.material_override = material(Color("d2f3ff"))
	visual.add_child(body_mesh)
	box(visual, Vector3(0, 1.25, -0.37), Vector3(0.55, 0.22, 0.18), Color("42e8cd"))
	add_child(player)
	camera = Camera3D.new()
	camera.position = Vector3(0, 23, 22)
	camera.fov = 60
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	portal = Node3D.new()
	add_child(portal)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.8
	ring.mesh = torus
	ring.position.y = 0.08
	ring.material_override = material(Color("6e7eae"), true)
	portal.add_child(ring)

func text_label(value: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := VBoxContainer.new()
	top.position = Vector2(32, 24)
	root.add_child(top)
	top.add_child(text_label("GAMEWRIGHT  /  FIELD TEST 001", 16, Color("52dfc4")))
	top.add_child(text_label("CRYSTAL RUSH", 30))
	score_label = text_label("", 22)
	top.add_child(score_label)
	health_label = text_label("", 20, Color("ff9c9c"))
	top.add_child(health_label)
	time_label = text_label("", 18, Color("b7c6da"))
	top.add_child(time_label)
	top.add_child(text_label("DASH", 14, Color("52dfc4")))
	dash_bar = ProgressBar.new()
	dash_bar.custom_minimum_size = Vector2(200, 10)
	dash_bar.show_percentage = false
	top.add_child(dash_bar)
	objective = text_label("", 20, Color("52dfc4"))
	objective.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	objective.position = Vector2(32, -70)
	root.add_child(objective)
	var controls := text_label("WASD MOVE   /   SPACE JUMP   /   SHIFT DASH   /   ESC PAUSE", 15, Color("a7b6cc"))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(32, -38)
	root.add_child(controls)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	overlay = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.1, 0.97)
	style.border_color = Color("3fb9a7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	overlay.add_theme_stylebox_override("panel", style)
	center.add_child(overlay)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	overlay.add_child(content)
	headline = text_label("", 40, Color("52dfc4"))
	content.add_child(headline)
	message = text_label("", 18, Color("d2ddec"))
	content.add_child(message)
	button = Button.new()
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(on_button)
	content.add_child(button)

func reset_run() -> void:
	if arena:
		remove_child(arena)
		arena.queue_free()
	arena = Node3D.new()
	add_child(arena)
	crystals.clear()
	enemies.clear()
	collected = 0
	health = 3
	elapsed = 0
	paused = false
	player.position = Vector3(0, 0.1, 0)
	camera.position = Vector3(0, 23, 22)
	camera.look_at(Vector3.ZERO)
	player.velocity = Vector3.ZERO
	player.dash_time = 0
	player.dash_cooldown = 0
	player.invulnerable = 0
	player.visual.visible = true
	portal.get_child(0).material_override = material(Color("6e7eae"), true)
	player.enabled = false
	for i in range(TOTAL):
		var crystal := MeshInstance3D.new()
		var gem := PrismMesh.new()
		gem.size = Vector3(0.75, 1.3, 0.75)
		crystal.mesh = gem
		crystal.material_override = material(Color("42f5cb"), true)
		var angle := TAU * i / TOTAL
		var radius := 11.0 if i % 2 == 0 else 18.0
		crystal.position = Vector3(cos(angle) * radius, 1.1, sin(angle) * radius)
		arena.add_child(crystal)
		crystals.append(crystal)
	for i in range(5):
		spawn_enemy(TAU * i / 5.0)
	update_hud()

func spawn_enemy(angle: float) -> void:
	var enemy := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.3
	enemy.mesh = sphere
	enemy.material_override = material(Color("ff587e"), true)
	enemy.position = Vector3(cos(angle) * 20, 0.8, sin(angle) * 20)
	arena.add_child(enemy)
	enemies.append(enemy)

func on_button() -> void:
	if paused:
		paused = false
	else:
		reset_run()
		state = "playing"
	player.enabled = true
	overlay.hide()

func show_overlay(title: String, detail: String, action: String) -> void:
	headline.text = title
	message.text = detail
	button.text = action
	overlay.show()
	button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			paused = false
			on_button()
		elif event.physical_keycode == KEY_ESCAPE and state == "playing":
			if paused:
				on_button()
			else:
				paused = true
				player.enabled = false
				show_overlay("TAKE A BREATHER", "Expedition paused. Your crystals are safe.", "RESUME")

func _physics_process(delta: float) -> void:
	if state != "playing" or paused:
		return
	elapsed += delta
	for i in range(crystals.size() - 1, -1, -1):
		var crystal := crystals[i]
		crystal.rotate_y(delta * 1.8)
		crystal.position.y = 1.1 + sin(elapsed * 2.4 + i) * 0.18
		if crystal.position.distance_to(player.position + Vector3.UP) < 1.3:
			collect_crystal(i)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		var direction := player.position - enemy.position
		direction.y = 0
		enemy.position += direction.normalized() * (2.4 + collected * 0.09) * delta
		enemy.position.y = 0.85 + sin(elapsed * 4 + i) * 0.15
		if enemy.position.distance_to(player.position + Vector3.UP) < 1.2:
			if player.dash_time > 0:
				enemies.remove_at(i)
				enemy.queue_free()
			elif player.invulnerable <= 0:
				take_damage()
				if state != "playing":
					return
	if collected == TOTAL:
		portal.rotation.y += delta
		if Vector2(player.position.x, player.position.z).length() < 1.8:
			finish(true)
	camera.position = camera.position.lerp(player.position + Vector3(0, 23, 22), delta * 3)
	camera.look_at(player.position + Vector3(0, 0.5, 0))
	update_hud()

func collect_crystal(index: int) -> void:
	crystals[index].queue_free()
	crystals.remove_at(index)
	collected += 1
	if collected == TOTAL:
		portal.get_child(0).material_override = material(Color("42f5cb"), true)

func take_damage() -> void:
	health -= 1
	player.invulnerable = 1.5
	if health <= 0:
		finish(false)

func finish(won: bool) -> void:
	state = "won" if won else "lost"
	player.enabled = false
	update_hud()
	if won:
		show_overlay("EXTRACTION COMPLETE", "All 12 crystals recovered in %.1f seconds.\nYour expedition made it home." % elapsed, "PLAY AGAIN")
	else:
		show_overlay("SIGNAL LOST", "Recovered %d / 12 crystals.\nKeep moving and use your dash to clear sentinels." % collected, "TRY AGAIN")

func update_hud() -> void:
	score_label.text = "ENERGY   %02d / %02d" % [collected, TOTAL]
	health_label.text = "SHIELDS   " + "● ".repeat(maxi(health, 0))
	time_label.text = "EXPEDITION   %05.1fs" % elapsed
	dash_bar.value = (1.0 - player.dash_cooldown / 1.2) * 100
	objective.text = "RETURN TO THE CENTRAL BEACON" if collected == TOTAL else "RECOVER CRYSTALS  •  DASH THROUGH SENTINELS"

func smoke_test() -> void:
	on_button()
	assert(state == "playing" and crystals.size() == TOTAL and enemies.size() == 5)
	Input.action_press("right")
	for i in range(15):
		await get_tree().physics_frame
	Input.action_release("right")
	assert(player.position.x > 0.5, "Player movement failed")
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	assert(player.dash_cooldown > 0, "Dash failed")
	var enemy_count := enemies.size()
	enemies[0].position = player.position + Vector3.UP
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(enemies.size() < enemy_count, "Dash combat failed")
	for i in range(TOTAL):
		collect_crystal(0)
	player.position = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(state == "won", "Extraction failed")
	on_button()
	assert(health == 3 and collected == 0 and enemies.size() == 5)
	for i in range(3):
		take_damage()
	assert(state == "lost", "Lose state failed")
	on_button()
	assert(state == "playing" and health == 3)
	print("CRYSTAL_RUSH_SMOKE_OK: movement, dash, combat, collection, extraction, defeat, restart")
	get_tree().quit()

func capture_preview() -> void:
	var directory := ProjectSettings.globalize_path("res://../../generated/previews")
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("crystal-rush-title.png"))
	on_button()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("crystal-rush-game.png"))
	print("CRYSTAL_RUSH_CAPTURE_OK")
	get_tree().quit()
