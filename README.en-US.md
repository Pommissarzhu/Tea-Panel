<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="Tea Panel app icon">
</p>

<h1 align="center">Tea Panel</h1>

<p align="center">A quiet tea brewing companion for your Mac's menu bar.</p>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English (US)</strong>
</p>

<p align="center">macOS 13+ · Apple Silicon · Swift 6 · MIT</p>

Tea Panel helps you brew a cup of tea while you work. Set your water volume, check the suggested amount of dry tea, and follow the cooling and steeping timers. When it's time to add leaves or remove your infuser, a silent floating card stays visible until you respond.

The app's current interface and default README are in **Simplified Chinese**. This version uses American English; both language versions describe the same app.

<p align="center">
  <img src="docs/images/brewing-panel.png" width="384" alt="Tea Panel showing the gardenia green tea preset, 330 mL of water, and a suggested 6.6 g of dry tea">
</p>

## Features

- **Three built-in presets:** gardenia green tea, Tieguanyin oolong, and jasmine green tea.
- **Tea amounts that match your cup:** calculate dry tea from your water volume and preferred ratio.
- **Cooling and steeping stages:** confirm when you add the leaves, or skip cooling when you're ready to brew.
- **Refill support:** reuse the same leaves, add time with each infusion, and start at any infusion from 1 to 99.
- **Persistent, silent reminders:** see the countdown in the menu bar and act on a floating reminder when time is up.
- **Your own recipes:** save up to 10 configurations with custom names, icons, ratios, temperatures, and timing.
- **Local preferences:** cup settings, saved recipes, and the latest draft stay on your Mac. The app makes no network requests.
- **Native interface:** SwiftUI and AppKit, with Reduce Motion support and no third-party dependencies.

## Quick start

### Requirements

- A Mac with **Apple Silicon** running **macOS 13 Ventura or later**.
- Xcode Command Line Tools with a **Swift 6** compiler and the macOS SDK.

If Command Line Tools aren't installed, run `xcode-select --install` first.

Clone or download this repository, open a terminal in its root directory, and run:

```sh
zsh build.sh --run
```

The script builds and opens `build/Tea Panel.app`. You can also build with `zsh build.sh` and open the app yourself, or copy it to your Applications folder. The menu opens on launch; click its menu bar icon to open it again.

The build script currently targets `arm64` and signs the app ad hoc. Distributing a Developer ID signed, notarized app requires a separate release process.

## Brew your first cup

1. Choose a tea preset and enter the amount of water you'll actually pour. The default is 330 mL.
2. Fill your cup and click **已接水，开始晾水** to start cooling.
3. When the reminder appears, add the suggested amount of tea and click **已投茶，开始泡茶** to start steeping.
4. When the tea is ready, remove the infuser or pour out the tea, then acknowledge the reminder.
5. Choose **续泡** for another infusion, or **换新茶叶** to start over with fresh leaves.

Tieguanyin skips cooling by default: add the leaves and water before starting its steeping timer. For other presets, **跳过晾水，直接泡茶** starts a full steeping timer immediately.

Use **预览提醒** to see a reminder without starting or changing a timer. See the [usage guide](docs/guide.md) for custom recipes, refill behavior, and timing details.

## Built-in presets

These presets are starting points for brewing in a cup. Adjust them for your tea and taste.

| Tea | Reference water temperature | Dry tea per 200 mL | Cooling delay | First steep | Added per infusion |
| --- | --- | --- | --- | --- | --- |
| Gardenia green tea | 80°C | 4 g | 3 min | 3 min | 30 sec |
| Tieguanyin oolong | 100°C | 5 g | Skip | 1 min | 30 sec |
| Jasmine green tea | 85°C | 4 g | 2 min | 3 min | 30 sec |

At 330 mL, the suggested amounts are **6.6 g**, **8.3 g**, and **6.6 g**, respectively. Amounts are rounded to one decimal place.

Cooling is a fixed timer, not a temperature measurement. The temperature setting is a reference, and a timer cannot stop the leaves from steeping: remove them when the reminder appears.

## Development

```sh
zsh build.sh          # Build build/Tea Panel.app
zsh build.sh --run    # Build and launch
zsh test.sh           # Run core logic checks
zsh test.sh --motion  # Also run window and menu bar checks; requires a macOS GUI session
```

The current suites contain **193 core checks** and **68 motion and menu bar checks**. Full-screen behavior, multiple displays, and physical sleep/wake interactions still need hands-on verification. See [Contributing](CONTRIBUTING.md) for the source map and validation scope.

```text
.
├── Sources/          # SwiftUI views, AppKit integration, timer logic, and motion
├── Resources/        # App metadata and the active app icon
├── Tests/            # Core and window regression checks
├── docs/             # Usage guides, screenshots, design notes, and verification records
├── build.sh          # Local app build
└── test.sh           # Local test runner
```

Generated apps, disk images, compiler caches, and local settings are excluded from Git.

## Documentation

| Document | Contents |
| --- | --- |
| [Usage guide](docs/guide.md) / [使用指南](docs/guide.zh-CN.md) | Water settings, recipes, infusions, and reminders |
| [Changelog](CHANGELOG.md) | App version history |
| [Contributing](CONTRIBUTING.md) | Building, testing, and making changes |
| [Local data and migration](docs/data-storage.md) | Preferences and upgrade backups |
| [Product plan](docs/product-plan.zh-CN.md) | Original product decisions, in Chinese |
| [Verification history](docs/verification.zh-CN.md) | Earlier local test and UI inspection records, in Chinese |
| [Icon design](docs/design/app-icon.zh-CN.md) | Active icon provenance and a separate design proposal |

Quitting the app ends the active brewing session. Saved preferences remain available when you reopen it; active timers do not resume.

## License

Tea Panel's original source code, documentation, and app artwork are available under the [MIT License](LICENSE).
