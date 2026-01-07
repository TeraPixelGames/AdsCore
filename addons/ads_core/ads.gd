extends Node

enum AdType { BANNER, INTERSTITIAL, REWARDED, REWARDED_INTERSTITIAL, PLAYABLE }
const AD_TYPE_STR := {
	AdType.BANNER: "banner",
	AdType.INTERSTITIAL: "interstitial",
	AdType.REWARDED: "rewarded",
	AdType.REWARDED_INTERSTITIAL: "rewarded_interstitial",
	AdType.PLAYABLE: "playable",
}

enum ErrorCode {
	INIT_FAILED,
	LOAD_FAILED_NO_FILL,
	LOAD_FAILED_NETWORK,
	LOAD_FAILED_INTERNAL,
	SHOW_FAILED_COOLDOWN,
	SHOW_FAILED_NOT_LOADED,
	SHOW_FAILED_UNSUPPORTED,
	CONSENT_REQUIRED,
	PROVIDER_DISABLED,
	TIMEOUT,
}

signal ad_loaded(provider: String, placement: String, ad_type: String)
signal ad_failed(provider: String, placement: String, ad_type: String, error_code: int, message: String)
signal ad_shown(provider: String, placement: String, ad_type: String)
signal ad_closed(provider: String, placement: String, ad_type: String, completed: bool)
signal ad_rewarded(provider: String, placement: String, reward: Dictionary)
signal ad_clicked(provider: String, placement: String, ad_type: String)
signal ad_impression(provider: String, placement: String, ad_type: String)
signal analytics_event(event_name: String, data: Dictionary)

var _providers: Dictionary = {}
var _provider_order: Array[String] = []
var _caps_config: Dictionary = {}
var _caps_state: Dictionary = {}
var _consent: Dictionary = {}
var _test_mode: bool = false
var _analytics_listeners: Array[Callable] = []

func _ready() -> void:
	# Auto-init with defaults if not configured by the host app.
	if _provider_order.is_empty():
		init({})


func init(config: Dictionary) -> void:
	_clear()
	var merged_config := _load_project_config()
	for key in config:
		if key == "provider_config":
			var project_pc := merged_config.get("provider_config", {})
			var user_pc := config.get("provider_config", {})
			for provider_name in user_pc:
				project_pc[provider_name] = user_pc[provider_name]
			merged_config["provider_config"] = project_pc
		else:
			merged_config[key] = config[key]
	_provider_order = merged_config.get("providers", ["admob", "poki", "crazygames", "lagged", "y8", "mock"])
	var provider_config: Dictionary = merged_config.get("provider_config", {})
	for name in _provider_order:
		var provider := _create_provider(name)
		if provider == null:
			continue
		provider.ads = self
		provider.name = name
		provider.capabilities = provider.get_capabilities()
		provider.init_provider(provider_config.get(name, {}))
		_providers[name] = provider
	_caps_config = merged_config.get("caps", {})
	_test_mode = merged_config.get("test_mode", false)
	_consent = merged_config.get("consent", {})
	for provider_name in _providers:
		_providers[provider_name].set_test_mode(_test_mode)
		_providers[provider_name].set_consent(_consent)


func _clear() -> void:
	for provider_name in _providers:
		if _providers[provider_name].has_method("shutdown"):
			_providers[provider_name].shutdown()
	_providers.clear()
	_caps_state.clear()


func get_capabilities(provider: String) -> Dictionary:
	if not _providers.has(provider):
		return {}
	return _providers[provider].get_capabilities()


func get_capabilities_all() -> Dictionary:
	var result := {}
	for provider_name in _providers:
		result[provider_name] = _providers[provider_name].get_capabilities()
	return result


func register_provider(provider: Object) -> void:
	if provider == null or not provider.has_method("get_capabilities"):
		return
	provider.ads = self
	provider.capabilities = provider.get_capabilities()
	_providers[provider.name] = provider
	if not _provider_order.has(provider.name):
		_provider_order.append(provider.name)


func set_test_mode(enabled: bool) -> void:
	_test_mode = enabled
	for provider_name in _providers:
		_providers[provider_name].set_test_mode(enabled)


func set_consent(consent_state: Dictionary) -> void:
	_consent = consent_state
	for provider_name in _providers:
		_providers[provider_name].set_consent(consent_state)


func set_caps(placement: String, caps: Dictionary) -> void:
	_caps_config[placement] = caps


func set_enabled(provider: String, enabled: bool) -> void:
	if _providers.has(provider):
		_providers[provider].enabled = enabled


func load(placement: String, ad_type: String, opts: Dictionary = {}) -> bool:
	var provider := opts.get("provider", _select_provider(ad_type))
	if provider == "":
		ad_failed.emit("", placement, ad_type, ErrorCode.SHOW_FAILED_UNSUPPORTED, "no_provider")
		return false
	if not _providers.has(provider):
		ad_failed.emit(provider, placement, ad_type, ErrorCode.PROVIDER_DISABLED, "provider_missing")
		return false
	var p = _providers[provider]
	if not _provider_supports(p, ad_type):
		ad_failed.emit(provider, placement, ad_type, ErrorCode.SHOW_FAILED_UNSUPPORTED, "unsupported_ad_type")
		return false
	p.load(placement, ad_type, opts)
	return true


func show(placement: String, ad_type: String, opts: Dictionary = {}) -> bool:
	var provider := opts.get("provider", _select_provider(ad_type))
	if provider == "":
		ad_failed.emit("", placement, ad_type, ErrorCode.SHOW_FAILED_UNSUPPORTED, "no_provider")
		return false
	if not _providers.has(provider):
		ad_failed.emit(provider, placement, ad_type, ErrorCode.PROVIDER_DISABLED, "provider_missing")
		return false
	var p = _providers[provider]
	if not _provider_supports(p, ad_type):
		ad_failed.emit(provider, placement, ad_type, ErrorCode.SHOW_FAILED_UNSUPPORTED, "unsupported_ad_type")
		return false
	var caps_check := _can_show(placement)
	if not caps_check.get("ok", true):
		ad_failed.emit(provider, placement, ad_type, ErrorCode.SHOW_FAILED_COOLDOWN, caps_check.get("reason", "cap_reached"))
		return false
	p.show(placement, ad_type, opts)
	return true


func is_loaded(placement: String, ad_type: String, provider: String = "") -> bool:
	var provider_name := provider if provider != "" else _select_provider(ad_type)
	if provider_name == "" or not _providers.has(provider_name):
		return false
	return _providers[provider_name].is_loaded(placement, ad_type)


func get_providers() -> Array[String]:
	return _provider_order.duplicate()


func get_provider_instance(name: String) -> Object:
	if _providers.has(name):
		return _providers[name]
	return null


func register_analytics_listener(callback: Callable) -> void:
	if callback.is_valid():
		_analytics_listeners.append(callback)


func _select_provider(ad_type: String) -> String:
	for provider_name in _provider_order:
		if not _providers.has(provider_name):
			continue
		var p = _providers[provider_name]
		if not p.enabled:
			continue
		if _provider_supports(p, ad_type):
			return provider_name
	return ""


func _provider_supports(provider: Object, ad_type: String) -> bool:
	var caps : Dictionary = provider.get_capabilities()
	match ad_type:
		"banner":
			return caps.get("supports_banner", false)
		"interstitial":
			return caps.get("supports_interstitial", false)
		"rewarded":
			return caps.get("supports_rewarded", false)
		"rewarded_interstitial":
			return caps.get("supports_rewarded_interstitial", false)
		"playable":
			return caps.get("supports_playable", false)
		_:
			return false


func _can_show(placement: String) -> Dictionary:
	var limits: Dictionary = _caps_config.get(placement, {})
	if limits.is_empty():
		return {"ok": true}
	var state: Dictionary = _caps_state.get(placement, {"count": 0, "last_shown": 0.0})
	var now := Time.get_unix_time_from_system()
	if limits.has("max_per_session") and state.get("count", 0) >= limits.get("max_per_session"):
		return {"ok": false, "reason": "cap_reached"}
	if limits.has("min_interval_sec") and now - state.get("last_shown", 0.0) < limits.get("min_interval_sec"):
		return {"ok": false, "reason": "cooldown_active"}
	return {"ok": true}


func _record_show(placement: String) -> void:
	var state: Dictionary = _caps_state.get(placement, {"count": 0, "last_shown": 0.0})
	state.count = state.get("count", 0) + 1
	state.last_shown = Time.get_unix_time_from_system()
	_caps_state[placement] = state


func _emit_analytics(event_name: String, data: Dictionary) -> void:
	analytics_event.emit(event_name, data)
	for listener in _analytics_listeners:
		if listener.is_valid():
			listener.call_deferred(event_name, data)


func _on_provider_event(provider: String, kind: String, payload: Dictionary) -> void:
	var placement := payload.get("placement", "")
	var ad_type := payload.get("ad_type", "")
	match kind:
		"loaded":
			ad_loaded.emit(provider, placement, ad_type)
		"failed":
			ad_failed.emit(provider, placement, ad_type, payload.get("error_code", ErrorCode.LOAD_FAILED_INTERNAL), payload.get("message", ""))
		"shown":
			_record_show(placement)
			ad_shown.emit(provider, placement, ad_type)
		"closed":
			ad_closed.emit(provider, placement, ad_type, payload.get("completed", false))
		"rewarded":
			ad_rewarded.emit(provider, placement, payload.get("reward", {}))
		"clicked":
			ad_clicked.emit(provider, placement, ad_type)
		"impression":
			ad_impression.emit(provider, placement, ad_type)
		_:
			pass
	if kind != "":
		var analytics_data := payload.duplicate()
		analytics_data["provider"] = provider
		analytics_data["event"] = kind
		_emit_analytics("ads." + kind, analytics_data)


func _create_provider(name: String) -> Object:
	match name:
		"admob":
			return preload("res://addons/ads_core/providers/admob_provider.gd").new()
		"poki":
			return preload("res://addons/ads_core/providers/poki_provider.gd").new()
		"crazygames":
			return preload("res://addons/ads_core/providers/crazygames_provider.gd").new()
		"lagged":
			return preload("res://addons/ads_core/providers/lagged_provider.gd").new()
		"y8":
			return preload("res://addons/ads_core/providers/y8_provider.gd").new()
		"mock":
			return preload("res://addons/ads_core/providers/mock_provider.gd").new()
		_:
			return null


func _load_project_config() -> Dictionary:
	var config := {}

	if ProjectSettings.has_setting("ads_core/providers"):
		config["providers"] = ProjectSettings.get_setting("ads_core/providers")

	var consent := {
		"non_personalized": ProjectSettings.get_setting("ads_core/consent/non_personalized", false),
		"limit_ad_tracking": ProjectSettings.get_setting("ads_core/consent/limit_ad_tracking", false)
	}
	config["consent"] = consent
	config["test_mode"] = ProjectSettings.get_setting("ads_core/general/test_mode", false)

	var admob_config := {
		"placements": ProjectSettings.get_setting("ads_core/admob/placements", {}),
		"request_configuration": ProjectSettings.get_setting("ads_core/admob/request_configuration", {}),
		"test_device_ids": ProjectSettings.get_setting("ads_core/admob/test_device_ids", []),
		"banner_position": ProjectSettings.get_setting("ads_core/admob/banner_position", 1)
	}
	if not ProjectSettings.get_setting("ads_core/admob/enabled", true):
		admob_config["disabled"] = true

	config["provider_config"] = {"admob": admob_config}

	return config
