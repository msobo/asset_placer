class_name Synchronize
extends RefCounted

signal sync_state_change(running: bool)
signal sync_complete(added: int, removed: int, scanned: int)

## A resource may briefly disappear from ResourceUID while Godot reimports it.
## Requiring multiple failed scans prevents a transient import state from erasing metadata.
const MISSING_SCANS_BEFORE_REMOVAL := 2

static var instance: Synchronize

var sync_running = false:
	set(value):
		sync_running = value
		call_deferred("emit_signal", "sync_state_change", value)

var _added = 0
var _removed = 0
var _scanned = 0
var _missing_scan_counts: Dictionary[String, int] = {}


func _init():
	instance = self


func sync_all():
	if sync_running:
		push_error("Sync is already running")
		return

	AssetPlacerAsync.instance.enqueue(
		func():
			sync_running = true
			_sync_all()
			_notify_scan_complete()
			sync_running = false
	)


func sync_folder(folder: AssetFolder):
	if sync_running:
		push_error("Sync is already running")
		return

	AssetPlacerAsync.instance.enqueue(
		func():
			sync_running = true
			_sync_folder(folder)
			_notify_scan_complete()
			sync_running = false
	)


func _sync_folder(folder: AssetFolder):
	_update_assets()
	add_assets_from_folder(folder)


func _sync_all():
	_update_assets()
	for folder in AssetLibraryManager.get_asset_library().get_folders():
		add_assets_from_folder(folder)


func add_assets_from_folder(folder: AssetFolder, override_path := ""):
	var folder_path := folder.path if override_path.is_empty() else override_path
	var lib := AssetLibraryManager.get_asset_library()
	var dir := DirAccess.open(folder_path)
	if not dir:
		push_warning("Could not open folder: %s" % folder_path)
		return

	for file in dir.get_files():
		_scanned += 1
		if not AssetResource.is_file_supported(file) or not folder.name_passes_filters(file):
			continue

		var uid = ResourceIdCompat.path_to_uid(folder_path.path_join(file))
		if not lib.has_asset_id(uid):
			var asset := AssetResource.new(
				uid, file, [], folder_path, -1, Time.get_unix_time_from_system()
			)
			for rule in folder.get_rules():
				asset = rule.do_after_asset_added(asset)
			if lib.add_asset(asset):
				_added += 1

	if folder.include_subfolders:
		for sub_dir in dir.get_directories():
			var path: String = folder_path.path_join(sub_dir)
			add_assets_from_folder(folder, path)


func _notify_scan_complete():
	call_deferred("emit_signal", "sync_complete", _added, _removed, _scanned)
	if _added != 0 || _removed != 0:
		# Since Synchronize can run on another thread we need to assure UI has latest updates.
		AssetLibraryManager.get_asset_library()._queue_emit_assets_changed.call_deferred()
	_clear_data()


func _update_assets():
	var lib := AssetLibraryManager.get_asset_library()
	var assets: Array[AssetResource] = lib.get_assets().duplicate()
	for asset in assets:
		var previous_id := asset.id
		_refresh_asset_identity(asset, lib)
		if not _is_asset_valid(asset):
			var missing_key := previous_id
			var missing_count: int = int(_missing_scan_counts.get(missing_key, 0)) + 1
			_missing_scan_counts[missing_key] = missing_count
			if missing_count >= MISSING_SCANS_BEFORE_REMOVAL:
				_removed += 1
				lib.remove_asset(asset)
				_missing_scan_counts.erase(missing_key)
			continue

		_missing_scan_counts.erase(previous_id)
		_missing_scan_counts.erase(asset.id)
		for folder in lib.get_folders():
			if folder.has_asset(asset):
				for rule in folder.get_rules():
					asset = rule.do_after_asset_added(asset)
		lib.update_asset(asset)


func _refresh_asset_identity(asset: AssetResource, lib: AssetLibrary):
	var source_path := asset.get_path()
	if source_path.is_empty():
		var fallback_path := asset.get_fallback_path()
		if ResourceLoader.exists(fallback_path):
			source_path = fallback_path
	if source_path.is_empty():
		return

	var current_id: String = ResourceIdCompat.path_to_uid(source_path)
	if current_id.is_empty():
		current_id = source_path
	if current_id != asset.id:
		var existing_asset := lib.get_asset(current_id)
		if existing_asset:
			existing_asset.add_tags(asset.tags)
			if existing_asset.primary_collection < 0:
				existing_asset.primary_collection = asset.primary_collection
			lib.update_asset(existing_asset)
		else:
			asset.id = current_id
	asset.name = source_path.get_file()
	asset.folder_path = source_path.get_base_dir()


func _is_asset_valid(asset: AssetResource) -> bool:
	var lib := AssetLibraryManager.get_asset_library()
	return asset.has_resource() and lib.asset_has_folder(asset)


func _clear_data():
	_removed = 0
	_added = 0
	_scanned = 0
