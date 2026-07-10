class_name AssetPlacer
extends RefCounted

const META_ASSET_ID = &"asset_placer_res_id"
const META_BRUSH_ANCHOR = &"asset_placer_brush_anchor"
const META_BRUSH_NORMAL = &"asset_placer_brush_normal"

enum BrushStrokeMode { Freehand, Line, RectangleFill }

var preview_node: Node3D
var preview_aabb: AABB
var preview_rids = []
var asset: AssetResource
var preview_transform_step: float = 0.1
var plane_placement_step: float = 0.2
var preview_rotate_step: float = 5
var undo_redo: EditorUndoRedoManager
var preview_material = load("res://addons/asset_placer/utils/preview_material.tres")

var _last_placement_anchor := Vector3.ZERO
var _preview_root: Node
var _brush_preview: MeshInstance3D
var _brush_active := false
var _brush_mode := BrushStrokeMode.Freehand
var _brush_start_cell := Vector2i.ZERO
var _brush_last_cell := Vector2i.ZERO
var _brush_cells: Dictionary = {}
var _brush_plane_options: PlaneOptions
var _brush_grid_step := 1.0
var _brush_start_anchor := Vector3.ZERO
var _brush_transform := Transform3D.IDENTITY
var _brush_asset: AssetResource

var _is_node_transform_mode: bool = false
var _original_transform: Transform3D
var _strategy: AssetPlacementStrategy
var _presenter: AssetPlacerPresenter:
	get:
		return AssetPlacerPresenter.instance


func _init(undo_redo: EditorUndoRedoManager):
	self.undo_redo = undo_redo


func start_placement(root: Window, asset: AssetResource, placement: GapPlacementMode):
	stop_placement()
	_preview_root = root
	self.asset = asset
	_is_node_transform_mode = false
	preview_node = _instantiate_asset_resource(asset)
	root.add_child(preview_node)
	preview_rids = get_collision_rids(preview_node)
	set_placement_mode(placement)
	_apply_preview_material(preview_node)
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is Node3D and _presenter != null:
		AssetTransformations.apply_transforms(preview_node, _presenter.options)
	self.preview_aabb = AABBProvider.provide_aabb(preview_node)


func start_node_transform(node: Node3D, placement: GapPlacementMode):
	stop_placement()
	_is_node_transform_mode = true
	preview_node = node
	_original_transform = node.global_transform
	preview_rids = get_collision_rids(preview_node)
	set_placement_mode(placement)
	self.preview_aabb = AABBProvider.provide_aabb(preview_node)


func _apply_preview_material(node: Node3D):
	if not preview_material:
		return
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, preview_material)

	for child in node.get_children():
		if child is MeshInstance3D:
			for i in child.get_surface_override_material_count():
				child.set_surface_override_material(i, preview_material)
		_apply_preview_material(child)


func move_preview(mouse_position: Vector2, camera: Camera3D) -> bool:
	if preview_node and _presenter != null:
		var hit = _strategy.get_placement_point(camera, mouse_position)
		if not hit.valid:
			return false
		var normal = Vector3.UP
		if _presenter.options.align_normals:
			normal = hit.normal
		var snap_normal: Vector3 = normal
		if _strategy is PlanePlacementStrategy:
			snap_normal = _strategy.plane_options.normal

		var snapped_pos = _snap_position(hit.position, snap_normal)
		_last_placement_anchor = snapped_pos
		# Use snapped position to get correct height of terrain.
		if _strategy is Terrain3DAssetPlacementStrategy:
			snapped_pos.y = _strategy.terrain_3d_node.data.get_height(snapped_pos)

		var forward_hint = preview_node.global_transform.basis.z

		var new_basis = get_safe_basis(normal, forward_hint).scaled(preview_node.scale)
		var new_transform = Transform3D(new_basis, snapped_pos)

		var local_bottom = Vector3(0, preview_aabb.position.y, 0)

		if _presenter.options.use_asset_origin:
			local_bottom = Vector3.ZERO

		var bottom_world = new_transform * local_bottom
		var adjust = snapped_pos - bottom_world
		new_transform.origin += adjust
		preview_node.global_transform = new_transform

		return true
	else:
		return false


func place_asset(focus_on_placement: bool):
	if preview_node and _presenter != null:
		if _is_node_transform_mode:
			_confirm_node_transform()
			return true
		else:
			_place_instance(preview_node.global_transform, focus_on_placement)
			return true
	else:
		return false


func begin_brush_stroke(mouse_position: Vector2, camera: Camera3D, mode: BrushStrokeMode) -> bool:
	if preview_node == null or _presenter == null:
		return false
	if _presenter.placement_mode is not GapPlacementMode.PlanePlacement:
		return false
	if not _presenter.options.snapping_enabled or not move_preview(mouse_position, camera):
		return false

	var source: PlaneOptions = _presenter.placement_mode.plane_options
	_brush_plane_options = PlaneOptions.new(source.normal, source.origin)
	_brush_grid_step = _presenter.options.snapping_grid_step
	_brush_mode = mode
	_brush_start_cell = PlaneGrid.world_to_cell(
		_last_placement_anchor, _brush_plane_options.normal, _brush_grid_step
	)
	_brush_last_cell = _brush_start_cell
	_brush_start_anchor = PlaneGrid.cell_to_world(
		_brush_start_cell, _brush_plane_options, _brush_grid_step
	)
	_brush_transform = preview_node.global_transform
	_brush_asset = asset
	_brush_active = true
	_set_brush_cells([_brush_start_cell])
	return true


func update_brush_stroke(mouse_position: Vector2, camera: Camera3D) -> bool:
	if not _brush_active or not move_preview(mouse_position, camera):
		return false
	var current := PlaneGrid.world_to_cell(
		_last_placement_anchor, _brush_plane_options.normal, _brush_grid_step
	)
	if current == _brush_last_cell:
		return true
	match _brush_mode:
		BrushStrokeMode.Freehand:
			for cell in PlaneGrid.raster_line(_brush_last_cell, current):
				_brush_cells[cell] = true
			_update_brush_preview()
		BrushStrokeMode.Line:
			_set_brush_cells(PlaneGrid.raster_line(_brush_start_cell, current))
		BrushStrokeMode.RectangleFill:
			_set_brush_cells(PlaneGrid.rectangle(_brush_start_cell, current))
	_brush_last_cell = current
	return true


func has_active_brush_stroke() -> bool:
	return _brush_active


func cancel_brush_stroke():
	_brush_active = false
	_brush_cells.clear()
	_brush_asset = null
	if is_instance_valid(_brush_preview):
		_brush_preview.hide()


func commit_brush_stroke() -> bool:
	if not _brush_active or _brush_asset == null or _brush_cells.is_empty():
		cancel_brush_stroke()
		return false
	var edited_root := EditorInterface.get_edited_scene_root()
	var placement_root := _presenter.resolve_placement_parent(edited_root)
	if placement_root == null:
		cancel_brush_stroke()
		return false
	var target_parent := AssetParentSelector.pick_parent(
		placement_root, _brush_asset, _presenter.options.group_automatically
	)
	if not is_instance_valid(target_parent) or not is_instance_valid(_brush_asset.get_resource()):
		cancel_brush_stroke()
		return false

	var occupants := _index_brush_occupants(placement_root)
	var old_records: Array = []
	var seen_old: Dictionary = {}
	var new_nodes: Array[Node3D] = []
	var reserved_names: Dictionary = {}
	for cell: Vector2i in _brush_cells.keys():
		for old_node: Node3D in occupants.get(cell, []):
			if seen_old.has(old_node):
				continue
			seen_old[old_node] = true
			(
				old_records
				. append(
					{
						"node": old_node,
						"parent": old_node.get_parent(),
						"index": old_node.get_index(),
						"owner": old_node.owner,
					}
				)
			)

		var new_node := _instantiate_asset_resource(_brush_asset)
		if new_node == null:
			continue
		var anchor := PlaneGrid.cell_to_world(cell, _brush_plane_options, _brush_grid_step)
		var transform := _brush_transform
		transform.origin += anchor - _brush_start_anchor
		new_node.global_transform = transform
		new_node.transform = target_parent.global_transform.affine_inverse() * transform
		new_node.name = _pick_brush_name(new_node.name, target_parent, reserved_names)
		new_node.set_meta(META_ASSET_ID, _brush_asset.id)
		new_node.set_meta(META_BRUSH_ANCHOR, anchor)
		new_node.set_meta(META_BRUSH_NORMAL, _brush_plane_options.normal.normalized())
		new_nodes.append(new_node)

	if new_nodes.is_empty():
		cancel_brush_stroke()
		return false
	undo_redo.create_action(
		"Brush Paint: %s (%d cells)" % [_brush_asset.name, new_nodes.size()], 0, edited_root
	)
	for new_node in new_nodes:
		undo_redo.add_do_reference(new_node)
	for record in old_records:
		undo_redo.add_undo_reference(record.node)
	undo_redo.add_do_method(self, "_do_brush_delta", new_nodes, target_parent, old_records)
	undo_redo.add_undo_method(self, "_undo_brush_delta", new_nodes, old_records)
	undo_redo.commit_action()
	_presenter.on_asset_placed(false)
	cancel_brush_stroke()
	return true


func _set_brush_cells(cells: Array[Vector2i]):
	_brush_cells.clear()
	for cell in cells:
		_brush_cells[cell] = true
	_update_brush_preview()


func _ensure_brush_preview():
	if is_instance_valid(_brush_preview) or _preview_root == null:
		return
	_brush_preview = MeshInstance3D.new()
	_brush_preview.name = "AssetPlacerBrushPreview"
	_brush_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.75, 1.0, 0.38)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_brush_preview.material_override = material
	_preview_root.add_child(_brush_preview)


func _update_brush_preview():
	_ensure_brush_preview()
	if not is_instance_valid(_brush_preview) or _brush_cells.is_empty():
		return
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var axes := PlaneGrid.get_axes(_brush_plane_options.normal)
	var tangent: Vector3 = axes[0]
	var bitangent: Vector3 = axes[1]
	var normal := _brush_plane_options.normal.normalized()
	var half := _brush_grid_step * 0.46
	for cell: Vector2i in _brush_cells.keys():
		var center := PlaneGrid.cell_to_world(cell, _brush_plane_options, _brush_grid_step)
		center += normal * maxf(_brush_grid_step * 0.01, 0.005)
		var base := vertices.size()
		vertices.append(center - tangent * half - bitangent * half)
		vertices.append(center + tangent * half - bitangent * half)
		vertices.append(center + tangent * half + bitangent * half)
		vertices.append(center - tangent * half + bitangent * half)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_brush_preview.mesh = mesh
	_brush_preview.show()


func _index_brush_occupants(root: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for node in _collect_asset_nodes(root):
		var anchor = _resolve_node_anchor(node)
		if anchor == null:
			continue
		var cell := PlaneGrid.world_to_cell(anchor, _brush_plane_options.normal, _brush_grid_step)
		if not result.has(cell):
			result[cell] = []
		result[cell].append(node)
	return result


func _collect_asset_nodes(root: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in root.get_children():
		if child is not Node3D:
			continue
		if child.has_meta(META_ASSET_ID):
			result.append(child)
		else:
			result.append_array(_collect_asset_nodes(child))
	return result


func _resolve_node_anchor(node: Node3D) -> Variant:
	var normal := _brush_plane_options.normal.normalized()
	var plane_height := normal.dot(_brush_plane_options.origin)
	var tolerance := maxf(_brush_grid_step * 0.05, 0.001)
	if node.has_meta(META_BRUSH_ANCHOR) and node.has_meta(META_BRUSH_NORMAL):
		var stored_normal: Vector3 = node.get_meta(META_BRUSH_NORMAL)
		if absf(stored_normal.normalized().dot(normal)) < 0.999:
			return null
		var stored_anchor: Vector3 = node.get_meta(META_BRUSH_ANCHOR)
		return (
			stored_anchor if absf(normal.dot(stored_anchor) - plane_height) <= tolerance else null
		)

	var candidates: Array[Vector3] = [node.global_position]
	var bounds := AABBProvider.provide_aabb(node)
	if bounds.size != Vector3.ZERO:
		candidates.append(node.global_transform * Vector3(0, bounds.position.y, 0))
	var best := candidates[0]
	var best_distance := absf(normal.dot(best) - plane_height)
	for candidate in candidates:
		var distance := absf(normal.dot(candidate) - plane_height)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best if best_distance <= tolerance else null


func _pick_brush_name(base: String, parent: Node, reserved: Dictionary) -> String:
	var candidate := base
	var suffix := 1
	while parent.has_node(NodePath(candidate)) or reserved.has(candidate):
		candidate = "%s (%d)" % [base, suffix]
		suffix += 1
	reserved[candidate] = true
	return candidate


func _do_brush_delta(new_nodes: Array, parent: Node3D, old_records: Array):
	for record in old_records:
		var old_node: Node3D = record.node
		if is_instance_valid(old_node) and old_node.get_parent() != null:
			old_node.get_parent().remove_child(old_node)
	for new_node: Node3D in new_nodes:
		if new_node.get_parent() == null:
			parent.add_child(new_node)
		new_node.owner = EditorInterface.get_edited_scene_root()


func _undo_brush_delta(new_nodes: Array, old_records: Array):
	for new_node: Node3D in new_nodes:
		if is_instance_valid(new_node) and new_node.get_parent() != null:
			new_node.get_parent().remove_child(new_node)
	for record in old_records:
		var old_node: Node3D = record.node
		var old_parent: Node = record.parent
		if (
			is_instance_valid(old_node)
			and is_instance_valid(old_parent)
			and old_node.get_parent() == null
		):
			old_parent.add_child(old_node)
			old_parent.move_child(old_node, mini(record.index, old_parent.get_child_count() - 1))
			old_node.owner = record.owner


func set_plugin_settings(settings: AssetPlacerSettings):
	preview_rotate_step = settings.rotation_step
	preview_transform_step = settings.transform_step
	plane_placement_step = settings.plane_placement_step
	if settings.preview_material_resource.is_empty():
		preview_material = null
	else:
		preview_material = load(settings.preview_material_resource)


func transform_preview(
	mode: AssetPlacerPresenter.TransformMode, axis: Vector3, direction: int
) -> bool:
	if not preview_node:
		return false

	match mode:
		AssetPlacerPresenter.TransformMode.None:
			return false
		AssetPlacerPresenter.TransformMode.Scale:
			var factor := 1.0 + preview_transform_step * direction
			var min_scale := 0.01
			var new_scale := preview_node.scale
			if axis.x != 0:
				new_scale.x = max(preview_node.scale.x * factor, min_scale)
			if axis.y != 0:
				new_scale.y = max(preview_node.scale.y * factor, min_scale)
			if axis.z != 0:
				new_scale.z = max(preview_node.scale.z * factor, min_scale)
			preview_node.scale = new_scale
			return true
		AssetPlacerPresenter.TransformMode.Rotate:
			# Can be replaced with deg_to_rad(preview_transform_step) however 0.1 deg is low.
			preview_node.rotate(axis.normalized() * direction, deg_to_rad(preview_rotate_step))
			return true

		AssetPlacerPresenter.TransformMode.Move:
			_presenter.move_plane_up(direction, plane_placement_step)
			return true
		_:
			return false


func get_collision_rids(node: Node) -> Array:
	var rids = []
	if node is CollisionObject3D:
		rids.append(node.get_rid())
	for child in node.get_children():
		rids += get_collision_rids(child)
	return rids


func _snap_position(hit_pos: Vector3, normal: Vector3) -> Vector3:
	if !_presenter.options.snapping_enabled:
		return hit_pos

	var grid_step: float = (
		_brush_grid_step if _brush_active else _presenter.options.snapping_grid_step
	)
	return PlaneGrid.snap_position(hit_pos, normal, grid_step)


func _place_instance(transform: Transform3D, select_after_placement: bool):
	var scene := EditorInterface.get_edited_scene_root()
	var scene_root := _presenter.resolve_placement_parent(scene)
	if scene_root == null:
		return
	var options := _presenter.options
	var parent := AssetParentSelector.pick_parent(scene_root, asset, options.group_automatically)

	if is_instance_valid(parent) and is_instance_valid(asset.get_resource()):
		var new_node: Node3D = _instantiate_asset_resource(asset)
		new_node.global_transform = transform
		new_node.transform = parent.global_transform.affine_inverse() * transform
		new_node.name = _pick_name(new_node, parent)
		new_node.set_meta(META_ASSET_ID, asset.id)

		undo_redo.create_action("Place Asset: %s" % asset.name, 0, parent)
		undo_redo.add_do_reference(new_node)
		undo_redo.add_do_method(self, "_do_placement", new_node, parent, select_after_placement)
		undo_redo.add_undo_method(self, "_undo_placement", new_node, parent)
		undo_redo.commit_action()

		AssetTransformations.apply_transforms(preview_node, _presenter.options)
		_presenter.on_asset_placed()


func _do_placement(new_node: Node3D, root: Node3D, select_after_placement: bool):
	var temp_name := new_node.name
	root.add_child(new_node)
	new_node.name = temp_name
	new_node.owner = EditorInterface.get_edited_scene_root()
	if select_after_placement:
		_presenter.clear_selection()
		EditorInterface.edit_node(new_node)


func _undo_placement(new_node: Node3D, root: Node3D):
	root.remove_child(new_node)


func _confirm_node_transform():
	if _is_node_transform_mode and preview_node:
		# Create undo action for the node transformation
		undo_redo.create_action("Transform Node: %s" % preview_node.name, 0, preview_node)
		undo_redo.add_do_method(
			self, "_do_node_transform", preview_node, preview_node.global_transform
		)
		undo_redo.add_undo_method(self, "_undo_node_transform", preview_node, _original_transform)
		undo_redo.commit_action()

		# Exit node transform mode
		_presenter.end_node_transform_mode()
		stop_placement()


func _do_node_transform(node: Node3D, new_transform: Transform3D):
	node.global_transform = new_transform


func _undo_node_transform(node: Node3D, original_transform: Transform3D):
	node.global_transform = original_transform


func stop_placement():
	cancel_brush_stroke()
	if is_instance_valid(_brush_preview):
		_brush_preview.queue_free()
	_brush_preview = null
	self.asset = null
	var was_node_transform_mode = _is_node_transform_mode
	_is_node_transform_mode = false
	if preview_node and not was_node_transform_mode:
		preview_node.queue_free()
	preview_node = null


func _instantiate_asset_resource(asset: AssetResource) -> Node3D:
	var new_node: Node3D
	var resource := asset.get_resource()
	if resource is PackedScene:
		new_node = (resource.instantiate() as Node3D)
	elif resource is ArrayMesh:
		new_node = MeshInstance3D.new()
		new_node.name = asset.name
		new_node.mesh = resource.duplicate()
	else:
		push_error("Not supported resource type %s" % str(resource))

	return new_node


func set_placement_mode(placement_mode: GapPlacementMode):
	if placement_mode is GapPlacementMode.SurfacePlacement:
		_strategy = SurfaceAssetPlacementStrategy.new(preview_rids)
	elif placement_mode is GapPlacementMode.PlanePlacement:
		_strategy = PlanePlacementStrategy.new(placement_mode.plane_options)
	elif placement_mode is GapPlacementMode.Terrain3DPlacement:
		_strategy = Terrain3DAssetPlacementStrategy.new(placement_mode.get_terrain_3d_node())
	else:
		push_error("Placement mode %s is not supported" % str(placement_mode))


func _pick_name(node: Node3D, parent: Node3D) -> String:
	var number_of_same_scenes := 0
	for child in parent.get_children():
		if child.has_meta(META_ASSET_ID) && child.get_meta(META_ASSET_ID) == asset.id:
			number_of_same_scenes += 1
	return node.name if number_of_same_scenes == 0 else node.name + " (%s)" % number_of_same_scenes


func get_safe_basis(up: Vector3, forward_hint: Vector3) -> Basis:
	up = up.normalized()
	var forward = forward_hint.normalized()

	if abs(up.dot(forward)) > 0.99:
		if abs(up.dot(Vector3.UP)) < 0.9:
			forward = Vector3.UP
		else:
			forward = Vector3.FORWARD

	var right = up.cross(forward).normalized()

	if right.length() < 0.001:
		right = up.cross(Vector3.FORWARD).normalized()
		if right.length() < 0.001:
			right = up.cross(Vector3.RIGHT).normalized()

	forward = right.cross(up).normalized()

	if up.length() < 0.001 or right.length() < 0.001 or forward.length() < 0.001:
		return Basis()

	return Basis(right, up, forward).orthonormalized()
