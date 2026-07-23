@tool
class_name AssetThumbnailTexture2D
extends Texture2D

var _asset: AssetResource
var _resolved_texture: Texture2D = null
var _last_time_modified = 0
var _thumbnail_identifier := ""
var _source_path := ""


## Uses the lightweight AssetResource instead of loading its scene resource.
func _init(asset: Variant = null):
	var cache_store := ThumbnailCacheStore.instance
	if asset is AssetResource and is_instance_valid(asset):
		_asset = asset as AssetResource
		_source_path = _asset.get_path()
		_thumbnail_identifier = cache_store.identifier_for_asset(_asset) if cache_store else ""
		_resolved_texture = cache_store.get_placeholder_texture() if cache_store else null
		_refresh_texture(true)
	var coordinator := ThumbnailGenerationCoordinator.instance
	if is_instance_valid(coordinator):
		coordinator.thumbnail_updated.connect(_on_thumbnail_updated)


func _refresh_texture(request_regeneration: bool):
	if not Engine.is_editor_hint():
		return

	if not is_instance_valid(_asset):
		return

	var cache_store := ThumbnailCacheStore.instance
	if cache_store == null:
		return

	if not _asset.has_resource():
		_resolved_texture = cache_store.get_placeholder_texture()
		emit_changed()
		return

	_source_path = _asset.get_path()
	if _source_path.is_empty():
		_resolved_texture = cache_store.get_placeholder_texture()
		emit_changed()
		return

	_thumbnail_identifier = cache_store.identifier_for_asset(_asset)
	_last_time_modified = FileAccess.get_modified_time(_source_path)
	var cached_texture := cache_store.load_texture(_thumbnail_identifier)
	var stale := cache_store.is_missing_or_stale_path(_thumbnail_identifier, _source_path)
	if is_instance_valid(cached_texture):
		_resolved_texture = cached_texture
	else:
		_resolved_texture = cache_store.get_placeholder_texture()

	if request_regeneration and stale:
		var coordinator := ThumbnailGenerationCoordinator.instance
		if is_instance_valid(coordinator) and not coordinator.is_running():
			coordinator.generate_for_asset(_asset, true)

	emit_changed()


func _resolve():
	if not Engine.is_editor_hint():
		return

	if is_instance_valid(_asset) and not _source_path.is_empty():
		var new_time_modified = FileAccess.get_modified_time(_source_path)
		if new_time_modified != _last_time_modified:
			_refresh_texture(true)


func _on_thumbnail_updated(identifier: String, _thumbnail_path: String):
	if identifier == _thumbnail_identifier:
		_refresh_texture(false)


# Called automatically by Control.draw() and other systems
func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_resolve()
	if _resolved_texture:
		_resolved_texture.draw(to_canvas_item, pos, modulate, transpose)


func _draw_rect(
	to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool
) -> void:
	_resolve()
	if _resolved_texture:
		_resolved_texture.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(
	to_canvas_item: RID,
	rect: Rect2,
	src_rect: Rect2,
	modulate: Color,
	transpose: bool,
	clip_uv: bool
) -> void:
	_resolve()
	if _resolved_texture:
		_resolved_texture.draw_rect_region(
			to_canvas_item, rect, src_rect, modulate, transpose, clip_uv
		)


func _get_width() -> int:
	_resolve()
	return _resolved_texture.get_width() if _resolved_texture else 1


func _get_height() -> int:
	_resolve()
	return _resolved_texture.get_height() if _resolved_texture else 1


func _has_alpha() -> bool:
	_resolve()
	return _resolved_texture.has_alpha() if _resolved_texture else true


func _is_pixel_opaque(x: int, y: int) -> bool:
	_resolve()
	return _resolved_texture.is_pixel_opaque(x, y) if _resolved_texture else false


func get_image() -> Image:
	_resolve()
	return _resolved_texture.get_image() if _resolved_texture else Image.new()


func get_size() -> Vector2:
	return Vector2(_get_width(), _get_height())
