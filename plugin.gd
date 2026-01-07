@tool
extends EditorPlugin

var _debug_dock: Control
var _admob_plugin: EditorPlugin

func _enter_tree() -> void:
	_register_project_settings()
	_enable_admob()
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
	_disable_admob()


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


func _enable_admob() -> void:
	var admob_path := "res://addons/ads_core/admob/admob.gd"
	if not FileAccess.file_exists(admob_path):
		push_warning("AdsCore: AdMob addon not found at %s; AdMob provider will run in stub mode." % admob_path)
		return
	var admob_script := load(admob_path)
	if admob_script == null:
		push_warning("AdsCore: Failed to load %s; AdMob provider will run in stub mode." % admob_path)
		return
	_admob_plugin = admob_script.new()
	if _admob_plugin:
		add_child(_admob_plugin)


func _disable_admob() -> void:
	if _admob_plugin and is_instance_valid(_admob_plugin):
		remove_child(_admob_plugin)
		_admob_plugin.queue_free()
		_admob_plugin = null
