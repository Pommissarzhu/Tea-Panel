using System;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using ShapePath = System.Windows.Shapes.Path;

namespace TeaPanel;

public partial class MenuWindow : Window
{
    private readonly TeaStore store;
    private bool ready;
    private bool refreshing;
    private bool showsSettings;
    private string previousReadout = "";
    private string previousReadoutKind = "";
    private readonly TextBlock readoutMeasure = new();
    internal bool MayClose { get; set; }
    public event Action? PrimaryRequested;
    public event Action? SkipRequested;
    public event Action? PreviewRequested;
    public event Action? QuitRequested;
    public event Action? DismissRequested;

    private sealed record ConfigurationChoice(string Id, string Name, TeaIcon Icon)
    {
        public Geometry Symbol => TeaIcons.Get(Icon);
    }
    private sealed record TimeChoice(int Value, string Label);

    public MenuWindow(TeaStore store)
    {
        this.store = store;
        InitializeComponent();
        DataContext = store;
        foreach (TeaIcon icon in Enum.GetValues<TeaIcon>())
        {
            var button = new ToggleButton { Tag = icon, ToolTip = TeaIcons.Names[(int)icon],
                Height = 34, Margin = new Thickness(0, 0, 6, 6), Padding = new Thickness(0) };
            var path = new ShapePath { Data = TeaIcons.Get(icon), Width = 17, Height = 17, Stretch = Stretch.Uniform };
            path.SetBinding(ShapePath.FillProperty, new Binding(nameof(Control.Foreground)) { Source = button });
            button.Content = path;
            System.Windows.Automation.AutomationProperties.SetName(button, "图标：" + TeaIcons.Names[(int)icon]);
            button.Click += (_, _) => store.SetIcon(icon);
            IconChoices.Children.Add(button);
        }
        ready = true;
        store.PropertyChanged += StoreChanged;
        Closed += (_, _) => store.PropertyChanged -= StoreChanged;
        Refresh();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!MayClose) { e.Cancel = true; DismissRequested?.Invoke(); }
        base.OnClosing(e);
    }

    private void StoreChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (!ready || refreshing) return;
        if (e.PropertyName is null) Refresh();
        else if (e.PropertyName == nameof(TeaStore.RemainingSeconds)) UpdateHero();
    }

    private void Refresh()
    {
        refreshing = true;
        try
        {
            foreach (var button in new[] { GardeniaButton, TieguanyinButton, JasmineButton })
            {
                button.IsChecked = !store.IsCustomMode && Enum.Parse<TeaKind>((string)button.Tag) == store.Preferences.SelectedTea;
                button.IsEnabled = !store.IsActive;
            }
            CustomButton.IsEnabled = !store.IsActive || store.IsCustomMode;
            CustomButton.Background = (Brush)FindResource(store.IsCustomMode ? "Forest" : "TranslucentWhite");
            CustomButton.Foreground = (Brush)FindResource(store.IsCustomMode ? "Paper" : "Green");
            CustomTitle.Text = store.IsCustomMode && store.HasUnsavedChanges ? "自定义 · 未保存" : "自定义";
            CustomIcon.Data = store.IsCustomMode ? TeaIcons.Get(store.Configuration.Icon) : TeaIcons.Settings;
            CustomIcon.Fill = store.IsCustomMode ? (Brush)FindResource("Paper") : null;
            CustomIcon.Stroke = store.IsCustomMode ? null : (Brush)FindResource("Green");
            QuickSaveButton.Visibility = store.IsCustomMode ? Visibility.Visible : Visibility.Collapsed;
            QuickSaveButton.Content = store.SavedConfiguration is null ? "保存" : "更新";
            SavedConfigurations.ItemsSource = store.CustomConfigurations.Length == 0
                ? new[] { new ConfigurationChoice("", "还没有保存的配置", TeaIcon.Leaf) }
                : store.CustomConfigurations.Select(c => new ConfigurationChoice(c.Id, c.Name, c.Icon)).ToArray();
            SavedConfigurations.SelectedValue = store.IsCustomMode ? store.SavedConfiguration?.Id : null;
            SavedConfigurations.IsEnabled = !store.IsActive;
            NoticeText.Text = store.StorageMessage ?? store.ConfigurationMessage ?? "";
            NoticeText.Foreground = (Brush)FindResource(store.StorageMessage is null ? "Green" : "Error");
            NoticeText.Visibility = NoticeText.Text.Length == 0 ? Visibility.Collapsed : Visibility.Visible;
            BrewView.Visibility = showsSettings ? Visibility.Collapsed : Visibility.Visible;
            SettingsView.Visibility = showsSettings ? Visibility.Visible : Visibility.Collapsed;
            SettingsButton.Background = showsSettings ? (Brush)FindResource("Pale") : Brushes.Transparent;
            SettingsTitle.Text = store.IsCustomMode ? "自定义配置" : "内置模板参数";
            SettingsTeaName.Text = TeaPresets.Name(store.Configuration.BaseTea);
            SettingsNote.Text = store.IsActive ? "本轮用量和名称保持不变；时间修改用于下一泡，其余修改用于下一轮。"
                : "修改任意参数即进入自定义模式。草稿自动保留，点击保存后加入配置列表。";
            foreach (ToggleButton button in IconChoices.Children) button.IsChecked = (TeaIcon)button.Tag == store.Configuration.Icon;
            foreach (ToggleButton button in TemperatureChoices.Children) button.IsChecked = int.Parse((string)button.Tag) == store.WaterTemperatureC;
            SetTimeOptions(CoolingMinutes, CoolingSecondsChoice, 0, 900, 30, store.CoolingSeconds);
            SetTimeOptions(BrewMinutes, BrewSecondsChoice, 15, 1800, 15, store.FirstBrewSeconds);
            SetTimeOptions(IncrementMinutes, IncrementSecondsChoice, 0, 600, 15, store.IncrementSeconds);
            CoolingZeroNote.Visibility = store.CoolingSeconds == 0 ? Visibility.Visible : Visibility.Collapsed;
            IncrementZeroNote.Visibility = store.IncrementSeconds == 0 ? Visibility.Visible : Visibility.Collapsed;
            SaveActions.Visibility = store.IsCustomMode ? Visibility.Visible : Visibility.Collapsed;
            SaveButton.Content = store.SavedConfiguration is null ? "保存配置" : "更新配置";
            SaveAsButton.Visibility = DeleteButton.Visibility = store.SavedConfiguration is null ? Visibility.Collapsed : Visibility.Visible;
            DeleteButton.IsEnabled = !store.IsActive;
            FullConfigurationsNote.Visibility = store.CanSaveAsNew ? Visibility.Collapsed : Visibility.Visible;
            BrewInputs.Visibility = store.IsActive ? Visibility.Collapsed : Visibility.Visible;
            InfusionLabel.Text = store.StartingInfusion.ToString();
            InfusionMinus.IsEnabled = store.StartingInfusion > 1;
            InfusionPlus.IsEnabled = store.StartingInfusion < 99;
            ActiveActions.Visibility = store.IsActive ? Visibility.Visible : Visibility.Collapsed;
            BatchInfo.Visibility = store.Round is null ? Visibility.Collapsed : Visibility.Visible;
            if (store.Round is { } round)
            {
                BatchText.Text = $"{TeaText.Number(round.WaterML)} mL · "
                    + (store.DisplayedInfusion > 1 ? "沿用原茶叶" : $"干茶 {TeaText.Grams(round.Grams)} 克");
                BatchRatio.Text = $"{TeaText.Number(round.Configuration.Recipe.WaterPerGram)} : 1";
            }
            BatchHint.Text = store.DisplayedInfusion >= 4 ? "茶味可能已经淡了，可以换新茶叶。"
                : store.Phase == TeaPhase.PreparingRefill ? "沿用原茶叶，不用再加干茶。" : "";
            BatchHint.Visibility = BatchHint.Text.Length > 0 && store.IsActive ? Visibility.Visible : Visibility.Collapsed;
            CoolingSummary.Text = TeaText.Duration(store.CoolingSeconds);
            BrewSummary.Text = TeaText.Duration(store.CurrentBrewSeconds);
            IncrementSummary.Text = store.IncrementSeconds == 0 ? "不加时" : "+" + TeaText.Duration(store.IncrementSeconds);
            PreviewButton.IsEnabled = store.Reminder is null;
            UpdateHero();
            UpdateActions();
        }
        finally { refreshing = false; }
    }

    private static void SetTimeOptions(ComboBox minutes, ComboBox seconds, int min, int max, int step, int current)
    {
        minutes.ItemsSource = Enumerable.Range(0, max / 60 + 1).Append(current / 60).Distinct().Order()
            .Select(value => new TimeChoice(value, $"{value:00} 分")).ToArray();
        minutes.SelectedValue = current / 60;
        var secondValues = Enumerable.Range(0, (59 / step) + 1).Select(i => i * step)
            .Where(value => current / 60 * 60 + value >= min && current / 60 * 60 + value <= max)
            .Append(current % 60).Distinct().Order();
        seconds.ItemsSource = secondValues.Select(value => new TimeChoice(value, $"{value:00} 秒")).ToArray();
        seconds.SelectedValue = current % 60;
        minutes.IsEnabled = minutes.Items.Count > 1;
        seconds.IsEnabled = seconds.Items.Count > 1;
    }

    private void UpdateHero()
    {
        HeroEyebrow.Text = store.Phase switch
        {
            TeaPhase.Cooling => "正在晾水",
            TeaPhase.WaitingForLeaves => "晾水计时结束",
            TeaPhase.Brewing => "正在泡茶",
            TeaPhase.Ready => "茶香已经就绪",
            TeaPhase.PreparingRefill => "准备续一杯",
            _ => store.IsCustomMode ? store.ConfigurationName : store.DisplayedInfusion > 1 ? "接着泡这一杯" : "这一杯，刚刚好"
        };
        var stateSymbol = TeaIcons.State(store.Phase);
        var symbol = stateSymbol ?? TeaIcons.Get(store.DisplayIcon);
        bool symbolChanged = HeroRingIcon.Data != symbol;
        HeroSmallIcon.Data = HeroRingIcon.Data = symbol;
        if (symbolChanged && HeroRingIcon.IsVisible)
        {
            var duration = TimeSpan.FromSeconds(TeaMotion.AnimationsEnabled ? 0.18 : 0.1);
            HeroSmallIcon.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, duration));
            HeroRingIcon.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, duration));
        }
        HeroSmallIcon.Fill = stateSymbol is null ? (Brush)FindResource("Muted") : null;
        HeroRingIcon.Fill = stateSymbol is null ? (Brush)FindResource("Green") : null;
        HeroSmallIcon.Stroke = stateSymbol is null ? null : (Brush)FindResource("Muted");
        HeroRingIcon.Stroke = stateSymbol is null ? null : (Brush)FindResource("Green");
        HeroSmallIcon.StrokeThickness = 1.3;
        HeroRingIcon.StrokeThickness = 1.5;
        HeroInfusionLabel.Text = $"第 {store.DisplayedInfusion} 泡";
        StageRow.Visibility = store.IsActive ? Visibility.Visible : Visibility.Collapsed;
        CoolingStage.IsChecked = store.Phase == TeaPhase.Cooling;
        LeavesStage.IsChecked = store.Phase == TeaPhase.WaitingForLeaves;
        BrewStage.IsChecked = store.Phase is TeaPhase.Brewing or TeaPhase.Ready;
        ProgressRing.IsTiming = store.Phase is TeaPhase.Cooling or TeaPhase.Brewing;
        bool dose = store.Phase == TeaPhase.Idle && store.DisplayedInfusion == 1;
        bool countdown = store.Phase is TeaPhase.Cooling or TeaPhase.Brewing;
        bool words = store.Phase is TeaPhase.WaitingForLeaves or TeaPhase.Ready or TeaPhase.PreparingRefill;
        string kind = dose ? "dose" : countdown ? store.Phase.ToString() : store.Phase.ToString() + store.DisplayedInfusion;
        string value = dose ? TeaText.Grams(store.RecommendedGrams) : countdown ? TeaText.Clock(store.RemainingSeconds)
            : store.Phase == TeaPhase.WaitingForLeaves ? (store.DisplayedInfusion == 1 ? "该放茶叶了" : "放回原茶叶")
            : store.Phase == TeaPhase.Ready ? "泡好了" : store.Phase == TeaPhase.PreparingRefill ? "再续一杯" : TeaText.Clock(store.CurrentBrewSeconds);
        TeaMotion.ChangeReadout(HeroValue, HeroPrevious, value,
            previousReadout.Length > 0 && (!countdown || previousReadoutKind != kind));
        HeroValue.FontWeight = words ? FontWeights.Medium : FontWeight.FromOpenTypeWeight(350);
        ((ScaleTransform)HeroValue.LayoutTransform).ScaleX = words ? 1 : 1.06;
        double maximum = words ? 31 : 61;
        readoutMeasure.Text = value;
        readoutMeasure.FontFamily = HeroValue.FontFamily;
        readoutMeasure.FontSize = maximum;
        readoutMeasure.FontWeight = HeroValue.FontWeight;
        readoutMeasure.Typography.NumeralAlignment = FontNumeralAlignment.Tabular;
        readoutMeasure.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        double width = readoutMeasure.DesiredSize.Width * (words ? 1 : 1.06);
        HeroValue.FontSize = Math.Max(maximum * 0.5, Math.Min(maximum, maximum * (dose ? 195 : 223) / Math.Max(1, width)));
        Canvas.SetTop(HeroPrevious, (69 - Measure(HeroPrevious.Text, HeroPrevious.FontSize, HeroPrevious.FontWeight).Height) / 2);
        HeroUnit.Text = dose ? "克" : "";
        HeroSubtitle.Text = store.Phase switch
        {
            TeaPhase.WaitingForLeaves => store.DisplayedInfusion == 1 ? $"投茶 {TeaText.Grams(store.Round?.Grams ?? 0)} 克后，确认开始" : "沿用原茶叶，放回后再开始计时",
            TeaPhase.Ready => "取出茶滤或倒出茶汤，慢慢享用",
            TeaPhase.PreparingRefill => "新水准备好后，再开始计时",
            TeaPhase.Cooling => "先等水凉一点，再放茶叶",
            TeaPhase.Brewing => "让茶香慢慢释放",
            TeaPhase.Idle when dose => (store.IsCustomMode ? "自定义" : "建议干茶") + " · " + TeaPresets.Detail(store.Configuration.BaseTea),
            _ => "本泡浸泡 · 沿用原茶叶，不再加干茶"
        };
        previousReadout = value;
        previousReadoutKind = kind;
    }

    private FormattedText Measure(string value, double size, FontWeight weight) => new(value, CultureInfo.CurrentCulture,
        FlowDirection.LeftToRight, new Typeface(HeroValue.FontFamily, FontStyles.Normal, weight, FontStretches.Normal),
        size, Brushes.Black, VisualTreeHelper.GetDpi(this).PixelsPerDip);

    private bool HasInputError(bool recipeOnly = false) => (recipeOnly ? new[] { RatioInput }
        : new[] { WaterInput, CapacityInput, SettingsWaterInput, RatioInput }).Any(Validation.GetHasError);

    private void UpdateActions()
    {
        if (!ready) return;
        string? error = HasInputError() ? "请输入有效的数值。" : store.ValidationMessage;
        ValidationText.Text = error ?? "";
        ValidationText.Visibility = error is not null && !store.IsActive ? Visibility.Visible : Visibility.Collapsed;
        PrimaryButton.Tag = store.Phase == TeaPhase.Brewing ? "Timing" : null;
        PrimaryButton.IsEnabled = store.Phase != TeaPhase.Brewing && (store.IsActive || error is null);
        PrimaryTitle.Text = store.Phase switch
        {
            TeaPhase.Cooling => "跳过晾水，直接泡茶",
            TeaPhase.WaitingForLeaves => store.DisplayedInfusion == 1 ? "已投茶，开始泡茶" : $"已放回，开始第 {store.DisplayedInfusion} 泡",
            TeaPhase.Brewing => "泡茶中，到点提醒你",
            TeaPhase.Ready => $"续泡 · 第 {store.DisplayedInfusion + 1} 泡",
            _ => store.CoolingSeconds > 0 ? (store.DisplayedInfusion > 1 ? "已接新水，开始晾水" : "已接水，开始晾水")
                : store.DisplayedInfusion == 1 ? "已注水，开始泡茶" : $"已注水，开始第 {store.DisplayedInfusion} 泡"
        };
        PrimaryArrow.Visibility = store.Phase is TeaPhase.Cooling or TeaPhase.Brewing ? Visibility.Collapsed : Visibility.Visible;
        bool skip = store.CanSkipCooling && (store.Phase is TeaPhase.Idle or TeaPhase.PreparingRefill);
        AfterPrimary.Visibility = !store.IsActive || skip ? Visibility.Visible : Visibility.Collapsed;
        SkipButton.Visibility = skip ? Visibility.Visible : Visibility.Collapsed;
        SkipButton.IsEnabled = store.IsActive || error is null;
        TemperatureHint.Visibility = store.IsActive ? Visibility.Collapsed : Visibility.Visible;
        TemperatureHint.Text = $"参考水温约 {store.WaterTemperatureC}°C" + (skip ? "" : " · 晾水计时不等于测温");
        Grid.SetColumn(TemperatureHint, skip ? 1 : 0);
        Grid.SetColumnSpan(TemperatureHint, skip ? 1 : 2);
        TemperatureHint.HorizontalAlignment = skip ? HorizontalAlignment.Right : HorizontalAlignment.Center;
        bool canSave = !HasInputError(true) && store.ConfigurationValidationMessage is null
            && (store.SavedConfiguration is not null || store.CanSaveAsNew);
        SaveButton.IsEnabled = QuickSaveButton.IsEnabled = canSave;
        SaveAsButton.IsEnabled = store.CanSaveAsNew && !HasInputError(true) && store.ConfigurationValidationMessage is null;
    }

    private void OnValidationError(object sender, ValidationErrorEventArgs e) { if (ready) UpdateActions(); e.Handled = true; }
    private void OnTea(object sender, RoutedEventArgs e) => store.SelectTea(Enum.Parse<TeaKind>((string)((ToggleButton)sender).Tag));
    private void OnCustom(object sender, RoutedEventArgs e) { store.EnterCustomMode(); ShowSettings(true); }
    private void OnSavedSelection(object sender, SelectionChangedEventArgs e)
    {
        if (refreshing || SavedConfigurations.SelectedValue is not string id || id.Length == 0) return;
        store.SelectCustomConfiguration(id);
        ShowSettings(false);
    }
    private void OnSavedItemMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (((ComboBoxItem)sender).DataContext is not ConfigurationChoice choice || choice.Id.Length == 0) return;
        SavedConfigurations.IsDropDownOpen = false;
        store.SelectCustomConfiguration(choice.Id);
        ShowSettings(false);
        e.Handled = true;
    }
    private void OnSettings(object sender, RoutedEventArgs e) => ShowSettings(!showsSettings);
    private void ShowSettings(bool value)
    {
        if (showsSettings == value) return;
        showsSettings = value;
        Refresh();
        MainScroll.ScrollToTop();
        TeaMotion.Reveal(showsSettings ? SettingsView : BrewView, 6);
        PanelBody.Focus();
    }
    private void OnTimePart(object sender, SelectionChangedEventArgs e)
    {
        if (refreshing || !ready || ((ComboBox)sender).SelectedValue is not int value) return;
        string tag = (string)((ComboBox)sender).Tag;
        bool minutes = tag.EndsWith("Minutes", StringComparison.Ordinal);
        int current = tag.StartsWith("Cooling", StringComparison.Ordinal) ? store.CoolingSeconds
            : tag.StartsWith("Brew", StringComparison.Ordinal) ? store.FirstBrewSeconds : store.IncrementSeconds;
        if (value == (minutes ? current / 60 : current % 60)) return;
        int seconds = minutes ? value * 60 + current % 60 : current / 60 * 60 + value;
        if (tag.StartsWith("Cooling", StringComparison.Ordinal)) store.CoolingSeconds = Math.Clamp(seconds, 0, 900);
        else if (tag.StartsWith("Brew", StringComparison.Ordinal)) store.FirstBrewSeconds = Math.Clamp(seconds, 15, 1800);
        else store.IncrementSeconds = Math.Clamp(seconds, 0, 600);
    }
    private void OnTemperature(object sender, RoutedEventArgs e) => store.WaterTemperatureC = int.Parse((string)((ToggleButton)sender).Tag);
    private void OnInfusionMinus(object sender, RoutedEventArgs e) => store.SetStartingInfusion(store.StartingInfusion - 1);
    private void OnInfusionPlus(object sender, RoutedEventArgs e) => store.SetStartingInfusion(store.StartingInfusion + 1);
    private void OnPrimary(object sender, RoutedEventArgs e) { if (PrimaryButton.IsEnabled) PrimaryRequested?.Invoke(); }
    private void OnSkip(object sender, RoutedEventArgs e) { if (SkipButton.IsEnabled) SkipRequested?.Invoke(); }
    private void OnEnd(object sender, RoutedEventArgs e) => store.EndRound();
    private void OnPreview(object sender, RoutedEventArgs e) => PreviewRequested?.Invoke();
    private void OnQuit(object sender, RoutedEventArgs e) => QuitRequested?.Invoke();
    private void OnSave(object sender, RoutedEventArgs e) { if (store.SaveConfiguration()) FlashNotice(); }
    private void OnSaveAs(object sender, RoutedEventArgs e) { if (store.SaveConfiguration(true)) FlashNotice(); }
    private void OnDelete(object sender, RoutedEventArgs e) => store.DeleteSelectedConfiguration();
    private void FlashNotice() => NoticeText.BeginAnimation(OpacityProperty,
        new DoubleAnimation(0.2, 1, TimeSpan.FromSeconds(TeaMotion.AnimationsEnabled ? 0.24 : 0.1)));
    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            var open = new[] { SavedConfigurations, CoolingMinutes, CoolingSecondsChoice, BrewMinutes,
                BrewSecondsChoice, IncrementMinutes, IncrementSecondsChoice }.FirstOrDefault(choice => choice.IsDropDownOpen);
            if (open is not null) open.IsDropDownOpen = false;
            else DismissRequested?.Invoke();
            e.Handled = true;
        }
        else if (e.Key == Key.Return && Keyboard.FocusedElement is TextBox box)
        { box.GetBindingExpression(TextBox.TextProperty)?.UpdateSource(); PanelBody.Focus(); e.Handled = true; }
    }
    private void OnBackgroundMouseDown(object sender, MouseButtonEventArgs e)
    {
        var source = e.OriginalSource as DependencyObject;
        while (source is not null && source != PanelBody)
        {
            if (source is TextBoxBase or ButtonBase or ComboBox or Slider) return;
            source = source is Visual ? VisualTreeHelper.GetParent(source) : null;
        }
        PanelBody.Focus();
    }
}
