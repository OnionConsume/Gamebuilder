import { mkdir, writeFile, copyFile, access, rm } from 'node:fs/promises';
import path from 'node:path';
import { validatePlan } from './plan.mjs';

export async function generateProject(input, output, { character } = {}) {
  const plan = validatePlan(input);
  if (character) {
    if (path.extname(character).toLowerCase() !== '.glb') throw new Error('Character must be a self-contained .glb file.');
    await access(character);
  }
  const root = path.resolve(output);
  // Exclusive directory creation prevents accidental replacement of an existing project.
  await mkdir(path.dirname(root), { recursive: true });
  await mkdir(root);
  try {
    await mkdir(path.join(root, 'assets'));
    if (character) await copyFile(character, path.join(root, 'assets', 'character.glb'));
    const config = `[application]\nconfig/name=${JSON.stringify(plan.title)}\nrun/main_scene="res://main.tscn"\n\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n`;
    const scene = `[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://game.gd" id="1"]\n\n[node name="Game" type="Node3D"]\nscript = ExtResource("1")\n`;
    await Promise.all([
      writeFile(path.join(root, 'project.godot'), config),
      writeFile(path.join(root, 'main.tscn'), scene),
      writeFile(path.join(root, 'game-plan.json'), JSON.stringify(plan, null, 2)),
      writeFile(path.join(root, 'game.gd'), gameScript(plan, Boolean(character))),
      writeFile(path.join(root, 'player.gd'), playerScript(plan)),
    ]);
    return root;
  } catch (error) {
    await rm(root, { recursive: true, force: true });
    throw error;
  }
}

function gameScript(p, hasCharacter) {
  const rgb = [1, 3, 5].map(i => parseInt(p.background.slice(i, i + 2), 16) / 255).join(', ');
  return `extends Node3D

var collected := 0
var crystals: Array[Node3D] = []
var player: CharacterBody3D
var status: Label

func _ready() -> void:
\tvar environment := WorldEnvironment.new()
\tenvironment.environment = Environment.new()
\tenvironment.environment.background_mode = Environment.BG_COLOR
\tenvironment.environment.background_color = Color(${rgb})
\tenvironment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
\tenvironment.environment.ambient_light_color = Color.WHITE
\tenvironment.environment.ambient_light_energy = 0.55
\tadd_child(environment)
\tvar sun := DirectionalLight3D.new()
\tsun.rotation_degrees = Vector3(-50, -25, 0)
\tadd_child(sun)
\tvar floor_body := StaticBody3D.new()
\tadd_child(floor_body)
\tvar floor_mesh := MeshInstance3D.new()
\tvar box := BoxMesh.new()
\tbox.size = Vector3(${p.arenaSize}, 1, ${p.arenaSize})
\tfloor_mesh.mesh = box
\tfloor_mesh.position.y = -0.5
\tfloor_body.add_child(floor_mesh)
\tvar floor_shape := CollisionShape3D.new()
\tvar shape := BoxShape3D.new()
\tshape.size = box.size
\tfloor_shape.shape = shape
\tfloor_shape.position.y = -0.5
\tfloor_body.add_child(floor_shape)
\tplayer = CharacterBody3D.new()
\tplayer.set_script(load("res://player.gd"))
\tplayer.position = Vector3(0, 2, 0)
\tvar collider := CollisionShape3D.new()
\tcollider.shape = CapsuleShape3D.new()
\tcollider.position.y = 1
\tplayer.add_child(collider)
\tvar visual: Node3D
${hasCharacter ? '\tvisual = load("res://assets/character.glb").instantiate()' : '\tvar placeholder := MeshInstance3D.new()\n\tplaceholder.mesh = CapsuleMesh.new()\n\tplaceholder.position.y = 1\n\tvisual = placeholder'}
\tvisual.name = "Visual"
\tplayer.add_child(visual)
\tvar camera := Camera3D.new()
\tcamera.position = Vector3(0, 7, 10)
\tcamera.rotation_degrees.x = -30
\tcamera.current = true
\tplayer.add_child(camera)
\tadd_child(player)
\tfor i in range(${p.collectibleCount}):
\t\tvar crystal := MeshInstance3D.new()
\t\tvar mesh := SphereMesh.new()
\t\tmesh.radius = 0.35
\t\tmesh.height = 0.7
\t\tcrystal.mesh = mesh
\t\tvar material := StandardMaterial3D.new()
\t\tmaterial.albedo_color = Color(0.3, 1.0, 0.75)
\t\tcrystal.material_override = material
\t\tvar angle := TAU * float(i) / ${p.collectibleCount}.0
\t\tvar radius := ${p.arenaSize} * (0.22 + 0.12 * float(i % 3) / 2.0)
\t\tcrystal.position = Vector3(cos(angle) * radius, 1, sin(angle) * radius)
\t\tadd_child(crystal)
\t\tcrystals.append(crystal)
\tvar ui := CanvasLayer.new()
\tadd_child(ui)
\tstatus = Label.new()
\tstatus.position = Vector2(24, 24)
\tstatus.add_theme_font_size_override("font_size", 24)
\tui.add_child(status)
\tupdate_status()

func _process(delta: float) -> void:
\tfor i in range(crystals.size() - 1, -1, -1):
\t\tvar crystal := crystals[i]
\t\tcrystal.rotate_y(delta * 2)
\t\tif crystal.position.distance_to(player.position + Vector3.UP) < 1.3:
\t\t\tcrystals.remove_at(i)
\t\t\tcrystal.queue_free()
\t\t\tcollected += 1
\t\t\tupdate_status()
\tif Input.is_physical_key_pressed(KEY_R):
\t\tget_tree().reload_current_scene()

func update_status() -> void:
\tstatus.text = "Crystals: %d / ${p.collectibleCount}\\nWASD / arrows: move | Space: jump | R: restart" % collected
\tif collected == ${p.collectibleCount}:
\t\tstatus.text += "\\nAll collected! You win."
`;
}

function playerScript(p) {
  return `extends CharacterBody3D

var animator: AnimationPlayer
var clips := {}
var jump_held := false

func _ready() -> void:
\tanimator = find_animation_player($Visual)
\tif animator:
\t\tfor clip in animator.get_animation_list():
\t\t\tfor action in ["idle", "walk", "run", "jump"]:
\t\t\t\tif action in clip.to_lower():
\t\t\t\t\tclips[action] = clip
\t\t\t\t\tif action != "jump":
\t\t\t\t\t\tanimator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func find_animation_player(node: Node) -> AnimationPlayer:
\tif node is AnimationPlayer:
\t\treturn node
\tfor child in node.get_children():
\t\tvar found := find_animation_player(child)
\t\tif found:
\t\t\treturn found
\treturn null

func _physics_process(delta: float) -> void:
\tvar direction := Vector3.ZERO
\tif Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.z -= 1
\tif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.z += 1
\tif Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
\tif Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
\tdirection = direction.normalized()
\tvelocity.x = direction.x * ${p.speed}
\tvelocity.z = direction.z * ${p.speed}
\tif not is_on_floor(): velocity.y -= 20 * delta
\tvar jump := Input.is_physical_key_pressed(KEY_SPACE)
\tif jump and not jump_held and is_on_floor(): velocity.y = ${p.jumpVelocity}
\tjump_held = jump
\tmove_and_slide()
\tif direction.length_squared() > 0:
\t\t$Visual.rotation.y = atan2(-direction.x, -direction.z)
\tvar action := "idle"
\tif not is_on_floor(): action = "jump"
\telif direction.length_squared() > 0: action = "run" if clips.has("run") else "walk"
\tif animator and clips.has(action) and animator.current_animation != clips[action]:
\t\tanimator.play(clips[action], 0.15)
\tif position.y < -20:
\t\tposition = Vector3(0, 2, 0)
\t\tvelocity = Vector3.ZERO
`;
}
