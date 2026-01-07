extends "res://addons/ads_core/providers/ads_provider.gd"

var _loaded: Dictionary = {}
var _behavior := {
	"load_success": true,
	"show_success": true,
	"reward": true,
	"delay_sec": 0.2,
}

func get_capabilities() -> Dictionary:
	return {
		"supports_banner": true,
		"supports_interstitial": true,
		"supports_rewarded": true,
		"supports_rewarded_interstitial": true,
		"supports_playable": true,
		"consent_required": false,
		"can_preload": true,
		"can_pause_game": true,
		"can_mute_audio": true,
	}


func init_provider(config: Dictionary) -> void:
	super.init_provider(config)
	_behavior.merge(config.get("behavior", {}), true)


func set_behavior(config: Dictionary) -> void:
	_behavior.merge(config, true)


func load(placement: String, ad_type: String, _opts: Dictionary = {}) -> void:
	_loaded[ad_type] = false
	var timer := ads.get_tree().create_timer(_behavior.get("delay_sec", 0.2))
	timer.timeout.connect(func() -> void:
		if _behavior.get("load_success", true):
			_loaded[ad_type] = true
			emit_loaded(placement, ad_type)
		else:
			emit_failed(placement, ad_type, Ads.ErrorCode.LOAD_FAILED_INTERNAL, "mock_load_failed")
	)


func show(placement: String, ad_type: String, _opts: Dictionary = {}) -> void:
	if not is_loaded(placement, ad_type):
		emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_NOT_LOADED, "mock_not_loaded")
		return
	_loaded[ad_type] = false
	var timer := ads.get_tree().create_timer(_behavior.get("delay_sec", 0.2))
	timer.timeout.connect(func() -> void:
		if not _behavior.get("show_success", true):
			emit_failed(placement, ad_type, Ads.ErrorCode.LOAD_FAILED_INTERNAL, "mock_show_failed")
			return
		emit_shown(placement, ad_type)
		if _behavior.get("reward", true) and ad_type.find("rewarded") != -1:
			emit_reward(placement, {"amount": 1, "currency": "mock"})
			emit_closed(placement, ad_type, true)
		else:
			emit_closed(placement, ad_type, false)
	)


func is_loaded(_placement: String, ad_type: String) -> bool:
	return _loaded.get(ad_type, false)
