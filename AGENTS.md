# Repository Guidelines

## Project Structure & Module Organization

Tea Panel is a native SwiftUI/AppKit menu bar app for Apple Silicon and macOS 13+.

- `Sources/TeaCore.swift`: recipes, timer phases, preferences, and migrations.
- `Sources/TeaViews.swift`: SwiftUI panels and controls.
- `Sources/TeaMotion.swift`: transitions and panel animation lifecycle.
- `Sources/TeaPanelApp.swift`: menu bar integration, AppKit windows, and wake handling.
- `Resources/`: active app icon and `Info.plist`.
- `Tests/`: executable regression suites.
- `docs/`: guides, screenshots, design proposals, and verification records.

## Build, Test, and Development Commands

Use Xcode Command Line Tools with Swift 6. Run commands from the repository root:

- `zsh build.sh`: create the ad hoc signed `build/Tea Panel.app`.
- `zsh build.sh --run`: build and launch the app.
- `zsh test.sh`: run core logic checks.
- `zsh test.sh --motion`: run core and window checks; requires a logged-in macOS graphical session.
- `codesign --verify --deep --strict "build/Tea Panel.app"`: verify the built app's signature.
- `git diff --check`: check whitespace errors.

No third-party dependencies or Xcode project setup are required.

## Coding Style & Naming Conventions

Follow existing Swift formatting: four-space indentation, opening braces on declaration lines, `UpperCamelCase` types and filenames, and `lowerCamelCase` members and enum cases. Keep UI and store mutations on `@MainActor`. Reuse `TeaTypography` and `TeaMotion` for consistent presentation. No formatter or linter is configured.

## Testing Guidelines

Tests are standalone `@main` programs using `check` helpers backed by `precondition`. Use `*Tests.swift` filenames and descriptive assertion messages. Isolate preferences in UUID-named `UserDefaults` suites, clean them up, and inject clocks for timer checks.

Add regression checks for behavior changes, especially migrations and panel lifecycle. No coverage percentage is enforced. For UI changes, inspect reminders and Reduce Motion behavior; document environments still awaiting manual verification.

## Commit & Pull Request Guidelines

Use short imperative summaries matching history, such as `Fix hero alignment, readout transitions, and typography`. Keep commits focused. Pull requests should explain the problem, resulting behavior, validation commands and results, and related issues when applicable. Include screenshots for visual changes and update `CHANGELOG.md` for user-visible changes.

## Documentation & Local Data

Keep `README.md` in Simplified Chinese and `README.en-US.md` in American English; synchronize shared behavior descriptions. Preserve saved recipes and migration backups; consult `docs/data-storage.md` before changing persistence. Keep `research/`, build output, installer bundles, caches, and local environment files out of commits. Design proposals remain separate from the active icon in `Resources/`.
