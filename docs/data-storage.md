# Local data and migration

Tea Panel stores preferences locally on each platform. It has no account, cloud sync, analytics, or network client. The platforms do not automatically import each other's data.

The macOS app continues to use `UserDefaults` and bundle identifier `local.teapanel.app`. Its keys and migration backups below are unchanged.

## What is saved

- Shared cup capacity and poured water volume.
- The selected built-in tea or custom mode.
- Up to 10 saved tea configurations.
- The latest custom draft, including its name, icon, ratio, temperature, and timing.

The main preference entry is a JSON-encoded `TeaPreferences` value stored under `TeaPanel.preferences.v1`.

Tea configurations do not store cup capacity, poured water volume, or the selected starting infusion. Active rounds, timer deadlines, reminders, and infusion counts stay in memory. Quitting the app ends the round; reopening starts at infusion 1.

## Upgrade backups

When a migration is needed, the app retains the original encoded preference data under the corresponding key before persisting the upgraded settings. Existing backups are preserved on later launches and saves.

| Backup key | Purpose |
| --- | --- |
| `TeaPanel.preferences.beforeTemplateV2` | Preserve preferences from before the earlier template-default upgrade |
| `TeaPanel.preferences.beforeCustomModeV1` | Preserve preferences before edited templates move into custom configurations |
| `TeaPanel.preferences.beforeIndependentBrewV1` | Preserve preferences before cup and water settings become independent of recipes |

The independent-water migration takes cup capacity and volume from the active legacy custom draft when available, retaining saved recipes, their identifiers, and the unsaved draft state. Legacy changes limited to cup capacity or water volume remain shared settings and do not consume a recipe slot.

The 0.3.3 preset update changes built-in defaults while preserving existing custom recipes, the latest draft, and shared water settings. Selecting a built-in preset loads its current defaults.

## Recovery and development

The backup entries contain the earlier JSON data rather than a separate exported file. Before attempting recovery, quit Tea Panel and make a copy of its preferences. A recovery tool must account for the source schema and migration markers; there is currently no recovery or import button in the app.

The core tests cover migration, backup preservation, and relaunch behavior using isolated `UserDefaults` suites. Keep production settings out of tests, screenshots, and repository commits.

## Windows preferences

Windows uses `%LOCALAPPDATA%\TeaPanel\preferences.json`, outside the app's installation or extraction folder. Its schema starts at `schemaVersion: 1` and saves shared capacity and water volume, the selected tea/mode, up to 10 saved configurations, and the latest custom draft. Round identity, deadlines, reminders, and infusion counts stay in memory; restarting begins idle at infusion 1.

JSON is serialized before writing a temporary file in the same directory and replacing the previous file. A save failure retains the previous file and current in-memory edit, with a visible message. Invalid numeric data cannot replace the last successfully saved file.

An unreadable original is copied to `preferences.json.unreadable-<id>.bak` before defaults are used. If the copy fails, the original remains and further writes are blocked for that run. An unsupported schema is left intact and is also protected from writes. No historical macOS migration runs on Windows.

Windows core tests use unique temporary directories. Desktop checks use `build/windows/verification/isolated-preferences/`, with a fresh in-memory store and an injected clock, never the normal Windows preference path. See the [Windows guide](windows-guide.md) and [verification record](windows-verification.zh-CN.md).
