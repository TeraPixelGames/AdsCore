extends "res://addons/ads_core/providers/ads_provider.gd"

var _loaded: Dictionary = {}
var _available: bool = false

func get_capabilities() -> Dictionary:
	return {
		"supports_banner": false,
		"supports_interstitial": true,
		"supports_rewarded": true,
		"supports_rewarded_interstitial": false,
		"supports_playable": false,
		"consent_required": false,
		"can_preload": true,
		"can_pause_game": true,
		"can_mute_audio": true,
	}


func init_provider(config: Dictionary) -> void:
	super.init_provider(config)
	_available = OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")


func load(placement: String, ad_type: String, _opts: Dictionary = {}) -> void:
	if not _available:
		emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_UNSUPPORTED, "web_only")
		return
	_loaded[ad_type] = true
	emit_loaded(placement, ad_type)


func show(placement: String, ad_type: String, _opts: Dictionary = {}) -> void:
	if not _available:
		emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_UNSUPPORTED, "web_only")
		return
	if not is_loaded(placement, ad_type):
		emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_NOT_LOADED, "not_loaded")
		return
	var ok := false
	match ad_type:
		"interstitial":
			ok = _call_js("(function(){if(window.y8API && y8API.showInterstitial){y8API.showInterstitial(); return true;} return false;})()")
		"rewarded":
			ok = _call_js("(function(){if(window.y8API && y8API.showRewarded){y8API.showRewarded(); return true;} return false;})()")
		_:
			ok = false
	if not ok:
		emit_failed(placement, ad_type, Ads.ErrorCode.LOAD_FAILED_INTERNAL, "y8_js_unavailable")
		return
	emit_shown(placement, ad_type)
	_loaded[ad_type] = false
	var timer := ads.get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void:
		if ad_type == "rewarded":
			emit_reward(placement, {"amount": 1, "currency": "reward"})
			emit_closed(placement, ad_type, true)
		else:
			emit_closed(placement, ad_type, false)
	)


func is_loaded(_placement: String, ad_type: String) -> bool:
	return _loaded.get(ad_type, false)


func _call_js(script: String) -> bool:
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var result = JavaScriptBridge.eval(script, true)
	return result == true
