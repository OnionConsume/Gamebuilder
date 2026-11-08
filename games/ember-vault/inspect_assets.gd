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
	quit()

func report(node: Node) -> void:
	if node is MeshInstance3D and node.visible:
		print("MESH ", node.name, " ", node.get_aabb(), " TRANSFORM ", node.transform)
	if node is AnimationPlayer:
		print("ANIMATIONS ", node.get_animation_list())
	for child in node.get_children():
		report(child)
