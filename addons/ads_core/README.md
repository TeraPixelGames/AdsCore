# AdsCore addon

This plugin ships with the Poing AdMob addon vendored under `addons/admob`, so AdMob runs live on Android/iOS without extra downloads. If you need to update, pull from https://github.com/poingstudios/godot-admob-plugin and replace the folder.

Configure your AdMob App ID in `addons/admob/android/config.gd` (and equivalent iOS config if you add it), then enable the AdMob export plugins in the Godot export settings. If the folder is removed, AdsCore will warn and the AdMob provider falls back to a stub while the HTML5 providers and mock continue to work.***

## Project Settings (AdsCore)

You can configure the plugin from *Project Settings → AdsCore* without touching code:

- **Providers**: `ads_core/providers` (Array). Order and enable the providers; defaults to `["admob", "poki", "crazygames", "lagged", "y8", "mock"]`.
- **General**: `ads_core/general/test_mode` (Bool). Forces AdMob to use Google test unit ids.
- **Consent**: `ads_core/consent/non_personalized`, `ads_core/consent/limit_ad_tracking` (Bool). Adds `npa=1` for AdMob requests.
- **AdMob**:
  - `ads_core/admob/enabled` (Bool).
  - `ads_core/admob/banner_position` (Enum: Top/Bottom/Left/Right/Top Left/Top Right/Bottom Left/Bottom Right/Center).
  - `ads_core/admob/placements` (Dictionary mapping placement name → ad unit id).
  - `ads_core/admob/request_configuration` (Dictionary with AdMob RequestConfiguration fields).
  - `ads_core/admob/test_device_ids` (Array of hashed test device ids).

These settings are read automatically by `Ads.init()`; any values you pass in code override the project settings.
