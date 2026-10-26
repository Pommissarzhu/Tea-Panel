# Usage guide

Core brewing rules are shared by both platforms. Control descriptions below use macOS; see the [Windows guide](windows-guide.md) for tray behavior, timing dropdowns, and build commands.

**English (US)** | [简体中文](guide.zh-CN.md)

[Back to Tea Panel](../README.en-US.md)

## Water volume and dry tea

Cup capacity and poured water volume are shared across all presets and saved recipes. Both default to 330 mL. Set your actual water volume on the main screen; change cup capacity under **我的杯子** in the settings panel.

The app approximates 1 mL of water as 1 g and calculates:

```text
dry tea (g) = poured water (mL) / water-to-dry-tea ratio
```

The ratio field uses **water : dry tea**. The gardenia preset uses `165 : 1`, giving 2.0 g for 330 mL. Jasmine uses `50 : 1`, giving 6.6 g for 330 mL; Tieguanyin uses `40 : 1`, giving 8.25 g, displayed as 8.3 g. For gardenia tea, weigh the whole dry mixture, including the flowers and green tea.

Changing cup capacity, water volume, or the starting infusion keeps your current recipe selected. At the start of a session, the app records its water volume, dry tea amount, recipe name, and icon. Water changes made during that session apply to the next session with fresh leaves.

## Cooling and steeping

For gardenia or jasmine tea:

1. Pour the water and choose **已接水，开始晾水**.
2. When cooling ends, add the leaves and choose **已投茶，开始泡茶**.
3. When steeping ends, remove the infuser or pour out the tea and acknowledge the reminder.

Steeping begins when you confirm that you added the leaves. Time spent waiting for that confirmation does not count toward steeping.

Gardenia cools for 2 minutes and steeps for 2 minutes on the first infusion. Jasmine cools for 2 minutes and steeps for 3 minutes on the first infusion.

Tieguanyin has no cooling delay by default. Prepare the leaves and water, then choose **已注水，开始泡茶**.

### Skip cooling

Choose **跳过晾水，直接泡茶** before a session, during cooling, or while preparing a refill. This starts the selected infusion's full steeping timer from the moment you click. It preserves the recipe's cooling setting for future use and does not estimate how long the leaves may already have been in the water.

The action is hidden during steeping so it cannot restart a running timer.

## Infusions and refills

Select the starting infusion on the main screen before beginning. If you've already brewed twice, select infusion 3. The app calculates:

```text
steeping time = first steep + (infusion number - 1) × added time
```

All three built-in presets add 30 seconds per infusion:

| Tea | Infusion 1 | Infusion 2 | Infusion 3 | Infusion 4 |
| --- | --- | --- | --- | --- |
| Gardenia green tea | 2:00 | 2:30 | 3:00 | 3:30 |
| Tieguanyin oolong | 1:00 | 1:30 | 2:00 | 2:30 |
| Jasmine green tea | 3:00 | 3:30 | 4:00 | 4:30 |

For later infusions, reuse the original leaves. The reminder asks you to put them back rather than add another dose of dry tea. When cooling fresh water for a refill, keep the leaves in a removed infuser or cool the water in another cup first.

Choose **续泡** when you're ready for another cup; the app waits for you to start. An infusion counts only when steeping begins. Cooling time stays the same across infusions.

The starting infusion can be selected from 1 to 99 and is kept only for the current app session. Switching presets or saved configurations preserves the selected number. **换新茶叶** and **结束本轮** reset it to 1 and keep your water settings. Later infusions may taste weak even with extra time; replace the leaves when needed.

## Custom recipes

The three built-in presets keep their defaults. Editing a tea parameter creates a draft labeled **自定义 · 未保存**. Tea parameters include the name, icon, water ratio, reference temperature, cooling time, first steeping time, and added time per infusion.

1. Start from a preset and edit its settings, or choose **自定义** to return to your latest draft.
2. Give it a name and choose one of 10 icons in settings.
3. Choose **保存** to add it to the saved list, then use **已存 n/10** to load it later.
4. After editing a saved configuration, choose **更新** to replace it or **另存为新配置** to save another one.

You can save up to 10 configurations. At the limit, update or delete an existing configuration before adding another. Deleting a saved configuration retains its current values as an unsaved draft.

The app automatically keeps the latest draft. Choosing a built-in preset restores that preset's defaults and retains shared water settings and the selected starting infusion. Presets and saved configurations can be switched after ending the active brewing session.

During a session, water volume, ratio, name, and icon remain attached to that session. Timing edits can apply to the next infusion; the active countdown retains its original deadline.

## Controls and reminders

- Infusion number: minus and plus buttons.
- Reference temperature: 50–100°C in 5°C steps, with shortcut buttons.
- Cooling delay: minute and second menus, with 30-second choices.
- First steep and added time: minute and second menus, with 15-second choices.
- Cup capacity, water volume, and ratio: direct numeric input with units.

Existing second values outside the menu's usual steps remain intact when you open settings. Focusing an input without changing its value preserves the current preset.

**预览提醒** shows a sample reminder and leaves real timing unchanged. Real reminders stay visible until you respond. They are silent, and the reminder panel is designed to leave keyboard focus with your current app.

Timers use deadlines, so elapsed time during sleep still counts. On wake, the app checks for an overdue reminder. Quitting ends the active session; reopening retains your preferences and begins with infusion 1. Full-screen, multiple-display, and physical sleep/wake behavior still need hands-on verification.

Reference temperatures and cooling delays are adjustable starting points. Tea Panel does not measure water temperature or stop extraction. Remove the infuser when steeping ends, and let the tea cool as needed before drinking.

See [Local data and migration](data-storage.md) for preference storage and upgrade backups.
