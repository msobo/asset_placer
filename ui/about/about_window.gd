@tool
extends Control
const PLUGIN_CONFIG_PATH := "res://addons/asset_placer/plugin.cfg"

@onready var version_label: Label = %VersionLabel


func _ready():
	version_label.text = "Version %s" % get_plugin_version()


func get_plugin_version() -> String:
	var config := ConfigFile.new()
	if config.load(PLUGIN_CONFIG_PATH) != OK:
		return "unknown"
	return str(config.get_value("plugin", "version", "unknown"))
