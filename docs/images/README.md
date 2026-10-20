# App screenshot

`brewing-panel.png` shows the native SwiftUI menu view in version 0.3.9 with the Chinese app name 茶伴 and a fresh, isolated preferences suite: gardenia tea, 330 mL water, infusion 1, and 6.6 g of dry tea.

The image was captured from `TeaMenuView` with AppKit bitmap rendering. It contains the actual app view, without a desktop background or a user's saved recipes. Its native size is 768 × 1336 pixels; the READMEs display it at 384 pixels wide.

`windows-brewing-panel.png` and `windows-reminder.png` show the native WPF 0.4.2 main panel and ready reminder. They were exported by the Windows desktop checks through `RenderTargetBitmap` from live windows at 200% scaling, using isolated preferences and an injected clock. The main image crops the transparent shadow margin to match the Mac content frame. They include no desktop background or real saved recipes. Their sizes are 768 × 1336 and 920 × 640 pixels.

`windows-configuration-dropdown.png` and `windows-timing-dropdown.png` show the 0.4.2 rounded native selectors. These were captured from each live WPF popup's root visual, with the same isolated test data and scaling.

`windows-settings.png` and `windows-settings-timing.png` show the top and bottom of the same parameter page, including the cup cards, icon picker, temperature controls, and three paired minute/second menus. They use the same capture method and isolated data.
