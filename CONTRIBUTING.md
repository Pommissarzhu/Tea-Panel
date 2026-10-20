# Contributing to Tea Panel

Tea Panel has two small native applications: SwiftUI/AppKit on macOS and C#/WPF on Windows. They share product rules and artwork, with separate platform source trees and no third-party application dependencies.

## Build and run

### macOS

Use an Apple Silicon Mac, macOS 13 or later, and Xcode Command Line Tools with a Swift 6 compiler and macOS SDK.

```sh
zsh build.sh
zsh build.sh --run
```

The build produces `build/Tea Panel.app`, converts `Resources/AppIcon.png` into an `.icns` file using `sips` and `iconutil`, copies localized app names, and applies an ad hoc signature. The app displays as 茶伴 in Simplified Chinese and Tea Panel in English. Its on-disk bundle name and identifier stay the same so upgrades use the existing installation and preferences. All generated output stays in the ignored `build/` directory.

### Windows

Use Windows 11 x64 with the .NET 10 SDK and PowerShell 5.1 or 7. A full Visual Studio installation is optional.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1 -Run
```

The output is `build/windows/app/TeaPanel.exe`. Scripts can use `TEA_PANEL_DOTNET`, an optional `build/tools/dotnet/dotnet.exe`, or the SDK on PATH. The WPF process owns DPI awareness through its manifest; WinForms is used only for the tray component, so its WFO0003 startup warning is suppressed specifically. Normal builds exclude the desktop test runner and its entry point.

## Source map

| File | Responsibility |
| --- | --- |
| `Sources/TeaCore.swift` | Presets, quantities, timer phases, custom recipes, preferences, and migrations |
| `Sources/TeaViews.swift` | Menu panel, inputs, recipe settings, and reminder cards |
| `Sources/TeaMotion.swift` | Shared transitions, button feedback, and interruptible panel animations |
| `Sources/TeaPanelApp.swift` | Menu bar item, AppKit panels, timer updates, and wake handling |
| `Resources/Info.plist` | App identity, version, and minimum macOS version |
| `Resources/*.lproj/InfoPlist.strings` | Localized app names and copyright notices |
| `Tests/TeaCoreTests.swift` | Logic checks with isolated preferences and a controlled clock |
| `Tests/TeaMotionTests.swift` | Window lifecycle, menu bar action routing, and motion checks |
| `windows/TeaPanel/TeaCore.cs` | Windows models, bindable store, quantities, and timer state machine |
| `windows/TeaPanel/PreferenceStorage.cs` | Local JSON preferences and recovery |
| `windows/TeaPanel/*Window.xaml` and `.xaml.cs` | Native menu, settings, and reminder views |
| `windows/TeaPanel/TrayHost.cs`, `NativeDesktop.cs`, `PanelMotion.cs` | Tray, system events, positioning, and window lifecycle |
| `windows/TeaPanel/TeaMotion.cs`, `Styles.xaml` | Shared control feedback, content transitions, readout crossfades, and native control templates |
| `windows/Tests/` | Core/storage checks and native desktop probes |

## Validate a change

```sh
zsh -n build.sh
zsh -n test.sh
zsh -n package.sh
zsh test.sh
zsh test.sh --motion
zsh build.sh
codesign --verify --deep --strict "build/Tea Panel.app"
git diff --check
```

On Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1 -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/package.ps1
git diff --check
```

The Windows core suite links the production core/storage sources into a standalone executable. `-Desktop` additionally compiles the app with `TeaPanelTesting=true` and uses real WPF windows, an injected clock, and isolated settings under `build/windows/verification/`. Its layout fixture holds the menu open during render checks, then separately enables and verifies real focus-loss dismissal. Reminder checks compare native foreground and keyboard-focus handles; these checks do not simulate physical typing or sleep.

`--motion` also runs the core suite. It requires a logged-in macOS graphical session and creates temporary panels and a menu bar item. Run it locally when changing views, window behavior, or animations.

The tests use separate `UserDefaults` suites and remove those suites afterward. Keep that isolation when adding checks so tests preserve the user's actual recipes and active session. The normal app still uses its standard preferences; opening it is separate from running tests.

For a UI change, inspect the actual result as well as the automated checks. Include the affected state, reminder behavior, and Reduce Motion behavior in the pull request description.

## Verification record

The repository cleanup was checked locally on **October 19, 2026**, using **Apple Swift 6.4** on Apple Silicon:

- 193 core logic checks passed.
- 68 motion and menu bar checks passed.
- The app built successfully, and its ad hoc signature verified.

The deployment target is macOS 13; this run does not establish behavior on every supported macOS version. Full-screen apps, multiple displays, physical sleep/wake interactions, real mouse tracking of the menu bar, and the system's actual Reduce Motion toggle still need hands-on verification. The motion suite injects the Reduce Motion preference without changing system settings.

Earlier manual checks and native rendering probes are documented in the [verification history](docs/verification.zh-CN.md).

The Windows implementation passed 92 core/storage checks and 78 native desktop checks on October 19, 2026, using .NET SDK 10.0.402 and runtime 10.0.13 on Windows build 26300 at 200% scaling. The Windows build had no warnings or errors. See the [Windows verification record](docs/windows-verification.zh-CN.md) for artifacts and remaining manual scenarios. The macOS results above are historical; this Windows session did not rerun them.

## Releases

The **Build and Release** workflow has independent `macos-15` and `windows-latest` jobs. Each runs its core suite and packages its platform output. Windows calls the same `windows/package.ps1` used locally, verifies that the artifact contains only the standalone EXE and its matching checksum, and records the size and SHA-256 in the job summary. A single dependent job then publishes the DMG, self-contained single-file Windows EXE, and checksums to the same GitHub Release. Manual runs save both artifacts for 14 days without creating a release. Remote results are recorded in [Actions](https://github.com/Pommissarzhu/Tea-Panel/actions/workflows/release.yml); local checks do not establish macOS CI results.

To build without publishing a release, use GitHub CLI:

```sh
gh workflow run release.yml --ref main
gh run list --workflow release.yml --event workflow_dispatch --limit 5
```

After choosing the completed run ID, download its Windows files:

```sh
gh run download RUN_ID --name Tea-Panel-0.4.2-Windows-x64 --dir build/actions-windows
```

Replace `RUN_ID` with that run's numeric ID. The downloaded directory contains only `Tea-Panel-0.4.2-Windows-x64.exe` and `.exe.sha256`. The GitHub website wraps an Actions artifact in a ZIP for download; that wrapper is separate from application packaging. `gh run download` extracts it automatically. Tag-triggered Release assets expose the EXE and checksum as separate downloads.

1. Keep `CFBundleShortVersionString` in `Resources/Info.plist` and `Version` in `windows/TeaPanel/TeaPanel.csproj` identical; update the macOS build number and `CHANGELOG.md`. The workflow checks both versions against the tag.
2. On their respective platforms, run `zsh test.sh`, `zsh package.sh`, and the Windows test/package commands above. Both packages contain the MIT license. Run interactive desktop checks locally for UI changes.
3. Commit and push the release source, then the matching tag. For source version `0.4.2`:

   ```sh
   git tag v0.4.2
   git push origin v0.4.2
   ```

4. Check the workflow in Actions and the assets in Releases. A failed check or build prevents release creation. An existing release is not overwritten; use a new version for subsequent releases.

The workflow uses GitHub's automatic `GITHUB_TOKEN`; no personal access token or Apple signing secret is required. Existing releases are not overwritten. Windows 0.4.2 has not been published yet.

To verify a downloaded installer, keep the DMG and checksum in the same directory and run:

```sh
shasum -a 256 -c Tea-Panel-0.4.2-Apple-Silicon.dmg.sha256
```

For Windows, compare `Get-FileHash -Algorithm SHA256` against the matching `.exe.sha256` file. The single EXE includes the runtime, native WPF libraries, and embedded MIT license; no adjacent DLLs are needed. The Mac app remains ad hoc signed; the Windows executable is unsigned. CI runs core suites; motion and interactive checks remain local verification steps.

## Keep changes focused

- Preserve saved recipes, recent drafts, and migration backups when changing the data model. See [Local data and migration](docs/data-storage.md).
- Keep `README.md` in Simplified Chinese and `README.en-US.md` in American English. Update both when shared behavior changes, and keep commands, paths, and identifiers consistent across translations.
- Use the active icon in `Resources/`. The [v3 design proposal](docs/design/proposals/AppIcon-v3.md) remains a proposal.
- Update the [changelog](CHANGELOG.md) for user-visible behavior changes. Documentation-only cleanup does not change the app version.
- Keep generated bundles, disk images, compiler caches, local verification tools, and the local `research/` directory out of commits.

When reporting a bug, include your macOS version, app version, selected preset or recipe, the steps you took, and what you expected to happen.
