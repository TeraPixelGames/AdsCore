@tool
extends Control

var _mock_provider: Object = null
var _load_success: CheckBox
var _show_success: CheckBox
var _reward_toggle: CheckBox
var _delay_slider: HSlider

func _ready() -> void:
	name = "Ads Debug"
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	_focus_mock()
	_build_ui()


func _focus_mock() -> void:
	var ads := _get_ads()
	if ads and ads.has_method("get_provider_instance"):
		_mock_provider = ads.get_provider_instance("mock")


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "AdsDebugVBox"
	root.anchor_right = 1
	root.anchor_bottom = 1
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(root)

	var title := Label.new()
	title.text = "Ads Mock Simulator"
	title.add_theme_font_size_override("font_size", 14)
	root.add_child(title)

	_load_success = CheckBox.new()
	_load_success.text = "Load succeeds"
	_load_success.button_pressed = true
	_load_success.toggled.connect(func(_v: bool) -> void:
		_push_behavior()
	)
	root.add_child(_load_success)

	_show_success = CheckBox.new()
	_show_success.text = "Show succeeds"
	_show_success.button_pressed = true
	_show_success.toggled.connect(func(_v: bool) -> void:
		_push_behavior()
	)
	root.add_child(_show_success)

	_reward_toggle = CheckBox.new()
	_reward_toggle.text = "Reward on rewarded ads"
	_reward_toggle.button_pressed = true
	_reward_toggle.toggled.connect(func(_v: bool) -> void:
		_push_behavior()
	)
	root.add_child(_reward_toggle)

	var delay_row := HBoxContainer.new()
	var delay_label := Label.new()
	delay_label.text = "Delay (s)"
	delay_row.add_child(delay_label)
	_delay_slider = HSlider.new()
	_delay_slider.min_value = 0.05
	_delay_slider.max_value = 2.0
	_delay_slider.step = 0.05
	_delay_slider.value = 0.2
	_delay_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delay_slider.value_changed.connect(func(_v: float) -> void:
		_push_behavior()
	)
	delay_row.add_child(_delay_slider)
	root.add_child(delay_row)

	var btn_row := HBoxContainer.new()
	btn_row.add_child(_make_button("Load rewarded", func() -> void:
		_call_ads("load", ["debug_rewarded", "rewarded", {"provider": "mock"}])
	))
	btn_row.add_child(_make_button("Show rewarded", func() -> void:
		_call_ads("show", ["debug_rewarded", "rewarded", {"provider": "mock"}])
	))
	root.add_child(btn_row)

	var inter_row := HBoxContainer.new()
	inter_row.add_child(_make_button("Load interstitial", func() -> void:
		_call_ads("load", ["debug_interstitial", "interstitial", {"provider": "mock"}])
	))
	inter_row.add_child(_make_button("Show interstitial", func() -> void:
		_call_ads("show", ["debug_interstitial", "interstitial", {"provider": "mock"}])
	))
	root.add_child(inter_row)

	_push_behavior()


func _make_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	return btn


func _push_behavior() -> void:
	if _mock_provider and _mock_provider.has_method("set_behavior"):
		_mock_provider.set_behavior({
			"load_success": _load_success.button_pressed,
			"show_success": _show_success.button_pressed,
			"reward": _reward_toggle.button_pressed,
			"delay_sec": float(_delay_slider.value),
		})


func _get_ads() -> Object:
	if Engine.has_singleton("Ads"):
		return Engine.get_singleton("Ads")
	return null


func _call_ads(method: String, args: Array) -> void:
	var ads := _get_ads()
	if ads and ads.has_method(method):
		ads.callv(method, args)
