@tool
extends Control

const OVERLAY_PALETTE_BUTTON_BASE := Vector2(48, 48)

var _error_position: Vector2
var _error_hidden_position: Vector2
var _last_palette_assets: Array[AssetResource] = []
var _placement_tool := AssetPlacerPresenter.PlacementTool.Single
var _brush_shortcut_name := "Unassigned"
var _brush_shortcut_assigned := false

@onready var rotate_check_button: CheckBox = %RotateCheckButton
@onready var scale_check_button: CheckBox = %ScaleCheckButton
@onready var translate_check_button: CheckBox = %TranslateCheckButton
@onready var x_check_button: CheckButton = %XCheckButton
@onready var z_check_button: CheckButton = %ZCheckButton
@onready var y_check_button: CheckButton = %YCheckButton
@onready var placement_mode_label: Label = %PlacementModeLabel
@onready var error_label: Label = %ErrorLabel
@onready var error_container: Container = %ErrorContainer
@onready var error_timer: Timer = %ErrorTimer
@onready var rotation_delta_container: PanelContainer = %RotationDeltaContainer
@onready var rotation_delta_label: Label = %RotationDeltaLabel
@onready var snapping_switch: CheckButton = %SnappingSwitch
@onready var placement_shortcut_label: Label = %PlacementShortcutLabel
@onready var brush_mode_label: Label = %BrushModeLabel
@onready var asset_pallete: PanelContainer = %AssetPallete
@onready var asset_pallete_presenter := AssetPalettePresenter.new()
@onready var asset_pallete_container: HBoxContainer = %PalleteContainer
@onready var active_palette_label: Label = %ActivePaletteLabel
@onready var asset_pallete_resource = preload(
	"res://addons/asset_placer/ui/asset_palette/asset_pallete_item.tscn"
)
@onready var _settings_repository := AssetPlacerSettingsRepository.instance


func _ready():
	hide()
	_error_position = error_container.position
	show_settings(_settings_repository.get_settings())
	_settings_repository.settings_changed.connect(show_settings)
	var viewport_size = get_viewport_rect().size
	_error_hidden_position = Vector2(-viewport_size.x, _error_position.y)
	error_container.position = _error_hidden_position
	var presenter = AssetPlacerPresenter.instance
	presenter.transform_mode_changed.connect(set_mode)
	presenter.preview_transform_axis_changed.connect(set_axis)
	presenter.placer_active.connect(_set_overlay_visible)
	presenter.placement_mode_changed.connect(set_placement_mode)
	presenter.placement_tool_changed.connect(set_placement_tool)
	presenter.options_changed.connect(show_options)
	presenter.ready()
	presenter.show_error.connect(show_error)
	error_timer.timeout.connect(hide_error)
	set_mode(presenter.transform_mode)
	set_axis(presenter.preview_transform_axis)
	set_placement_tool(presenter.placement_tool)

	asset_pallete_presenter.palette_change.connect(show_asset_pallete)
	asset_pallete_presenter.ready(0)

	AssetPaletteSessionState.instance.active_palette_index_changed.connect(
		func():
			var index = AssetPaletteSessionState.instance.get_active_palette_index()
			asset_pallete_presenter.set_palette_index(index)
			_update_active_palette_label(index)
	)
	if AssetPaletteSessionState.instance:
		_update_active_palette_label(AssetPaletteSessionState.instance.get_active_palette_index())


func show_asset_pallete(assets: Array[AssetResource]):
	_last_palette_assets = assets.duplicate()
	if assets.all(func(a): return a == null):
		asset_pallete.hide()
	else:
		asset_pallete.show()

	for child in asset_pallete_container.get_children():
		child.queue_free()
	var palette_scale := _settings_repository.get_settings().palette_item_scale
	for index in range(assets.size()):
		var asset = assets[index]
		if asset:
			var asset_instance = asset_pallete_resource.instantiate() as AssetPalletItem
			asset_pallete_container.add_child(asset_instance)
			asset_instance.button_size = OVERLAY_PALETTE_BUTTON_BASE * palette_scale
			asset_instance.set_asset(asset)
			asset_instance.configurable = false
			asset_instance.set_index(index)


func _update_active_palette_label(index: int) -> void:
	active_palette_label.text = "Palette #%d" % [index + 1]


func set_mode(mode: AssetPlacerPresenter.TransformMode):
	rotate_check_button.button_pressed = mode == AssetPlacerPresenter.TransformMode.Rotate
	scale_check_button.button_pressed = mode == AssetPlacerPresenter.TransformMode.Scale
	translate_check_button.button_pressed = mode == AssetPlacerPresenter.TransformMode.Move


func set_placement_mode(mode: GapPlacementMode):
	if mode is GapPlacementMode.PlanePlacement:
		placement_mode_label.text = "Plane Placement"
	if mode is GapPlacementMode.SurfacePlacement:
		placement_mode_label.text = "Surface Placement"
	if mode is GapPlacementMode.Terrain3DPlacement:
		placement_mode_label.text = "Terrain3D Placement"


func set_placement_tool(tool: AssetPlacerPresenter.PlacementTool):
	_placement_tool = tool
	_update_brush_hint()


func _update_brush_hint():
	if _placement_tool == AssetPlacerPresenter.PlacementTool.Brush:
		brush_mode_label.text = (
			"%s: Brush · Spacing: Grid Step U/V · Auto Grid may override" % _brush_shortcut_name
			if _brush_shortcut_assigned
			else "Brush active · Spacing: Grid Step U/V · Auto Grid may override"
		)
	else:
		brush_mode_label.text = "Grid Brush shortcut: %s" % _brush_shortcut_name
	brush_mode_label.show()


func show_error(message: String):
	var tween = create_tween()
	tween.tween_property(error_container, "position", _error_position, 0.3)
	error_label.text = message
	error_timer.start()


func hide_error():
	var tween = create_tween()
	tween.tween_property(error_container, "position", _error_hidden_position, 0.3)


func show_settings(settings: AssetPlacerSettings):
	if not _last_palette_assets.is_empty():
		show_asset_pallete(_last_palette_assets)
	var rotate_hint := "To Rotate"
	if settings.drag_to_rotate_enabled:
		rotate_hint += " · Alt+LMB Drag"
	rotate_check_button.text = "%s: %s" % [
		settings.bindings[AssetPlacerSettings.Bindings.Rotate].get_display_name(), rotate_hint
	]
	scale_check_button.text = (
		"%s: To Scale" % settings.bindings[AssetPlacerSettings.Bindings.Scale].get_display_name()
	)
	translate_check_button.text = (
		"%s: To Translate"
		% settings.bindings[AssetPlacerSettings.Bindings.Translate].get_display_name()
	)
	snapping_switch.text = (
		"%s: Grid Snapping"
		% settings.bindings[AssetPlacerSettings.Bindings.GridSnapping].get_display_name()
	)
	placement_shortcut_label.text = (
		"(%s)" % settings.bindings[AssetPlacerSettings.Bindings.TogglePlaneMode].get_display_name()
	)
	var brush_binding: APInputOption = settings.bindings[AssetPlacerSettings.Bindings.ToggleBrush]
	_brush_shortcut_name = brush_binding.get_display_name()
	_brush_shortcut_assigned = not brush_binding.equals(APInputOption.none())
	_update_brush_hint()


func show_options(options: AssetPlacerOptions):
	snapping_switch.button_pressed = options.snapping_enabled


func set_axis(vector: Vector3):
	x_check_button.button_pressed = vector.x == 1
	y_check_button.button_pressed = vector.y == 1
	z_check_button.button_pressed = vector.z == 1


func show_rotation_delta(camera: Camera3D, world_position: Vector3, degrees: float):
	if not is_instance_valid(camera) or camera.is_position_behind(world_position):
		rotation_delta_container.hide()
		return
	if absf(degrees) < 0.05:
		degrees = 0.0
	var prefix := "+" if degrees >= 0.0 else ""
	rotation_delta_label.text = "%s%.1f°" % [prefix, degrees]
	rotation_delta_container.reset_size()
	var screen_position := camera.unproject_position(world_position)
	var label_size := rotation_delta_container.size
	var target := screen_position + Vector2(-label_size.x * 0.5, -label_size.y - 24.0)
	var max_position := (size - label_size).max(Vector2.ZERO)
	rotation_delta_container.position = target.clamp(Vector2.ZERO, max_position)
	rotation_delta_container.show()


func hide_rotation_delta():
	rotation_delta_container.hide()


func _set_overlay_visible(visible: bool):
	self.visible = visible
	if not visible:
		hide_rotation_delta()
