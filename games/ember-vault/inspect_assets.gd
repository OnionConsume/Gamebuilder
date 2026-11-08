# SPDX-License-Identifier: GPL-3.0-only
extends SceneTree

func _initialize() -> void:
	var base := "res://Assets/PolygonDungeon/Prefabs/"
	for item in ["Environments/Floors/SM_Env_Tiles_01", "Environments/Walls/SM_Env_Wall_01", "Environments/Walls/SM_Env_Wall_Pillar_Large_Broken_01", "Props/SM_Prop_Brazier_01", "Weapons/SM_Wep_Straightsword_01", "Characters/Character_Hero_Knight_Female"]:
		var packed = load(base + item + ".tscn")
		if packed == null:
			continue
		var node = packed.instantiate()
		root.add_child(node)
		print("ASSET ", item)
		report(node)
		node.free()
	if ResourceLoader.exists("res://Assets/worker.glb"):
		var worker = load("res://Assets/worker.glb").instantiate()
		root.add_child(worker)
		report(worker)
		worker.free()
	quit()

func report(node: Node) -> void:
	if node is Node3D and not node is MeshInstance3D:
		print("NODE ", node.get_path(), " ", node.transform)
	if node is Skeleton3D:
		for i in range(node.get_bone_count()):
			print("BONE ", i, " ", node.get_bone_name(i), " REST ", node.get_bone_rest(i))
	if node is MeshInstance3D and node.visible:
		print("MESH ", node.name, " ", node.get_aabb(), " TRANSFORM ", node.transform)
	if node is AnimationPlayer:
		print("ANIMATIONS ", node.get_animation_list())
		if node.has_animation("Running"):
			var animation: Animation = node.get_animation("Running")
			for track in range(animation.get_track_count()):
				if animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
					print("TRACK ", animation.track_get_path(track), " ", animation.track_get_key_value(track, 0), " -> ", animation.track_get_key_value(track, animation.track_get_key_count(track) - 1))
	for child in node.get_children():
		report(child)
