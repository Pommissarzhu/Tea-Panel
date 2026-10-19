# Changelog

This history describes local Tea Panel app versions. The current version is **0.3.8**.

## Unreleased

- Add a Simplified Chinese default README and a matching American English README, with an app screenshot.
- Organize usage guides, product notes, icon design proposals, and verification records under `docs/`.
- Add contributing and preference migration documentation, an MIT license, and broader ignore rules for local output.
- Keep local research material out of the published repository.

## 0.3.8

- Align preset icons and text using a fixed icon column so switching teas preserves the text position.
- Crossfade the dry tea amount and refill duration in a fixed area while keeping the progress ring stationary.
- Display refill durations as `mm:ss`, matching the countdown style.
- Use rounded system typography and monospaced digits, with single-line scaling for long durations.

## 0.3.7

- Show numeric input focus around the full input card and preserve its inner padding.
- Open the menu without automatically editing the water volume.
- End editing when pressing Return, clicking the background, or choosing another action.

## 0.3.6

- Prepare window animation state before app activation so an already visible panel still animates in.
- Unify menu bar open and close handling; use a 0.3-second, 10-point menu entrance.
- Add feedback for input focus, hovering, repeated saves, validation messages, recipe changes, and quitting.
- Animate user-adjusted values while keeping the live countdown direct.

## 0.3.5

- Add the flat sage and forest-green app icon for Finder and other system surfaces.
- Keep the menu bar symbol tied to the active tea configuration.

## 0.3.4

- Add short entrance and dismissal animations to menu and reminder panels.
- Add lightweight transitions for selections, settings, phases, the progress ring, and buttons.
- Protect panels against repeated dismissal and reopening during an exit animation.
- Use short fades when Reduce Motion is enabled.

## 0.3.3

- Update the three built-in cup-brewing presets and add 30 seconds per infusion.
- Round suggested dry tea amounts to one decimal place.
- Preserve existing custom recipes, drafts, and shared water settings.

## 0.3.2

- Use controls suited to each value: infusion buttons, a temperature slider and shortcuts, and minute/second menus.
- Preserve existing valid values when opening settings.

## 0.3.1

- Allow cooling to be skipped before starting, during cooling, or before a refill.
- Start the current infusion's full steeping timer without changing the saved recipe.
- Prevent repeated starts once steeping has begun.

## 0.3.0

- Separate cup capacity and poured water volume from tea recipes.
- Allow a session to start at a selected infusion from 1 to 99.
- Preserve recipes and drafts while migrating the active draft's water settings into shared preferences.
- Back up the original preferences under `TeaPanel.preferences.beforeIndependentBrewV1`.

## 0.2.3

- Replace the pointed popover with an independent rounded menu panel.
- Position the menu when it opens and keep its location fixed during changes.
- Dismiss on Escape or when switching to another app; use a consistent 18 × 18 pt menu bar icon canvas.
- Supersede the popover anchor adjustments attempted in 0.2.1 and 0.2.2.

## 0.2.0

- Keep built-in presets intact and move edited recipes into custom configurations.
- Save up to 10 configurations with custom names and icons, plus the latest unsaved draft.
- Preserve earlier preferences under `TeaPanel.preferences.beforeCustomModeV1`, alongside the older `TeaPanel.preferences.beforeTemplateV2` backup.
