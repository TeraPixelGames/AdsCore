@tool
extends EditorPlugin

var _debug_dock: Control

func _enter_tree() -> void:
	_register_project_settings()
	if not FileAccess.file_exists("res://addons/admob/plugin.cfg"):
		push_warning("AdsCore: AdMob addon not found at res://addons/admob/plugin.cfg; AdMob provider will run in stub mode.")
	add_autoload_singleton("Ads", "res://addons/ads_core/ads.gd")
	if _debug_dock == null:
		_debug_dock = preload("res://addons/ads_core/debug/ads_debug_panel.gd").new()
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, _debug_dock)


func _exit_tree() -> void:
	if _debug_dock:
		remove_control_from_docks(_debug_dock)
		_debug_dock.queue_free()
		_debug_dock = null
	remove_autoload_singleton("Ads")


func _register_project_settings() -> void:
	var settings := [
		{
			"name": "ads_core/providers",
			"type": TYPE_ARRAY,
			"default": ["admob", "poki", "crazygames", "lagged", "y8", "mock"]
		},
		{
			"name": "ads_core/general/test_mode",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "ads_core/consent/non_personalized",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "ads_core/consent/limit_ad_tracking",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "ads_core/admob/enabled",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "ads_core/admob/banner_position",
			"type": TYPE_INT,
			"default": 1, # bottom
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Top,Bottom,Left,Right,Top Left,Top Right,Bottom Left,Bottom Right,Center"
		},
		{
			"name": "ads_core/admob/placements",
			"type": TYPE_DICTIONARY,
			"default": {}
		},
		{
			"name": "ads_core/admob/request_configuration",
			"type": TYPE_DICTIONARY,
			"default": {}
		},
		{
			"name": "ads_core/admob/test_device_ids",
			"type": TYPE_ARRAY,
			"default": []
		}
	]

	for setting in settings:
		var name: String = setting["name"]
		if not ProjectSettings.has_setting(name):
			ProjectSettings.set_setting(name, setting.get("default"))
		var info := {
			"name": name,
			"type": setting["type"],
			"hint": setting.get("hint", PROPERTY_HINT_NONE),
			"hint_string": setting.get("hint_string", ""),
			"usage": PROPERTY_USAGE_DEFAULT
		}
		ProjectSettings.add_property_info(info)
