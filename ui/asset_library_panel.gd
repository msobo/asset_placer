@tool
class_name AssetLibraryPanel
extends Control

@onready var asset_library_window: AssetLibraryWindow = $Panel/TabContainer/Assets
@onready var tab_container: TabContainer = $Panel/TabContainer


func _ready():
	AssetPlacerDockPresenter.instance.show_tab.connect(func(tab): tab_container.current_tab = tab)
