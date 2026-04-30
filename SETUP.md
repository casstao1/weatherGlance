# SkyGlance Setup Guide

## Prerequisites
- Xcode 15+ (iOS 17 SDK)
- Apple Developer account for device/widget signing
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Step 1 — Select your Team

The project now leaves the development team unset in `project.yml`, so Xcode
can use the Apple account currently signed into your machine. Pick your team in
Signing & Capabilities for both targets after opening the project.

Also update the App Group in both `.entitlements` files:
- `SkyGlance/SkyGlance.entitlements`
- `SkyGlanceWidget/SkyGlanceWidget.entitlements`

Replace `group.com.castao.weatherGlance` if you change the bundle prefix.

## Step 2 — Generate the Xcode project

```sh
cd /path/to/SkyGlance
xcodegen generate
```

This creates `SkyGlance.xcodeproj`. Open it in Xcode:

```sh
open SkyGlance.xcodeproj
```

## Step 3 — Optional: Enable WeatherKit capability

SkyGlance uses Open-Meteo by default. Only enable WeatherKit if you want to test
Apple WeatherKit as a provider:
1. Select the **SkyGlance** target → Signing & Capabilities
2. Click **+ Capability** → add **WeatherKit**
3. Repeat for the **SkyGlanceWidget** target

WeatherKit also requires enabling it in your App ID on
[developer.apple.com](https://developer.apple.com/account/resources/identifiers/list).

To force WeatherKit at runtime for testing, add the launch argument
`-skyglanceEnableWeatherKit` or the environment variable
`SKYGLANCE_ENABLE_WEATHERKIT=1`.

## Step 4 — Build & Run

Select an iPhone simulator running iOS 17+ and press ⌘R.

To test widgets:
- Run on a physical device (widgets require a signed build)
- Long-press the home screen → Edit → Add Widget → search "SkyGlance"
- Lock screen widgets: Settings → Wallpaper → Customize → add a widget

## Project Structure

```
SkyGlance/
  SkyGlance/                ← Main app target
    Models/                  Data types
    Theme/                   Mood-based color system
    Icons/                   Minimal Line v2 SwiftUI icons
    Components/              HourColumnView, ForecastStripView, InlineSummaryView
    Data/                    WeatherService, TimelineMapper, HourLabelFormatter
    App/                     App entry point + ContentView

  SkyGlanceWidget/          ← Widget extension target
    Widgets/                 All 6 widget configurations + WidgetBundle

  project.yml              ← xcodegen config
```

## Widget Inventory

| Kind | Family | Layout |
|------|--------|--------|
| GlanceInlineWidget | accessoryInline | Single-line summary |
| GlanceCircularWidget | accessoryCircular | Compact current conditions |
| GlanceLockScreen6HWidget | accessoryRectangular | Now + 5 hours (6 cols) |
| GlanceLockScreen5HWidget | accessoryRectangular | Now + 4 hours (5 cols) |
| GlanceHomeSmallWidget | systemSmall | Icon + temp + 3 hours |
| GlanceHomeMedium6HWidget | systemMedium | 6-hour strip |
| GlanceHomeMedium5HWidget | systemMedium | 5-hour strip |

## Moods

The UI adapts automatically to the current weather:

| Condition | Mood | Feel |
|-----------|------|------|
| Sunny / Mostly Sunny | warm | Amber / sand tones |
| Rain / Heavy Rain | dark | Deep charcoal / slate |
| Cloudy / Partly Cloudy | neutral | Soft graphite |
| Snow | cool | Icy blue-gray |
