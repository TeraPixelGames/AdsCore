# AdsCore (Godot addon)

AdsCore is a provider-agnostic ads facade for Godot 4. It ships with AdMob (Android/iOS) plus multiple HTML5 portals (Poki, CrazyGames, Lagged, Y8) and a mock provider for local testing.

## Installation
1) Copy the `addons/ads_core` and `addons/admob` folders into your project (this repo already includes both).
2) In Godot, enable the AdsCore plugin in *Project Settings → Plugins*.
3) Ensure the AdMob export plugins are enabled in *Project Settings → Export (Android/iOS) → Plugins* so the native singletons are packaged.

## Quick start
AdsCore auto-initializes using Project Settings. To override or supply runtime config:
```gdscript
Ads.init({
	"providers": ["admob", "poki", "mock"], # order is priority
	"provider_config": {
		"admob": {
			"placements": {
				"default_banner": "ca-app-pub-xxx/banner",
				"default_interstitial": "ca-app-pub-xxx/interstitial",
				"reward": "ca-app-pub-xxx/rewarded"
			},
			"request_configuration": {
				"tag_for_child_directed_treatment": 0,
				"tag_for_under_age_of_consent": 0,
				"max_ad_content_rating": "G"
			},
			"test_device_ids": ["HASHED_TEST_DEVICE_ID"],
			"banner_position": AdPosition.Values.BOTTOM
		}
	},
	"caps": {}, # optional frequency caps
	"test_mode": true, # AdMob uses Google test units when true
	"consent": {"non_personalized": true}
})
```

Show ads:
```gdscript
Ads.load("reward", "rewarded")
Ads.show("reward", "rewarded")
```

Signals (connect on `Ads` autoload): `ad_loaded`, `ad_failed`, `ad_shown`, `ad_closed`, `ad_rewarded`, `ad_clicked`, `ad_impression`, `analytics_event`.

## Project Settings (GUI)
Configure under *Project Settings → AdsCore*; runtime `Ads.init()` overrides these values:
- `ads_core/providers` (Array): Provider order.
- `ads_core/general/test_mode` (Bool).
- `ads_core/consent/non_personalized`, `ads_core/consent/limit_ad_tracking` (Bool).
- `ads_core/admob/enabled` (Bool).
- `ads_core/admob/banner_position` (Enum Top/Bottom/Left/Right/Top Left/Top Right/Bottom Left/Bottom Right/Center).
- `ads_core/admob/placements` (Dictionary placement → ad unit id).
- `ads_core/admob/request_configuration` (Dictionary for RequestConfiguration fields).
- `ads_core/admob/test_device_ids` (Array of hashed test devices).

## Provider specifics

### AdMob (Android/iOS)
- Configure App ID in `addons/admob/android/config.gd` (and iOS equivalent if added).
- Enable AdMob export plugins in platform export settings.
- Placements map to ad unit IDs; `test_mode` swaps in Google test units.
- Consent: setting `non_personalized` or `limit_ad_tracking` adds `npa=1` to requests.
```gdscript
Ads.init({
	"providers": ["admob"],
	"provider_config": {
		"admob": {
			"placements": {
				"default_banner": "ca-app-pub-xxx/banner",
				"default_interstitial": "ca-app-pub-xxx/interstitial",
				"reward": "ca-app-pub-xxx/rewarded",
				"reward_interstitial": "ca-app-pub-xxx/rewarded_interstitial"
			},
			"request_configuration": {
				"tag_for_child_directed_treatment": 0,
				"tag_for_under_age_of_consent": 0,
				"max_ad_content_rating": "G"
			},
			"test_device_ids": ["HASHED_TEST_DEVICE_ID"],
			"banner_position": AdPosition.Values.BOTTOM
		}
	},
	"test_mode": true,
	"consent": {"non_personalized": true}
})
```
Loading/showing:
```gdscript
Ads.load("default_interstitial", "interstitial")
Ads.show("default_interstitial", "interstitial")
```

### Poki (HTML5)
- Requires `Engine.has_singleton("JavaScriptBridge")` and Poki SDK on the page.
- Supports interstitial and rewarded. Calls `PokiSDK.commercialBreak/rewardedBreak`.
**Export step (index.html):** include the Poki SDK before `engine.js` in your exported `index.html`:
```html
<script src="https://game-cdn.poki.com/scripts/v2/poki-sdk.js"></script>
```
Godot does not inject this automatically; add it to your custom export template or post-process your build.
```gdscript
Ads.init({
	"providers": ["poki"],
	"test_mode": false
})
Ads.load("any", "interstitial")
Ads.show("any", "interstitial")
```

### CrazyGames (HTML5)
- Requires CrazyGames SDK injected. Supports interstitial, rewarded, playable via `CrazyGames.SDK.showAd`.
**Export step (index.html):** include the CrazyGames SDK before `engine.js`:
```html
<script src="https://sdk.crazygames.com/crazygames-sdk-v3.js"></script>
```
Add manually or via your export template pipeline.
```gdscript
Ads.init({"providers": ["crazygames"]})
Ads.load("p1", "playable")
Ads.show("p1", "playable")
```

### Lagged (HTML5)
- Requires `laggedAPI`. Supports interstitial and rewarded.
**Export step (index.html):** include Lagged’s API script (replace with the official URL you receive):
```html
<script src="https://lagged.com/api/v2/lagged-api.js"></script>
```
```gdscript
Ads.init({"providers": ["lagged"]})
Ads.load("main", "rewarded")
Ads.show("main", "rewarded")
```

### Y8 (HTML5)
- Requires `y8API`. Supports interstitial and rewarded.
**Export step (index.html):** include Y8’s API script (replace with the official URL you receive):
```html
<script src="https://static.y8.com/api/y8-api.js"></script>
```
```gdscript
Ads.init({"providers": ["y8"]})
Ads.load("menu", "interstitial")
Ads.show("menu", "interstitial")
```

### Mock
- Always available; configurable behavior for testing load/show/reward flows.
```gdscript
Ads.init({
	"providers": ["mock"],
	"provider_config": {
		"mock": {
			"behavior": {
				"load_success": true,
				"show_success": true,
				"reward": true,
				"delay_sec": 0.1
			}
		}
	}
})
Ads.load("fake", "rewarded")
Ads.show("fake", "rewarded")
```

## Notes
- Provider order controls fallback/priority.
- Frequency caps can be provided via `caps` in `Ads.init()` (per placement).
- If AdMob is missing, the provider disables itself and other providers continue to work.***
