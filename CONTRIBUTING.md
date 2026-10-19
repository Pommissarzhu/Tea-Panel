# Contributing to Tea Panel

Tea Panel is a small native macOS app built directly with `swiftc`. The repository has no third-party dependencies or Xcode project to configure.

## Build and run

Use an Apple Silicon Mac, macOS 13 or later, and Xcode Command Line Tools with a Swift 6 compiler and macOS SDK.

```sh
zsh build.sh
zsh build.sh --run
```

The build produces `build/Tea Panel.app`, converts `Resources/AppIcon.png` into an `.icns` file using `sips` and `iconutil`, copies localized app names, and applies an ad hoc signature. The app displays as 茶伴 in Simplified Chinese and Tea Panel in English. Its on-disk bundle name and identifier stay the same so upgrades use the existing installation and preferences. All generated output stays in the ignored `build/` directory.

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

## Releases

The **Build and Release** workflow runs on GitHub's `macos-15` Apple Silicon runner. A pushed `v<version>` tag runs the core suite, builds and signs the app, creates a compressed DMG, verifies the signature and disk image, and publishes the DMG and its SHA-256 checksum to GitHub Releases. The tag must exactly match `CFBundleShortVersionString` in `Resources/Info.plist`; a mismatch stops the workflow before testing or building.

1. Set a new release version and build number in `Resources/Info.plist`, and update `CHANGELOG.md`.
2. Run `zsh test.sh` and `zsh package.sh`. The package contains `Tea Panel.app`, a shortcut to Applications, and the MIT license. Output is written to `dist/`.
3. Commit and push the release source, including `.github/workflows/release.yml` and `package.sh`, then push the matching tag. For version `0.3.9`:

   ```sh
   git tag v0.3.9
   git push origin v0.3.9
   ```

4. Check the workflow in Actions and the assets in Releases. A failed check or build prevents release creation. An existing release is not overwritten; use a new version for subsequent releases.

The workflow uses GitHub's automatic `GITHUB_TOKEN` with `contents: write`; no personal access token or Apple signing secret is required. Enable GitHub Actions for the repository if it is disabled. **Run workflow** provides a manual build that saves the DMG and checksum as an Actions artifact for 14 days without creating a release.

To verify a downloaded installer, keep the DMG and checksum in the same directory and run:

```sh
shasum -a 256 -c Tea-Panel-0.3.9-Apple-Silicon.dmg.sha256
```

The app remains ad hoc signed. Developer ID signing and Apple notarization require separate Apple credentials and are not part of this workflow. CI runs the core suite; the motion suite and interactive macOS checks remain local verification steps.

## Keep changes focused

- Preserve saved recipes, recent drafts, and migration backups when changing the data model. See [Local data and migration](docs/data-storage.md).
- Keep `README.md` in Simplified Chinese and `README.en-US.md` in American English. Update both when shared behavior changes, and keep commands, paths, and identifiers consistent across translations.
- Use the active icon in `Resources/`. The [v3 design proposal](docs/design/proposals/AppIcon-v3.md) remains a proposal.
- Update the [changelog](CHANGELOG.md) for user-visible behavior changes. Documentation-only cleanup does not change the app version.
- Keep generated bundles, disk images, compiler caches, local verification tools, and the local `research/` directory out of commits.

When reporting a bug, include your macOS version, app version, selected preset or recipe, the steps you took, and what you expected to happen.
