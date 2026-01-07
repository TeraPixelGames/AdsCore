extends "res://addons/ads_core/providers/ads_provider.gd"

const TEST_UNIT_IDS := {
	"banner": "ca-app-pub-3940256099942544/6300978111",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
	"rewarded_interstitial": "ca-app-pub-3940256099942544/5354046379",
}

var _placements: Dictionary = {}
var _last_placement_by_type: Dictionary = {}
var _pending_actions: Array[Callable] = []
var _pending_reward_state: Dictionary = {}
var _request_extras: Dictionary = {}
var _request_config: Dictionary = {}
var _test_device_ids: Array = []
var _initialized: bool = false
var _initializing: bool = false
var _test_mode: bool = false

var _banner: AdView = null
var _banner_loaded: bool = false
var _banner_position := AdPosition.Values.BOTTOM

var _interstitial: InterstitialAd = null
var _rewarded: RewardedAd = null
var _rewarded_interstitial: RewardedInterstitialAd = null


func get_capabilities() -> Dictionary:
	return {
		"supports_banner": true,
		"supports_interstitial": true,
		"supports_rewarded": true,
		"supports_rewarded_interstitial": true,
		"supports_playable": false,
		"consent_required": true,
		"can_preload": true,
		"can_pause_game": false,
		"can_mute_audio": true,
	}


func init_provider(config: Dictionary) -> void:
	super.init_provider(config)
	_placements = config.get("placements", {})
	_request_config = config.get("request_configuration", {})
	_test_device_ids = config.get("test_device_ids", [])
	_banner_position = config.get("banner_position", AdPosition.Values.BOTTOM)
	if not enabled:
		return
	if not _has_admob_plugin():
		enabled = false
		return
	_apply_request_configuration()
	_start_initialization()


func shutdown() -> void:
	_destroy_banner()
	_destroy_interstitial()
	_destroy_rewarded()
	_destroy_rewarded_interstitial()
	_pending_actions.clear()


func set_consent(consent_state: Dictionary) -> void:
	_request_extras.clear()
	if consent_state.get("limit_ad_tracking", false) or consent_state.get("non_personalized", false):
		_request_extras["npa"] = "1"
	_apply_request_configuration()


func set_test_mode(enabled: bool) -> void:
	_test_mode = enabled


func load(placement: String, ad_type: String, _opts: Dictionary = {}) -> void:
	if not _has_admob_plugin():
		emit_failed(placement, ad_type, Ads.ErrorCode.PROVIDER_DISABLED, "admob_plugin_missing")
		return
	_last_placement_by_type[ad_type] = placement
	if not _initialized:
		_queue_action(func() -> void:
			self.load(placement, ad_type, _opts)
		)
		return
	match ad_type:
		"banner":
			_load_banner(placement)
		"interstitial":
			_load_interstitial(placement)
		"rewarded":
			_load_rewarded(placement)
		"rewarded_interstitial":
			_load_rewarded_interstitial(placement)
		_:
			emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_UNSUPPORTED, "unsupported")


func show(placement: String, ad_type: String, _opts: Dictionary = {}) -> void:
	if not _has_admob_plugin():
		emit_failed(placement, ad_type, Ads.ErrorCode.PROVIDER_DISABLED, "admob_plugin_missing")
		return
	_last_placement_by_type[ad_type] = placement
	match ad_type:
		"banner":
			if _banner and _banner_loaded:
				_banner.show()
				emit_shown(placement, ad_type)
			else:
				emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_NOT_LOADED, "banner_not_loaded")
		"interstitial":
			if _interstitial:
				_interstitial.show()
			else:
				emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_NOT_LOADED, "interstitial_not_loaded")
		"rewarded":
			if _rewarded:
				_set_pending_reward_state(ad_type, placement)
				_rewarded.show(_build_reward_listener(ad_type))
			else:
				emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_NOT_LOADED, "rewarded_not_loaded")
		"rewarded_interstitial":
			if _rewarded_interstitial:
				_set_pending_reward_state(ad_type, placement)
				_rewarded_interstitial.show(_build_reward_listener(ad_type))
			else:
				emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_NOT_LOADED, "rewarded_interstitial_not_loaded")
		_:
			emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_UNSUPPORTED, "unsupported")


func is_loaded(_placement: String, ad_type: String) -> bool:
	match ad_type:
		"banner":
			return _banner != null and _banner_loaded
		"interstitial":
			return _interstitial != null
		"rewarded":
			return _rewarded != null
		"rewarded_interstitial":
			return _rewarded_interstitial != null
		_:
			return false


func _has_admob_plugin() -> bool:
	return ClassDB.class_exists("MobileAds") and Engine.has_singleton("PoingGodotAdMob")


func _start_initialization() -> void:
	if _initialized or _initializing:
		return
	_initializing = true
	var init_listener := OnInitializationCompleteListener.new()
	init_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_initialized = true
		_initializing = false
		_flush_pending_actions()
	MobileAds.initialize(init_listener)


func _queue_action(action: Callable) -> void:
	if not _initializing:
		_start_initialization()
	_pending_actions.append(action)


func _flush_pending_actions() -> void:
	var queued := _pending_actions.duplicate()
	_pending_actions.clear()
	for action in queued:
		if action.is_valid():
			action.call_deferred()


func _apply_request_configuration() -> void:
	if not _has_admob_plugin() or not ClassDB.class_exists("RequestConfiguration"):
		return
	var request_configuration := RequestConfiguration.new()
	request_configuration.test_device_ids = _test_device_ids
	if _request_config.has("tag_for_child_directed_treatment"):
		request_configuration.tag_for_child_directed_treatment = _request_config["tag_for_child_directed_treatment"]
	if _request_config.has("tag_for_under_age_of_consent"):
		request_configuration.tag_for_under_age_of_consent = _request_config["tag_for_under_age_of_consent"]
	if _request_config.has("max_ad_content_rating"):
		request_configuration.max_ad_content_rating = _request_config["max_ad_content_rating"]
	MobileAds.set_request_configuration(request_configuration)


func _load_banner(placement: String) -> void:
	_destroy_banner()
	_banner_loaded = false
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_resolve_unit(placement, "banner"), ad_size, _banner_position)
	_banner.ad_listener = _build_banner_listener(placement)
	_banner.load_ad(_build_ad_request())


func _load_interstitial(placement: String) -> void:
	_destroy_interstitial()
	var load_callback := InterstitialAdLoadCallback.new()
	load_callback.on_ad_failed_to_load = func(ad_error: LoadAdError) -> void:
		emit_failed(placement, "interstitial", _map_load_error(ad_error), ad_error.message)
	load_callback.on_ad_loaded = func(interstitial_ad: InterstitialAd) -> void:
		_interstitial = interstitial_ad
		_interstitial.full_screen_content_callback = _build_fullscreen_callback(placement, "interstitial")
		emit_loaded(placement, "interstitial")
	InterstitialAdLoader.new().load(_resolve_unit(placement, "interstitial"), _build_ad_request(), load_callback)


func _load_rewarded(placement: String) -> void:
	_destroy_rewarded()
	var load_callback := RewardedAdLoadCallback.new()
	load_callback.on_ad_failed_to_load = func(ad_error: LoadAdError) -> void:
		emit_failed(placement, "rewarded", _map_load_error(ad_error), ad_error.message)
	load_callback.on_ad_loaded = func(rewarded_ad: RewardedAd) -> void:
		_rewarded = rewarded_ad
		_rewarded.full_screen_content_callback = _build_fullscreen_callback(placement, "rewarded")
		emit_loaded(placement, "rewarded")
	RewardedAdLoader.new().load(_resolve_unit(placement, "rewarded"), _build_ad_request(), load_callback)


func _load_rewarded_interstitial(placement: String) -> void:
	_destroy_rewarded_interstitial()
	var load_callback := RewardedInterstitialAdLoadCallback.new()
	load_callback.on_ad_failed_to_load = func(ad_error: LoadAdError) -> void:
		emit_failed(placement, "rewarded_interstitial", _map_load_error(ad_error), ad_error.message)
	load_callback.on_ad_loaded = func(rewarded_interstitial_ad: RewardedInterstitialAd) -> void:
		_rewarded_interstitial = rewarded_interstitial_ad
		_rewarded_interstitial.full_screen_content_callback = _build_fullscreen_callback(placement, "rewarded_interstitial")
		emit_loaded(placement, "rewarded_interstitial")
	RewardedInterstitialAdLoader.new().load(_resolve_unit(placement, "rewarded_interstitial"), _build_ad_request(), load_callback)


func _build_ad_request() -> AdRequest:
	var request := AdRequest.new()
	request.extras = _request_extras.duplicate()
	return request


func _build_banner_listener(placement: String) -> AdListener:
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		_banner_loaded = true
		emit_loaded(placement, "banner")
	listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		emit_failed(placement, "banner", _map_load_error(error), error.message)
	listener.on_ad_opened = func() -> void:
		emit_shown(placement, "banner")
	listener.on_ad_closed = func() -> void:
		emit_closed(placement, "banner", false)
	listener.on_ad_clicked = func() -> void:
		emit_clicked(placement, "banner")
	listener.on_ad_impression = func() -> void:
		emit_impression(placement, "banner")
	return listener


func _build_fullscreen_callback(placement: String, ad_type: String) -> FullScreenContentCallback:
	var callback := FullScreenContentCallback.new()
	callback.on_ad_clicked = func() -> void:
		emit_clicked(placement, ad_type)
	callback.on_ad_impression = func() -> void:
		emit_impression(placement, ad_type)
	callback.on_ad_showed_full_screen_content = func() -> void:
		emit_shown(placement, ad_type)
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		var completed := false
		if ad_type == "rewarded" or ad_type == "rewarded_interstitial":
			var state: Dictionary = _pending_reward_state.get(ad_type, {})
			completed = state.get("earned", false)
			_pending_reward_state.erase(ad_type)
		emit_closed(placement, ad_type, completed)
	_destroy_loaded(ad_type)
	callback.on_ad_failed_to_show_full_screen_content = func(ad_error: AdError) -> void:
		emit_failed(placement, ad_type, Ads.ErrorCode.SHOW_FAILED_INTERNAL, ad_error.message)
	_destroy_loaded(ad_type)
	return callback


func _build_reward_listener(ad_type: String) -> OnUserEarnedRewardListener:
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(rewarded_item: RewardedItem) -> void:
		var state: Dictionary = _pending_reward_state.get(ad_type, {})
		state["earned"] = true
		_pending_reward_state[ad_type] = state
		var placement := state.get("placement", ad_type)
		var reward := {"currency": rewarded_item.type, "amount": rewarded_item.amount}
		emit_reward(placement, reward)
	return listener


func _set_pending_reward_state(ad_type: String, placement: String) -> void:
	_pending_reward_state[ad_type] = {"placement": placement, "earned": false}


func _map_load_error(error: LoadAdError) -> int:
	match error.code:
		2:
			return Ads.ErrorCode.LOAD_FAILED_NETWORK
		3:
			return Ads.ErrorCode.LOAD_FAILED_NO_FILL
		_:
			return Ads.ErrorCode.LOAD_FAILED_INTERNAL


func _resolve_unit(placement: String, default_type: String) -> String:
	if _test_mode:
		return TEST_UNIT_IDS.get(default_type, default_type)
	return _placements.get(placement, default_type)


func _destroy_banner() -> void:
	if _banner:
		_banner.destroy()
		_banner = null
		_banner_loaded = false


func _destroy_interstitial() -> void:
	if _interstitial:
		_interstitial.destroy()
		_interstitial = null


func _destroy_rewarded() -> void:
	if _rewarded:
		_rewarded.destroy()
		_rewarded = null


func _destroy_rewarded_interstitial() -> void:
	if _rewarded_interstitial:
		_rewarded_interstitial.destroy()
		_rewarded_interstitial = null


func _destroy_loaded(ad_type: String) -> void:
	match ad_type:
		"interstitial":
			_destroy_interstitial()
		"rewarded":
			_destroy_rewarded()
		"rewarded_interstitial":
			_destroy_rewarded_interstitial()
