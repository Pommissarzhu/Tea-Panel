using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace TeaPanel;

// Compiled only with TeaPanelTesting=true. Normal builds contain neither this runner
// nor its command-line entry point. No production preferences or system settings are used.
internal static class DesktopChecks
{
    [StructLayout(LayoutKind.Sequential)]
    private struct GuiThreadInfo
    {
        public uint Size, Flags;
        public IntPtr Active, Focus, Capture, MenuOwner, MoveSize, Caret;
        public int Left, Top, Right, Bottom;
    }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo information);
    private readonly record struct FocusSnapshot(IntPtr Foreground, IntPtr Keyboard);
    private static FocusSnapshot ReadFocus()
    {
        var information = new GuiThreadInfo { Size = (uint)Marshal.SizeOf<GuiThreadInfo>() };
        if (!GetGUIThreadInfo(0, ref information)) throw new System.ComponentModel.Win32Exception();
        return new(NativeDesktop.GetForegroundWindow(), information.Focus);
    }

    internal static async Task Run(Application app, string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);
        var checks = new List<string>();
        var motionFrames = new List<MotionFrame>();
        bool systemAnimations = SystemParameters.ClientAreaAnimation;
        TeaMotion.AnimationPreferenceOverride = true;
        TrayHost? host = null;
        Window? inputWindow = null;
        Window? motionWindow = null;
        Exception? dispatcherFailure = null;
        app.DispatcherUnhandledException += (_, args) => { dispatcherFailure = args.Exception; args.Handled = true; };
        void Check(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
            checks.Add(message);
        }
        static void Click(ButtonBase button) => button.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));
        static void Edit(TextBox box, string value)
        {
            box.Text = value;
            box.GetBindingExpression(TextBox.TextProperty)!.UpdateSource();
        }
        int result = 1;
        try
        {
            var now = DateTimeOffset.FromUnixTimeSeconds(1_800_000_000);
            var storage = new PreferenceStorage(Path.Combine(outputDirectory, "isolated-preferences"));
            var store = new TeaStore(now: () => now, save: storage.Save);
            bool quitRequested = false;
            host = new(store, () => quitRequested = true);
            host.HoldMenuForLayoutChecks = true;
            Check(host.IsTrayVisible, "Real NotifyIcon is registered for this test process");
            host.ShowMenu();
            var menu = host.Menu;
            Check(await ObserveMotion(menu, menu.PanelBody, outputDirectory, "menu-entrance", motionFrames), "Menu entrance renders changing intermediate frames");
            Check(menu.IsVisible && host.IsMenuPresented, "Menu opens through the tray controller");
            Check(menu.PanelBody.Opacity > 0.99, "Menu entrance reaches full opacity");
            Check(!menu.WaterInput.IsKeyboardFocused && FocusManager.GetFocusedElement(menu) == menu.PanelBody, "Opening menu does not focus numeric input");
            Check(menu.HeroValue.Text == "6.6", "Default dose renders in the WPF readout");
            Capture(menu, Path.Combine(outputDirectory, "windows-brewing-panel.png"));
            Check(HasInk(menu.HeroValue), "Readout font produces visible glyph pixels");
            Check(!menu.ShowInTaskbar && menu.Topmost, "Menu remains a floating tray panel");
            Check(menu.PanelBody.ActualWidth == 384 && menu.PanelBody.ActualHeight == 668,
                "Main panel matches the 384 by 668 macOS content frame");
            Check(menu.MainScroll.ScrollableHeight < 1, "Default brewing page fits without scrolling");
            Check(Math.Abs(menu.WaterCard.ActualHeight - menu.InfusionCard.ActualHeight) < 0.1
                && Math.Abs(menu.WaterCard.ActualWidth - menu.InfusionCard.ActualWidth) < 0.1,
                "Water and infusion controls are equal cards");
            Check(menu.HeroUnit.Text == "克" && menu.HeroUnit.TranslatePoint(new Point(), menu.PanelBody).X
                - menu.HeroValue.TranslatePoint(new Point(menu.HeroValue.ActualWidth, 0), menu.PanelBody).X < 8,
                "Dose unit sits beside the number instead of the ring");
            var savedCaption = (TextBlock)menu.SavedConfigurations.Template.FindName("SelectionText", menu.SavedConfigurations);
            Check(savedCaption.Text == "已存 0/10" && menu.SavedConfigurations.ActualWidth < 90,
                "Saved configurations use the compact macOS-style count menu");
            menu.SavedConfigurations.IsDropDownOpen = true;
            await Task.Delay(300);
            Check(!((ComboBoxItem)menu.SavedConfigurations.ItemContainerGenerator.ContainerFromIndex(0)).IsEnabled,
                "Empty saved menu explains that no configurations are saved");
            menu.SavedConfigurations.IsDropDownOpen = false;
            CapturePanel(menu, Path.Combine(outputDirectory, "windows-brewing-panel-body.png"));
            double left = menu.Left, top = menu.Top;
            Click(menu.TieguanyinButton);
            Check(store.Preferences.SelectedTea == TeaKind.Tieguanyin && menu.HeroValue.Text == "8.3", "Preset button reaches the model and readout");
            Check(await ObserveMotion(menu, menu.HeroValue, outputDirectory, "tea-selection", motionFrames), "Changing tea renders a moving readout crossfade");
            Check(menu.HeroPrevious.Opacity < 0.01 && menu.HeroValue.Opacity > 0.99, "Readout crossfade finishes with exactly one visible value");
            var selectedFill = (Border)menu.TieguanyinButton.Template.FindName("SelectionFill", menu.TieguanyinButton);
            Check(selectedFill.Opacity > 0.99, "Tea selection finishes with the forest-green highlight");
            Check(menu.Left == left && menu.Top == top, "Switching preset cannot move an open menu");
            Click(menu.GardeniaButton);
            Edit(menu.WaterInput, "not a number");
            Check(Validation.GetHasError(menu.WaterInput) && !menu.PrimaryButton.IsEnabled, "Malformed numeric input blocks brewing");
            Edit(menu.WaterInput, "250");
            Check(store.WaterML == 250 && menu.PrimaryButton.IsEnabled, "Correcting numeric input restores brewing");
            Click(menu.SettingsButton);
            Check(menu.SettingsView.Visibility == Visibility.Visible, "Settings button opens native parameter controls");
            Check(await ObserveMotion(menu, menu.SettingsView, outputDirectory, "settings-transition", motionFrames), "Settings transition renders intermediate frames");
            var selectedTemperature = (ToggleButton)menu.TemperatureChoices.Children[1];
            var temperatureFill = (Border)selectedTemperature.Template.FindName("SelectionFill", selectedTemperature);
            Check(temperatureFill.Opacity > 0.99, "Initial temperature selection is painted when settings first appears");
            Edit(menu.NameInput, "下午的花茶");
            Edit(menu.RatioInput, "60");
            Check(store.IsCustomMode && store.ConfigurationName == "下午的花茶" && store.WaterPerGram == 60, "Settings bindings create a custom draft");
            store.CoolingSeconds = 125;
            Check((int)menu.CoolingMinutes.SelectedValue == 2 && (int)menu.CoolingSecondsChoice.SelectedValue == 5,
                "Independent minute and second menus retain nonstandard saved seconds");
            menu.CoolingSecondsChoice.BringIntoView();
            await Task.Delay(120);
            var minuteLabel = (TextBlock)menu.CoolingMinutes.Template.FindName("SelectionText", menu.CoolingMinutes);
            var minuteMeasure = new TextBlock { Text = minuteLabel.Text, FontFamily = minuteLabel.FontFamily,
                FontSize = minuteLabel.FontSize, FontWeight = minuteLabel.FontWeight };
            minuteMeasure.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
            Check(minuteMeasure.DesiredSize.Width <= minuteLabel.ActualWidth + 0.5, "Minute labels show both the value and unit without ellipsis");
            menu.CoolingSecondsChoice.IsDropDownOpen = true;
            await Task.Delay(320);
            var timingPopup = (Popup)menu.CoolingSecondsChoice.Template.FindName("PART_Popup", menu.CoolingSecondsChoice);
            var timingCard = (Border)menu.CoolingSecondsChoice.Template.FindName("PopupCard", menu.CoolingSecondsChoice);
            Check(timingPopup.IsOpen && timingCard.IsVisible && host.IsMenuPresented, "The styled timing dropdown stays open inside the menu");
            Check(timingCard.CornerRadius.TopLeft == 13, "Timing dropdown uses the paper card template");
            CaptureVisual(timingPopup.Child, Path.Combine(outputDirectory, "windows-timing-dropdown.png"));
            var escape = new KeyEventArgs(Keyboard.PrimaryDevice, PresentationSource.FromVisual(menu), Environment.TickCount, Key.Escape)
                { RoutedEvent = Keyboard.PreviewKeyDownEvent };
            menu.RaiseEvent(escape);
            Check(!menu.CoolingSecondsChoice.IsDropDownOpen && host.IsMenuPresented, "Escape closes the dropdown before dismissing the panel");
            Capture(menu, Path.Combine(outputDirectory, "windows-settings-timing.png"));
            menu.CoolingMinutes.SelectedValue = 3;
            Check(store.CoolingSeconds == 185 && (int)menu.CoolingSecondsChoice.SelectedValue == 5,
                "Changing minutes retains the saved seconds component");
            menu.CoolingSecondsChoice.SelectedValue = 0;
            Check(store.CoolingSeconds == 180, "Changing seconds retains the minutes component");
            menu.BrewMinutes.SelectedValue = 30;
            Check(store.FirstBrewSeconds == 1800 && menu.BrewSecondsChoice.Items.Count == 1,
                "Time menu prevents seconds from exceeding the maximum duration");
            menu.BrewMinutes.SelectedValue = 0;
            Check(store.FirstBrewSeconds == 15, "First steeping duration cannot fall below fifteen seconds");
            store.FirstBrewSeconds = 180;
            var icon = (ToggleButton)menu.IconChoices.Children[6];
            Click(icon);
            Check(store.Configuration.Icon == TeaIcon.Moon, "Native icon choice updates draft");
            Click(menu.SaveButton);
            Check(store.CustomConfigurations.Length == 1 && !store.HasUnsavedChanges, "Save button persists one clean configuration");
            Check(File.Exists(storage.FilePath), "UI save writes only isolated test preferences");
            menu.MainScroll.ScrollToEnd();
            await Task.Delay(160);
            var firstTimeRow = menu.CoolingMinutes.TranslatePoint(new Point(), menu.MainScroll);
            var lastTimeRow = menu.IncrementSecondsChoice.TranslatePoint(new Point(), menu.MainScroll);
            Check(firstTimeRow.Y >= 0 && lastTimeRow.Y + menu.IncrementSecondsChoice.ActualHeight <= menu.MainScroll.ActualHeight,
                "All three time rows are reachable together on the settings page");
            Capture(menu, Path.Combine(outputDirectory, "windows-settings-timing.png"));
            menu.MainScroll.ScrollToTop();
            await Task.Delay(120);
            Capture(menu, Path.Combine(outputDirectory, "windows-settings.png"));
            Click(menu.SettingsButton);
            Check(menu.BrewView.Visibility == Visibility.Visible && menu.HeroValue.Text == "4.2", "Return to brewing retains settings and dose");
            await Task.Delay(320);
            Check(savedCaption.Text == "已存 1/10", "Saving updates the count without showing a large selection field");
            Click(menu.CustomButton);
            Check(menu.SettingsView.Visibility == Visibility.Visible, "Custom action opens its parameter page like macOS");
            menu.SavedConfigurations.IsDropDownOpen = true;
            await Task.Delay(300);
            var currentItem = (ComboBoxItem)menu.SavedConfigurations.ItemContainerGenerator.ContainerFromIndex(0);
            currentItem.RaiseEvent(new MouseButtonEventArgs(Mouse.PrimaryDevice, Environment.TickCount, MouseButton.Left)
                { RoutedEvent = UIElement.PreviewMouseLeftButtonDownEvent });
            Check(menu.BrewView.Visibility == Visibility.Visible && !menu.SavedConfigurations.IsDropDownOpen,
                "Choosing the current saved configuration also returns to brewing");
            await Task.Delay(320);
            menu.SavedConfigurations.IsDropDownOpen = true;
            await Task.Delay(320);
            var savedPopup = (Popup)menu.SavedConfigurations.Template.FindName("PART_Popup", menu.SavedConfigurations);
            var savedItem = (ComboBoxItem)menu.SavedConfigurations.ItemContainerGenerator.ContainerFromIndex(0);
            Check(savedPopup.IsOpen && savedItem.IsSelected && savedItem.IsEnabled, "Saved configuration dropdown retains real ComboBox selection");
            CaptureVisual(savedPopup.Child, Path.Combine(outputDirectory, "windows-configuration-dropdown.png"));
            Capture(menu, Path.Combine(outputDirectory, "windows-custom-configuration.png"));
            menu.SavedConfigurations.IsDropDownOpen = false;
            store.SelectTea(TeaKind.Gardenia);
            store.WaterML = 330;
            menu.UpdateLayout();
            double ringX = menu.HeroRingIcon.TranslatePoint(new Point(), menu.PanelBody).X;
            Click(menu.InfusionPlus);
            menu.UpdateLayout();
            await Task.Delay(250);
            Check(store.StartingInfusion == 2 && menu.HeroValue.Text == "03:30", "Infusion selector switches dose to next infusion duration");
            Check(Math.Abs(menu.HeroRingIcon.TranslatePoint(new Point(), menu.PanelBody).X - ringX) < 0.01, "Readout switch keeps progress ring stationary");
            Click(menu.InfusionPlus);
            Click(menu.InfusionPlus);
            Check(await ObserveMotion(menu, menu.HeroValue, outputDirectory, "infusion-change", motionFrames)
                && menu.HeroValue.Text == "04:30" && menu.HeroPrevious.Opacity < 0.01,
                "Rapid infusion changes animate and settle on the latest value");
            Click(menu.InfusionMinus);
            Click(menu.InfusionMinus);
            Click(menu.InfusionMinus);
            host.HideMenu();
            await Task.Delay(50);
            host.ShowMenu();
            await Task.Delay(400);
            Check(menu.IsVisible && menu.PanelBody.Opacity > 0.99, "Reopening during dismissal cancels stale hide completion");
            host.HideMenu();
            host.HideMenu();
            await Task.Delay(250);
            Check(!menu.IsVisible, "Repeated dismissal finishes once");
            host.ShowMenu();
            await Task.Delay(350);
            Click(menu.PrimaryButton);
            await Task.Delay(250);
            Check(store.Phase == TeaPhase.Cooling && !menu.IsVisible, "Primary action starts cooling and hides menu");
            host.ShowMenu();
            await Task.Delay(350);
            Check(menu.CoolingStage.IsChecked == true && menu.ProgressRing.IsTiming,
                "Cooling uses the matching stage pill and timed progress ring");
            Check(((Border)menu.CoolingStage.Template.FindName("SelectionFill", menu.CoolingStage)).Opacity > 0.99,
                "The first visible cooling stage has its selected background");
            CapturePanel(menu, Path.Combine(outputDirectory, "windows-cooling-panel.png"));
            host.HideMenu();
            await Task.Delay(220);

            var typing = new TextBox { Text = "Tea Panel focus probe", Margin = new Thickness(12) };
            inputWindow = new Window { Title = "Tea Panel verification", Width = 320, Height = 120,
                Content = typing, ShowInTaskbar = false };
            inputWindow.Show();
            inputWindow.Activate();
            typing.Focus();
            host.HoldMenuForLayoutChecks = false;
            host.ShowMenu();
            inputWindow.Activate();
            typing.Focus();
            await Task.Delay(50);
            Check(!host.IsMenuPresented && store.Phase == TeaPhase.Cooling, "Losing focus hides menu while timer continues");
            host.HoldMenuForLayoutChecks = true;
            var foreground = ReadFocus();
            Check(foreground.Foreground != IntPtr.Zero, "Operating-system foreground and keyboard focus snapshot is available");
            now = now.AddSeconds(180);
            store.Tick();
            Check(ReadFocus() == foreground, "Reminder appearance preserves operating-system foreground and keyboard focus");
            await Task.Delay(450);
            Check(store.Phase == TeaPhase.WaitingForLeaves && host.Reminder.IsVisible, "Actual cooling completion displays a reminder window");
            Check(!host.Reminder.ShowActivated && !host.Reminder.ShowInTaskbar && host.Reminder.Topmost, "Reminder uses nonactivating floating window settings");
            now = now.AddSeconds(3600);
            store.Tick();
            await Task.Delay(120);
            Check(store.Phase == TeaPhase.WaitingForLeaves && host.Reminder.IsVisible, "Unanswered reminder persists across a long time jump");
            Capture(host.Reminder, Path.Combine(outputDirectory, "windows-add-leaves.png"));
            host.ShowMenu();
            await Task.Delay(350);
            Check(menu.LeavesStage.IsChecked == true && menu.HeroValue.Text == "该放茶叶了",
                "Waiting for leaves displays the manual confirmation stage");
            CapturePanel(menu, Path.Combine(outputDirectory, "windows-waiting-panel.png"));
            host.HideMenu();
            await Task.Delay(220);
            Click(host.Reminder.ConfirmButton);
            await Task.Delay(280);
            Check(store.Phase == TeaPhase.Brewing && store.RemainingSeconds == 180 && !host.Reminder.IsVisible, "Reminder confirmation starts full steeping timer");
            host.ShowMenu();
            await Task.Delay(350);
            Check(menu.BrewStage.IsChecked == true && menu.ProgressRing.IsTiming && !menu.PrimaryButton.IsEnabled,
                "Steeping shows its stage and prevents repeated starts");
            CapturePanel(menu, Path.Combine(outputDirectory, "windows-steeping-panel.png"));
            host.HideMenu();
            await Task.Delay(220);
            now = now.AddSeconds(180);
            foreground = ReadFocus();
            store.Tick();
            Check(ReadFocus() == foreground, "Reused reminder window still preserves operating-system input focus");
            await Task.Delay(450);
            Check(store.Phase == TeaPhase.Ready && host.Reminder.IsVisible, "Brew completion shows a fresh reminder");
            Capture(host.Reminder, Path.Combine(outputDirectory, "windows-reminder.png"));
            Click(host.Reminder.ConfirmButton);
            await Task.Delay(280);
            Check(store.Phase == TeaPhase.Ready && store.Reminder is null && !host.Reminder.IsVisible, "Ready acknowledgment clears card but retains round");
            inputWindow.Close();
            inputWindow = null;
            host.ShowMenu();
            await Task.Delay(350);
            CapturePanel(menu, Path.Combine(outputDirectory, "windows-ready-panel.png"));
            Click(menu.PrimaryButton);
            await Task.Delay(320);
            Check(store.Phase == TeaPhase.PreparingRefill && menu.HeroValue.Text == "再续一杯",
                "Refill preparation matches the macOS readout and requires fresh water");
            CapturePanel(menu, Path.Combine(outputDirectory, "windows-refill-panel.png"));
            Click(menu.PreviewButton);
            await Task.Delay(450);
            Check(store.Reminder?.IsPreview == true && store.Phase == TeaPhase.PreparingRefill && !menu.IsVisible, "Preview action displays card without changing phase");
            Click(host.Reminder.ConfirmButton);
            await Task.Delay(280);
            Check(store.Reminder is null && store.Phase == TeaPhase.PreparingRefill, "Preview acknowledgment leaves real session unchanged");
            host.ShowMenu();
            await Task.Delay(350);
            Click(menu.SkipButton);
            await Task.Delay(250);
            Check(store.Phase == TeaPhase.Brewing && store.DisplayedInfusion == 2 && store.RemainingSeconds == 210,
                "Refill skip starts the full next infusion without adding leaves");
            store.EndRound();
            store.FirstBrewSeconds = 1800;
            store.IncrementSeconds = 600;
            store.SetStartingInfusion(99);
            host.ShowMenu();
            await Task.Delay(400);
            Check(menu.HeroValue.Text == "1010:00" && menu.PrimaryButton.IsEnabled, "Longest supported readout stays usable");
            Check(menu.HeroValue.TransformToAncestor(menu.PanelBody).TransformBounds(new Rect(menu.HeroValue.RenderSize)).Width <= 223.5,
                "Long monospaced readout fits its reserved area");
            Capture(menu, Path.Combine(outputDirectory, "windows-long-duration.png"));

            var body = new Border { Background = Brushes.White, Child = new TextBlock { Text = "Motion check" }, Focusable = true };
            motionWindow = new Window { Width = 200, Height = 100, Content = body, ShowInTaskbar = false, ShowActivated = false };
            var motion = new PanelMotion(motionWindow, body, reminder: true, animationsEnabled: () => false);
            motion.Show();
            await Task.Delay(160);
            Check(body.Opacity > 0.99 && ((TranslateTransform)body.RenderTransform).Y == 0, "Disabled animations fade in without displacement");
            motion.Hide();
            Check(!body.IsHitTestVisible, "Dismissing panel immediately stops accepting duplicate confirmation clicks");
            await Task.Delay(160);
            Check(!motionWindow.IsVisible, "Disabled animations finish dismissal");
            TeaMotion.AnimationPreferenceOverride = false;
            motion.Show();
            TeaMotion.Reveal(body);
            await Task.Delay(160);
            Check(((TranslateTransform)body.RenderTransform).Y == 0 && body.Opacity > 0.99,
                "Reduced content motion fades without translating");
            var currentReadout = new TextBlock { Text = "6.6" };
            var previousReadout = new TextBlock();
            var textHost = new StackPanel();
            textHost.Children.Add(currentReadout);
            textHost.Children.Add(previousReadout);
            body.Child = textHost;
            TeaMotion.ChangeReadout(currentReadout, previousReadout, "8.3", animate: true);
            await Task.Delay(160);
            Check(((TranslateTransform)currentReadout.RenderTransform).Y == 0 && currentReadout.Opacity > 0.99
                && previousReadout.Opacity < 0.01, "Reduced readout motion settles with no displacement or duplicate value");
            Check(SystemParameters.ClientAreaAnimation == systemAnimations, "Desktop checks preserve the real Windows animation setting");
            motion.Stop();
            motionWindow.Close();
            motionWindow = null;
            Click(menu.QuitButton);
            Check(quitRequested, "Quit button reaches the application lifecycle callback");
            Check(dispatcherFailure is null, "No WPF dispatcher exceptions occurred");
            var dpi = VisualTreeHelper.GetDpi(menu);
            host.Dispose();
            Check(!host.IsTrayVisible && !menu.IsVisible, "Disposal removes tray icon and closes windows");
            host = null;
            WriteReport(outputDirectory, new { passed = true, count = checks.Count, checks, motionFrames,
                framework = RuntimeInformation.FrameworkDescription, os = RuntimeInformation.OSDescription,
                systemAnimationsEnabled = systemAnimations, normalMotionPreferenceInjected = true,
                dpiScale = dpi.DpiScaleX, foregroundAndKeyboardPreserved = true,
                manualPending = new[] { "Physical tray mouse clicks", "Physical sleep/wake and lock/unlock", "Mixed-DPI multiple monitors", "Other display scaling factors", "Exclusive full-screen applications", "Actual system animation toggle" } });
            result = 0;
        }
        catch (Exception error)
        {
            WriteReport(outputDirectory, new { passed = false, count = checks.Count, checks, error = error.ToString(), dispatcherError = dispatcherFailure?.ToString() });
        }
        finally
        {
            TeaMotion.AnimationPreferenceOverride = null;
            host?.Dispose();
            inputWindow?.Close();
            motionWindow?.Close();
            app.Shutdown(result);
        }
    }

    private static void WriteReport(string directory, object report) => File.WriteAllText(
        Path.Combine(directory, "desktop-checks.json"), JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));

    private static void Capture(Window window, string path)
    {
        SaveBitmap(Render(window), path);
    }

    private static void CapturePanel(MenuWindow window, string path)
    {
        window.UpdateLayout();
        var dpi = VisualTreeHelper.GetDpi(window);
        var origin = window.PanelBody.TranslatePoint(new Point(), window);
        var image = new CroppedBitmap(Render(window), new Int32Rect((int)Math.Round(origin.X * dpi.DpiScaleX),
            (int)Math.Round(origin.Y * dpi.DpiScaleY), (int)Math.Round(window.PanelBody.ActualWidth * dpi.DpiScaleX),
            (int)Math.Round(window.PanelBody.ActualHeight * dpi.DpiScaleY)));
        SaveBitmap(image, path);
    }

    private sealed record MotionFrame(string Transition, double Milliseconds, double Opacity, double Offset, string Image);

    private static async Task<bool> ObserveMotion(Window window, FrameworkElement element,
        string directory, string name, List<MotionFrame> frames)
    {
        var clock = System.Diagnostics.Stopwatch.StartNew();
        var images = new List<(string Name, BitmapSource Bitmap)>();
        int captured = 0;
        double lastCapture = -100;
        bool intermediate = false;
        EventHandler rendering = (_, _) =>
        {
            double opacity = element.Opacity;
            if (opacity <= 0.01 || opacity >= 0.99) return;
            intermediate = true;
            if (captured >= 8 || clock.Elapsed.TotalMilliseconds - lastCapture < 28) return;
            lastCapture = clock.Elapsed.TotalMilliseconds;
            string image = $"motion-{name}-{captured++:00}.png";
            frames.Add(new(name, clock.Elapsed.TotalMilliseconds, opacity,
                (element.RenderTransform as TranslateTransform)?.Y ?? 0, image));
            images.Add((image, Render(window)));
        };
        CompositionTarget.Rendering += rendering;
        try { await Task.Delay(420); }
        finally { CompositionTarget.Rendering -= rendering; }
        string finalImage = $"motion-{name}-final.png";
        frames.Add(new(name, clock.Elapsed.TotalMilliseconds, element.Opacity,
            (element.RenderTransform as TranslateTransform)?.Y ?? 0, finalImage));
        Capture(window, Path.Combine(directory, finalImage));
        // Encode after playback so PNG compression cannot stall the observed animation.
        foreach (var image in images) SaveBitmap(image.Bitmap, Path.Combine(directory, image.Name));
        return intermediate;
    }

    private static void CaptureVisual(UIElement element, string path)
    {
        element = PresentationSource.FromVisual(element)?.RootVisual as UIElement ?? element;
        SaveBitmap(Render(element), path);
    }

    private static BitmapSource Render(UIElement element)
    {
        element.UpdateLayout();
        var dpi = VisualTreeHelper.GetDpi(element);
        var size = element.RenderSize;
        var bitmap = new RenderTargetBitmap((int)Math.Ceiling(size.Width * dpi.DpiScaleX),
            (int)Math.Ceiling(size.Height * dpi.DpiScaleY), dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
        bitmap.Render(element);
        bitmap.Freeze();
        return bitmap;
    }

    private static void SaveBitmap(BitmapSource bitmap, string path)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
    }

    private static bool HasInk(TextBlock text)
    {
        var window = Window.GetWindow(text);
        window.UpdateLayout();
        var dpi = VisualTreeHelper.GetDpi(window);
        var bitmap = new RenderTargetBitmap((int)Math.Ceiling(window.ActualWidth * dpi.DpiScaleX),
            (int)Math.Ceiling(window.ActualHeight * dpi.DpiScaleY), dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
        bitmap.Render(window);
        Rect bounds = text.TransformToAncestor(window).TransformBounds(new Rect(text.RenderSize));
        int x = Math.Max(0, (int)(bounds.X * dpi.DpiScaleX)), y = Math.Max(0, (int)(bounds.Y * dpi.DpiScaleY));
        int width = Math.Min(bitmap.PixelWidth - x, (int)(bounds.Width * dpi.DpiScaleX));
        int height = Math.Min(bitmap.PixelHeight - y, (int)(bounds.Height * dpi.DpiScaleY));
        if (width <= 0 || height <= 0) return false;
        var pixels = new byte[width * height * 4];
        bitmap.CopyPixels(new Int32Rect(x, y, width, height), pixels, width * 4, 0);
        for (int i = 0; i < pixels.Length; i += 4)
            if (pixels[i + 3] > 64 && pixels[i + 2] < 100 && pixels[i + 1] < 150 && pixels[i] < 120) return true;
        return false;
    }
}
