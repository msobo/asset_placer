class_name AssetPlacerOptions
extends RefCounted

const DEFAULT_GRID_STEP := Vector2.ONE
const MIN_GRID_STEP := 0.01
const MAX_GRID_STEP := 1000.0

var snapping_enabled: bool = false
var snapping_grid_step: Vector2 = DEFAULT_GRID_STEP

var use_asset_origin: bool = true
var align_normals: bool = false
var enable_random_placement = false

var rotate_on_placement: bool = false
var max_rotation: Vector3 = Vector3.UP * 180
var min_rotation: Vector3 = Vector3.ZERO

var scale_on_placement: bool = false
var min_scale: Vector3 = Vector3.ONE
var max_scale: Vector3 = Vector3.ONE * 2
var uniform_scaling: bool = true

var group_automatically: bool = true
var use_selected_as_parent: bool = false
