class_name AssetParentSelector
extends RefCounted


static func pick_parent(root: Node3D, asset: AssetResource, auto_group: bool) -> Node3D:
	var primary_id := asset.get_primary_collection()
	if not auto_group or primary_id < 0:
		return root

	var lib := AssetLibraryManager.get_asset_library()
	if lib == null:
		return root
	var collection := lib.get_collection(primary_id)
	if collection == null:
		return root

	var expected_name: String = collection.name
	for child in root.get_children():
		if child is Node3D and child.name == expected_name:
			return child

	var group_parent := Node3D.new()
	group_parent.name = expected_name
	root.add_child(group_parent)
	group_parent.owner = EditorInterface.get_edited_scene_root()
	return group_parent
