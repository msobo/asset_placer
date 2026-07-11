@tool
extends PanelContainer

signal action_pressed
signal set_primary_pressed

const CIRCLE_ICON = preload(
	"res://addons/asset_placer/ui/asset_collections_window/components/collection_circle.svg"
)

var _collection_color: Color

@onready var _button: Button = %Button
@onready var _collection_icon: TextureRect = %CollectionIcon
@onready var _label: Label = %Label
@onready var _favorite_button: Button = %MoveUpButton
@onready var _move_down_button: Button = %MoveDownButton


func _ready():
	_button.pressed.connect(func(): action_pressed.emit())
	_favorite_button.pressed.connect(func(): set_primary_pressed.emit())


func configure_as_assigned(
	collection: AssetCollection,
	is_partial: bool,
	primary_count: int,
	total_selected: int,
	batch_count: int = 1
):
	_set_collection_info(collection, is_partial)

	_button.icon = EditorIconTexture2D.new("Clear")
	if batch_count > 1:
		_button.text = "Unasign from %d assets" % batch_count
	else:
		_button.text = "Unasign"

	_move_down_button.hide()

	if is_partial:
		_favorite_button.hide()
	else:
		_favorite_button.icon = EditorIconTexture2D.new("Favorites")
		_favorite_button.theme_type_variation = &"FlatButton"
		_favorite_button.toggle_mode = true
		_favorite_button.show()
		_favorite_button.set_pressed_no_signal(primary_count == total_selected)
		_favorite_button.tooltip_text = _get_primary_tooltip(primary_count, total_selected)

		_apply_primary_state(primary_count, total_selected)


func configure_as_available(collection: AssetCollection, batch_count: int = 1):
	_set_collection_info(collection, false)
	_favorite_button.hide()
	_button.icon = EditorIconTexture2D.new("Add")
	if batch_count > 1:
		_button.text = "Asign to %d assets" % batch_count
	else:
		_button.text = "Asign"

	_move_down_button.hide()


func _set_collection_info(collection: AssetCollection, is_partial: bool):
	remove_theme_stylebox_override("panel")
	_favorite_button.modulate = Color.WHITE
	_favorite_button.set_pressed_no_signal(false)
	_collection_color = collection.background_color
	_collection_icon.texture = CIRCLE_ICON
	_collection_icon.modulate = _collection_color

	if is_partial:
		_label.text = collection.name + " (partial)"
		_collection_icon.modulate.a = 0.5
	else:
		_label.text = collection.name

	_label.remove_theme_color_override("font_color")


func _apply_primary_state(primary_count: int, total_selected: int):
	if primary_count <= 0:
		return

	_collection_icon.texture = EditorIconTexture2D.new("Favorites")
	_collection_icon.modulate = _collection_color

	if primary_count == total_selected:
		_label.text += " — Primary"
		_label.add_theme_color_override("font_color", _collection_color.lightened(0.35))
		_apply_primary_background()
	else:
		_label.text += " — Primary (%d/%d)" % [primary_count, total_selected]
		_collection_icon.modulate.a = 0.55
		_favorite_button.modulate.a = 0.65


func _apply_primary_background():
	var style := StyleBoxFlat.new()
	style.bg_color = Color(_collection_color, 0.18)
	style.border_color = Color(_collection_color, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)


func _get_primary_tooltip(primary_count: int, total_selected: int) -> String:
	var asset_label := "asset" if total_selected == 1 else "assets"
	if primary_count == total_selected:
		return "Remove Primary from %d %s" % [total_selected, asset_label]
	return "Set as Primary for %d %s" % [total_selected, asset_label]
