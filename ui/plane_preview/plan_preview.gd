@tool
extends Node3D

const GRID_CELLS_PER_TEXTURE := 8.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready():
	var presenter := AssetPlacerPresenter.instance
	var mode = AssetPlacerPresenter.instance.placement_mode
	var settings_repository := AssetPlacerSettingsRepository.instance
	_set_plane_material(settings_repository.get_settings(), presenter.options.snapping_grid_step)
	settings_repository.settings_changed.connect(
		func(settings): _set_plane_material(settings, presenter.options.snapping_grid_step)
	)
	presenter.options_changed.connect(
		func(options):
			_set_plane_material(settings_repository.get_settings(), options.snapping_grid_step)
	)

	_react_placement_mode_change(mode)
	presenter.placement_mode_changed.connect(_react_placement_mode_change)
	presenter.asset_deselected.connect(func(): hide())

	presenter.asset_selected.connect(
		func(a):
			if presenter.placement_mode is GapPlacementMode.PlanePlacement:
				show()
	)


func _set_plane_material(settings: AssetPlacerSettings, grid_step: Vector2):
	var source_material: Material = load(settings.plane_material_resource)
	if source_material == null:
		mesh_instance.set_surface_override_material(0, null)
		return

	var material := source_material.duplicate() as Material
	if material is BaseMaterial3D:
		if settings.plane_material_resource == AssetPlacerSettings.DEFAULT_PLANE_MATERIAL:
			var plane_size := 200.0
			if mesh_instance.mesh is PlaneMesh:
				plane_size = (mesh_instance.mesh as PlaneMesh).size.x
			var repeats := Vector2(
				plane_size / (grid_step.x * GRID_CELLS_PER_TEXTURE),
				plane_size / (grid_step.y * GRID_CELLS_PER_TEXTURE)
			)
			material.uv1_scale = Vector3(repeats.x, repeats.y, 1.0)
		else:
			material.uv1_scale = Vector3(
				material.uv1_scale.x / grid_step.x,
				material.uv1_scale.y / grid_step.y,
				material.uv1_scale.z
			)
	mesh_instance.set_surface_override_material(0, material)


func _react_placement_mode_change(placement_mode: GapPlacementMode):
	if placement_mode is GapPlacementMode.PlanePlacement:
		show()
		_update_mes_per_plane_configuration(placement_mode.plane_options)
	else:
		hide()


func _update_mes_per_plane_configuration(plane_options: PlaneOptions):
	var normal := plane_options.normal.normalized()
	var axes := PlaneGrid.get_axes(normal)
	var tangent: Vector3 = axes[0]
	var bitangent: Vector3 = axes[1]
	var basis := Basis(tangent, normal, -bitangent)
	mesh_instance.transform.basis = basis.orthonormalized()
	mesh_instance.global_transform = Transform3D(basis.orthonormalized(), plane_options.origin)
