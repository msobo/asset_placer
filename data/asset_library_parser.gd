class_name AssetLibraryParser
extends RefCounted

const DEFAULT_SAVE_PATH := "user://asset_library.json"


static func load_library(load_path = DEFAULT_SAVE_PATH) -> AssetLibrary:
	var data := _load_library_data(load_path)
	if data.is_empty():
		return AssetLibrary.new([], [], [])

	var folders_dicts: Array = data["folders"]
	var assets_dicts: Array = data["assets"]
	var collections_dict: Array = data["collections"]

	var folders: Array[AssetFolder]
	var assets: Array[AssetResource]
	var collections: Array[AssetCollection]

	for folder_dict in folders_dicts:
		var folder_path = folder_dict["path"]
		var include_subfolders = folder_dict["include_subfolders"]

		var folder = AssetFolder.new(folder_path, include_subfolders)

		# Load rules from inline data
		if folder_dict.has("rules"):
			for rule_dict in folder_dict["rules"]:
				var rule = RuleFactory.from_dict(rule_dict)
				if rule:
					folder.rules.append(rule)

		folders.append(folder)

	for asset_dict in assets_dicts:
		var asset_name = asset_dict["name"]
		var id = asset_dict["id"]
		var folder_path := ""
		if asset_dict.has("folder_path"):
			folder_path = asset_dict["folder_path"]
		var dict = asset_dict as Dictionary
		var tags: Array[int] = []
		if dict.has("tags"):
			var raw_tags = dict["tags"]
			for tag in raw_tags:
				tags.append(int(tag))
		var p_collection: int = -1
		if dict.has("primary_collection"):
			p_collection = int(dict["primary_collection"])

		var date_added := 0.0
		if dict.has("date_added"):
			date_added = float(dict["date_added"])
		var asset = AssetResource.new(id, asset_name, tags, folder_path, p_collection, date_added)
		assets.append(asset)

	for collection_dict in collections_dict:
		var col_name = collection_dict["name"]
		var color_string: String = collection_dict["color"]
		var color = Color.from_string(color_string, Color.AQUA)
		var id: int = collection_dict["id"]
		collections.append(AssetCollection.new(col_name, color, id))

	return AssetLibrary.new(assets, folders, collections)


static func save_library(library: AssetLibrary, save_path = DEFAULT_SAVE_PATH) -> Error:
	assert(is_instance_valid(library), "AssetLibraryParser: Cannot save null library.")

	var assets_dict: Array[Dictionary] = []
	var folders_dict: Array[Dictionary] = []
	var collections_dict: Array[Dictionary] = []

	for folder in library.get_folders():
		# Serialize rules inline
		var rules_data: Array[Dictionary] = []
		for rule in folder.rules:
			rules_data.append(rule.to_dict())

		folders_dict.append(
			{
				"path": folder.path,
				"include_subfolders": folder.include_subfolders,
				"rules": rules_data
			}
		)

	for asset in library.get_assets():
		assets_dict.append(
			{
				"name": asset.name,
				"id": asset.id,
				"tags": asset.tags,
				"folder_path": asset.folder_path,
				"primary_collection": asset.primary_collection,
				"date_added": asset.date_added
			}
		)

	for collection in library.get_collections():
		collections_dict.append(
			{
				"name": collection.name,
				"color": collection.background_color.to_html(),
				"id": collection.id
			}
		)

	var lib_dict = {
		"assets": assets_dict,
		"folders": folders_dict,
		"collections": collections_dict,
		"version": 3
	}

	var json = JSON.stringify(lib_dict)
	var temp_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error("Asset Placer: Cannot open temporary library file: %s" % error_string(open_error))
		return open_error
	file.store_string(json)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Asset Placer: Cannot write temporary library file: %s" % error_string(write_error))
		return write_error

	var parsed_temp = JSON.parse_string(FileAccess.get_file_as_string(temp_path))
	if parsed_temp is not Dictionary:
		push_error("Asset Placer: Refusing to replace library with invalid JSON.")
		return ERR_PARSE_ERROR

	var absolute_path := ProjectSettings.globalize_path(save_path)
	var absolute_temp_path := ProjectSettings.globalize_path(temp_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.copy_absolute(absolute_path, absolute_backup_path)
		if backup_error != OK:
			push_warning(
				"Asset Placer: Could not update library backup: %s" % error_string(backup_error)
			)

	var rename_error := DirAccess.rename_absolute(absolute_temp_path, absolute_path)
	if rename_error != OK:
		push_error("Asset Placer: Cannot replace asset library: %s" % error_string(rename_error))
		return rename_error
	return OK


static func _load_library_data(load_path: String) -> Dictionary:
	var data := _read_library_data(load_path)
	if not data.is_empty():
		return data

	var backup_path := load_path + ".bak"
	var backup_data := _read_library_data(backup_path)
	if not backup_data.is_empty():
		push_warning("Asset Placer: Loading backup because the main asset library is invalid.")
		return backup_data
	return {}


static func _read_library_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_error("Asset Placer: Invalid asset library JSON at %s" % path)
		return {}
	if not parsed.has_all(["folders", "assets", "collections"]):
		push_error("Asset Placer: Incomplete asset library JSON at %s" % path)
		return {}
	return parsed
