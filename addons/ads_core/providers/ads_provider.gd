extends RefCounted
class_name AdsProvider

var ads: Node = null
var name: String = ""
var capabilities: Dictionary = {}
var enabled: bool = true

func get_capabilities() -> Dictionary:
	return {
		"supports_banner": false,
		"supports_interstitial": false,
		"supports_rewarded": false,
		"supports_rewarded_interstitial": false,
		"supports_playable": false,
		"consent_required": false,
		"can_preload": true,
		"can_pause_game": false,
		"can_mute_audio": false,
	}


func init_provider(_config: Dictionary) -> void:
	enabled = not _config.get("disabled", false)


func shutdown() -> void:
	pass


func load(_placement: String, _ad_type: String, _opts: Dictionary = {}) -> void:
	pass


func show(_placement: String, _ad_type: String, _opts: Dictionary = {}) -> void:
	pass


func is_loaded(_placement: String, _ad_type: String) -> bool:
	return false


func set_consent(_consent_state: Dictionary) -> void:
	pass


func set_test_mode(_enabled: bool) -> void:
	pass


func emit_loaded(placement: String, ad_type: String) -> void:
	if ads:
		ads._on_provider_event(name, "loaded", {"placement": placement, "ad_type": ad_type})


func emit_failed(placement: String, ad_type: String, code: int, message: String) -> void:
	if ads:
		ads._on_provider_event(name, "failed", {"placement": placement, "ad_type": ad_type, "error_code": code, "message": message})


func emit_shown(placement: String, ad_type: String) -> void:
	if ads:
		ads._on_provider_event(name, "shown", {"placement": placement, "ad_type": ad_type})


func emit_closed(placement: String, ad_type: String, completed: bool) -> void:
	if ads:
		ads._on_provider_event(name, "closed", {"placement": placement, "ad_type": ad_type, "completed": completed})


func emit_reward(placement: String, reward: Dictionary) -> void:
	if ads:
		ads._on_provider_event(name, "rewarded", {"placement": placement, "ad_type": "rewarded", "reward": reward})


func emit_clicked(placement: String, ad_type: String) -> void:
	if ads:
		ads._on_provider_event(name, "clicked", {"placement": placement, "ad_type": ad_type})


func emit_impression(placement: String, ad_type: String) -> void:
	if ads:
		ads._on_provider_event(name, "impression", {"placement": placement, "ad_type": ad_type})
