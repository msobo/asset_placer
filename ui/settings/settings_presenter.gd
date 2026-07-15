class_name SettingsPresenter
extends RefCounted

signal show_settings(settings: AssetPlacerSettings)

var _repository: AssetPlacerSettingsRepository


func _init():
	_repository = AssetPlacerSettingsRepository.instance


func ready():
	show_settings.emit(_repository.get_settings())
	_repository.settings_changed.connect(show_settings.emit)


func reset_to_defaults():
	var default = AssetPlacerSettings.default()
	# keep path
	default.asset_library_path = _repository.get_settings().asset_library_path
	_repository.set_settings(AssetPlacerSettings.default())


func set_asset_library_path(path: String):
	var settings = _repository.get_settings()
	settings.asset_library_path = path
	_repository.set_settings(settings)

	AssetLibraryManager.update_save_path(path)
	ProjectSettings.save()


func set_default_transform_step(value: float):
	var settings = _repository.get_settings()
	settings.transform_step = value
	_repository.set_settings(settings)


func set_plane_placement_step(value: float):
	var settings = _repository.get_settings()
	settings.plane_placement_step = value
	_repository.set_settings(settings)


func set_ui_scale(value: float):
	var settings = _repository.get_settings()
	settings.ui_scale = value
	_repository.set_settings(settings)


func set_palette_item_scale(value: float):
	var settings = _repository.get_settings()
	settings.palette_item_scale = value
	_repository.set_settings(settings)


func set_rotation_step(value: float):
	var settings = _repository.get_settings()
	settings.rotation_step = value
	_repository.set_settings(settings)


func set_drag_to_rotate_enabled(value: bool):
	var settings = _repository.get_settings()
	settings.drag_to_rotate_enabled = value
	_repository.set_settings(settings)


func set_drag_rotation_sensitivity(value: float):
	var settings = _repository.get_settings()
	settings.drag_rotation_sensitivity = value
	_repository.set_settings(settings)


func set_auto_grid_enabled(value: bool):
	var settings = _repository.get_settings()
	settings.auto_grid_enabled = value
	_repository.set_settings(settings)


func set_auto_grid_step_component(
	value: float, surface: AssetPlacerSettings.AutoGridSurface, axis: int
):
	var settings = _repository.get_settings()
	var step: Vector2
	match surface:
		AssetPlacerSettings.AutoGridSurface.Wall:
			step = settings.auto_grid_wall_step
		AssetPlacerSettings.AutoGridSurface.Floor:
			step = settings.auto_grid_floor_step
		AssetPlacerSettings.AutoGridSurface.Ceiling:
			step = settings.auto_grid_ceiling_step
		_:
			return
	step[axis] = value
	match surface:
		AssetPlacerSettings.AutoGridSurface.Wall:
			settings.auto_grid_wall_step = step
		AssetPlacerSettings.AutoGridSurface.Floor:
			settings.auto_grid_floor_step = step
		AssetPlacerSettings.AutoGridSurface.Ceiling:
			settings.auto_grid_ceiling_step = step
	_repository.set_settings(settings)


func set_preview_material(material: String):
	if material.is_empty():
		return
	var current = _repository.get_settings()
	current.preview_material_resource = material
	_repository.set_settings(current)

	ProjectSettings.save()


func set_plane_material(material: String):
	if material.is_empty():
		return
	var current = _repository.get_settings()
	current.plane_material_resource = material
	_repository.set_settings(current)

	ProjectSettings.save()


func clear_preivew_material():
	var current = _repository.get_settings()
	current.preview_material_resource = ""
	_repository.set_settings(current)


func set_rotate_binding(key: APInputOption):
	var current = _repository.get_settings()
	current.binding_rotate = key
	_repository.set_settings(current)


func set_grid_snap_binding(key: APInputOption):
	var current = _repository.get_settings()
	current.binding_grid_snap = key
	_repository.set_settings(current)


func set_scale_binding(key: APInputOption):
	var current = _repository.get_settings()
	current.binding_scale = key
	_repository.set_settings(current)


func set_binding_in_place_transform(key: APInputOption):
	var current = _repository.get_settings()
	current.binding_in_place_transform = key
	_repository.set_settings(current)


func set_binding(input: APInputOption, key: AssetPlacerSettings.Bindings):
	var current_settings = _repository.get_settings()
	current_settings.bindings[key] = input
	_repository.set_settings(current_settings)


func start_thumbnail_regeneration() -> bool:
	var coordinator := ThumbnailGenerationCoordinator.instance
	if not is_instance_valid(coordinator):
		return false
	if coordinator.is_running():
		return false
	return coordinator.start_regeneration([], true)


func set_translate_binding(key: APInputOption):
	var current = _repository.get_settings()
	current.binding_translate = key
	_repository.set_settings(current)
