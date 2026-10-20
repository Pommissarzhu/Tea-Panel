# Windows usage and build guide

[简体中文](windows-guide.zh-CN.md) · [Project home](../README.en-US.md)

The Windows app is a native C# / WPF tray application targeting Windows 11 x64. Presets, dose calculations, staged timers, custom configurations, and refill rules match macOS.

The panel follows the Mac app's 384 × 668 logical content size, illustrated tea cards, infusion badge, paired input cards, and fixed footer. Windows uses local system fonts and vector artwork with the same meaning.

## Launch and tray behavior

Download `Tea-Panel-0.4.2-Windows-x64.exe` from the [v0.4.2 Release](https://github.com/Pommissarzhu/Tea-Panel/releases/tag/v0.4.2) and double-click it. Only this EXE is needed: the .NET runtime is included, with no extraction, separate .NET installation, or adjacent DLLs required. The same Release also provides the macOS DMG and checksums for both platforms.

When updating, quit the old version from the tray before running the new EXE. Existing local settings are retained.

The app uses official .NET single-file packaging. A few native dependencies are automatically extracted to a temporary cache at runtime, without manual steps. See [single-file deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview#native-libraries).

- The main panel opens once at launch. Left-click the tray icon to toggle it afterward.
- The icon may be inside the notification area's overflow menu. Its tooltip shows the tea name, phase, and remaining time.
- Right-click for Open and Quit. Esc, switching apps, or closing the main panel only hides it; quitting ends the session.
- Only one application instance and one brewing round run at a time.

![Native Windows main panel](images/windows-brewing-panel.png)

## Brewing and configurations

1. Select a tea, water volume, and starting infusion. Change cup capacity in Settings; capacity and volume both default to 330 mL.
2. Start cooling after pouring water. Add leaves when prompted, then confirm to start steeping. Tieguanyin starts steeping directly by default.
3. If the water is ready, skip cooling to start a full steeping timer from that moment.
4. Remove the infuser or pour out the tea when ready, then acknowledge the card. Choose refill to reuse the same leaves, and start when fresh water is ready.
5. Fresh leaves or End round resets infusion to 1. Quitting does not preserve active timers.

Settings includes name, icon, water-to-tea ratio, reference temperature, and timing. Like macOS, separate minute and second menus preserve the other component when edited, including nonstandard saved seconds. The minimum first-steep duration and maximum durations still apply. Numeric edits commit on focus loss or Return. Unparseable values display validation feedback and block starting a timer.

Custom opens its parameter page directly, with a nearby shortcut to save or update. The compact saved-count menu lists configurations with icons and returns to brewing when a configuration is chosen; an empty menu explains that no configurations have been saved.

Editing tea parameters creates a custom draft. Save adds it to the list, with a maximum of 10 configurations and support for update, save-as, and deletion. Cup capacity, water volume, and starting infusion are independent of recipes. Invalid water blocks brewing but does not prevent saving an otherwise valid tea configuration.

The current round retains its name, icon, water, and dry tea amount. Its planned steeping duration also remains fixed. Timing changes apply to the next infusion; other configuration changes apply to the next round. See the [shared brewing rules](guide.md) for default values and examples.

## Reminders and display

When time is up, a topmost card appears near the top of the monitor containing the pointer. It stays until acknowledged or the round is ended, without sound or proactively taking input focus. Preview does not start a timer or replace an outstanding real reminder.

![Persistent Windows reminder](images/windows-reminder.png)

Windows uses a tray icon, tooltip, and panel countdown rather than persistent Mac menu bar text. Cooling is a fixed timer, not a measurement of water temperature.

Timers use real deadlines, including time spent asleep or locked, and refresh after resume or unlock. Cards need not appear on the lock screen. See the [verification record](windows-verification.zh-CN.md) for display scaling, multiple-monitor, and full-screen coverage.

Tea selections fade between highlights. Dose and infusion changes crossfade and slightly move the large readout while the ring stays fixed. Settings pages and dropdowns fade in, and buttons respond to hovering and pressing. Countdown ticks update directly while the timed ring advances smoothly. Cooling, adding leaves, and steeping have stage indicators; an inactive ring only shows its pale outline.

With system animations disabled, windows and content use short fades without movement or scaling. Open the panel through the tray and use Tab to navigate controls; keyboard focus uses a rounded outline. Escape first closes an open dropdown, then hides the panel.

## Local settings

Settings live at `%LOCALAPPDATA%\TeaPanel\preferences.json`, independently of the EXE's location. Only shared cup settings, current mode, saved configurations, and the latest draft persist. Timers, reminders, and infusion counts stay in memory.

Save failures retain the existing file and in-memory edit with a message. Unreadable originals are copied to `.unreadable-<id>.bak` in the same directory. Other schema versions are not overwritten. The platforms do not automatically synchronize or import each other's settings; see [Local data](data-storage.md).

## Development commands

Building needs the .NET 10 SDK, without a full Visual Studio installation. Scripts support Windows PowerShell 5.1 and PowerShell 7. From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1 -Run
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1 -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File windows/package.ps1
```

`build.ps1` creates `build/windows/app/TeaPanel.exe`. Scripts first use `TEA_PANEL_DOTNET`, then an optional repository-local `build/tools/dotnet/dotnet.exe`, then the SDK on PATH.

The default suite checks core behavior and storage. `-Desktop` adds real WPF window checks using isolated data and an injected clock. Reports and screenshots go to `build/windows/verification/`; tests preserve the user's real Tea Panel settings and system animation setting.

Packaging creates `dist/Tea-Panel-0.4.2-Windows-x64.exe` and `.exe.sha256`; the checksum file is optional for running the app. Beyond the app there is one lightweight core test project, with no database, background service, or third-party application package.

## GitHub Actions builds

The Windows job in **Build and Release** calls the same `windows/package.ps1`, checks that output contains only the EXE and checksum, and verifies SHA-256. Manual runs only create build artifacts; pushing a matching version tag creates a Release.

GitHub's website wraps the Windows artifact in a ZIP containing the standalone EXE and `.exe.sha256`. Use `gh run download` to retrieve the files directly, as described in [Contributing](../CONTRIBUTING.md#releases). Release assets provide the EXE directly, with no DLL downloads or .NET installation needed.
