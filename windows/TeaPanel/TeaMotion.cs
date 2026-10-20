using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace TeaPanel;

// Small, shared feedback for native controls and changing content. Every movement
// checks the current Windows animation preference; reduced motion keeps short fades.
public static class TeaMotion
{
    internal static bool AnimationsEnabled
    {
        get
        {
#if TEA_PANEL_TESTING
            if (AnimationPreferenceOverride is bool value) return value;
#endif
            return SystemParameters.ClientAreaAnimation;
        }
    }
#if TEA_PANEL_TESTING
    internal static bool? AnimationPreferenceOverride { get; set; }
#endif
    public static readonly DependencyProperty FeedbackProperty = DependencyProperty.RegisterAttached(
        "Feedback", typeof(bool), typeof(TeaMotion), new PropertyMetadata(false, FeedbackChanged));
    public static bool GetFeedback(DependencyObject target) => (bool)target.GetValue(FeedbackProperty);
    public static void SetFeedback(DependencyObject target, bool value) => target.SetValue(FeedbackProperty, value);

    public static readonly DependencyProperty PopupEntranceProperty = DependencyProperty.RegisterAttached(
        "PopupEntrance", typeof(bool), typeof(TeaMotion), new PropertyMetadata(false, PopupEntranceChanged));
    public static bool GetPopupEntrance(DependencyObject target) => (bool)target.GetValue(PopupEntranceProperty);
    public static void SetPopupEntrance(DependencyObject target, bool value) => target.SetValue(PopupEntranceProperty, value);

    private static void FeedbackChanged(DependencyObject target, DependencyPropertyChangedEventArgs args)
    {
        if (target is not ButtonBase button) return;
        if ((bool)args.NewValue)
        {
            button.RenderTransformOrigin = new Point(0.5, 0.5);
            button.RenderTransform = new ScaleTransform();
            button.Loaded += ButtonLoaded;
            button.MouseEnter += PointerChanged;
            button.MouseLeave += PointerChanged;
            button.AddHandler(UIElement.MouseLeftButtonDownEvent, new MouseButtonEventHandler(ButtonMouseChanged), true);
            button.AddHandler(UIElement.MouseLeftButtonUpEvent, new MouseButtonEventHandler(ButtonMouseChanged), true);
            button.AddHandler(Keyboard.KeyDownEvent, new KeyEventHandler(ButtonKeyChanged), true);
            button.AddHandler(Keyboard.KeyUpEvent, new KeyEventHandler(ButtonKeyChanged), true);
            button.LostMouseCapture += PointerChanged;
            button.IsEnabledChanged += ButtonEnabledChanged;
            if (button is ToggleButton toggle)
            {
                toggle.Checked += SelectionChanged;
                toggle.Unchecked += SelectionChanged;
            }
        }
        else
        {
            button.Loaded -= ButtonLoaded;
            button.MouseEnter -= PointerChanged;
            button.MouseLeave -= PointerChanged;
            button.RemoveHandler(UIElement.MouseLeftButtonDownEvent, new MouseButtonEventHandler(ButtonMouseChanged));
            button.RemoveHandler(UIElement.MouseLeftButtonUpEvent, new MouseButtonEventHandler(ButtonMouseChanged));
            button.RemoveHandler(Keyboard.KeyDownEvent, new KeyEventHandler(ButtonKeyChanged));
            button.RemoveHandler(Keyboard.KeyUpEvent, new KeyEventHandler(ButtonKeyChanged));
            button.LostMouseCapture -= PointerChanged;
            button.IsEnabledChanged -= ButtonEnabledChanged;
            if (button is ToggleButton toggle)
            {
                toggle.Checked -= SelectionChanged;
                toggle.Unchecked -= SelectionChanged;
            }
        }
    }

    private static void ButtonLoaded(object sender, RoutedEventArgs args)
    {
        UpdateButton((ButtonBase)sender);
        if (sender is ToggleButton toggle) UpdateSelection(toggle, animate: false);
    }
    private static void PointerChanged(object sender, MouseEventArgs args) => UpdateButton((ButtonBase)sender);
    private static void ButtonMouseChanged(object sender, MouseButtonEventArgs args) => UpdateButton((ButtonBase)sender);
    private static void ButtonKeyChanged(object sender, KeyEventArgs args) => UpdateButton((ButtonBase)sender);
    private static void ButtonEnabledChanged(object sender, DependencyPropertyChangedEventArgs args) => UpdateButton((ButtonBase)sender);
    private static void SelectionChanged(object sender, RoutedEventArgs args) => UpdateSelection((ToggleButton)sender, animate: true);

    private static void UpdateButton(ButtonBase button)
    {
        bool pressed = button.IsEnabled && button.IsPressed;
        double opacity = !button.IsEnabled ? (button.Tag as string == "Timing" ? 0.72 : 0.35) : pressed ? 0.82 : button.IsMouseOver ? 0.94 : 1;
        button.BeginAnimation(UIElement.OpacityProperty, Fade(button.Opacity, opacity, 0.13));
        if (button.RenderTransform is not ScaleTransform scale) return;
        double size = pressed && AnimationsEnabled ? 0.98 : 1;
        scale.BeginAnimation(ScaleTransform.ScaleXProperty, Fade(scale.ScaleX, size, 0.13));
        scale.BeginAnimation(ScaleTransform.ScaleYProperty, Fade(scale.ScaleY, size, 0.13));
    }

    private static void UpdateSelection(ToggleButton button, bool animate)
    {
        if (button.Template?.FindName("SelectionFill", button) is not Border fill) return;
        double opacity = button.IsChecked == true ? 1 : 0;
        if (animate) fill.BeginAnimation(UIElement.OpacityProperty, Fade(fill.Opacity, opacity, 0.22));
        else { fill.BeginAnimation(UIElement.OpacityProperty, null); fill.Opacity = opacity; }
    }

    private static void PopupEntranceChanged(DependencyObject target, DependencyPropertyChangedEventArgs args)
    {
        if (target is not FrameworkElement body) return;
        if ((bool)args.NewValue) body.IsVisibleChanged += PopupVisibilityChanged;
        else body.IsVisibleChanged -= PopupVisibilityChanged;
    }
    private static void PopupVisibilityChanged(object sender, DependencyPropertyChangedEventArgs args)
    {
        if ((bool)args.NewValue) Reveal((FrameworkElement)sender, 6);
    }

    internal static void Reveal(FrameworkElement body, double distance = 8)
    {
        if (!body.IsVisible) return;
        var offset = body.RenderTransform as TranslateTransform ?? new TranslateTransform();
        body.RenderTransform = offset;
        body.BeginAnimation(UIElement.OpacityProperty, Fade(0, 1, 0.26));
        offset.BeginAnimation(TranslateTransform.YProperty,
            Fade(AnimationsEnabled ? distance : 0, 0, 0.26));
    }

    internal static void RevealSymbol(FrameworkElement symbol)
    {
        double size = AnimationsEnabled ? 0.88 : 1;
        var scale = new ScaleTransform(size, size);
        var offset = new TranslateTransform(0, AnimationsEnabled ? 3 : 0);
        var transforms = new TransformGroup();
        transforms.Children.Add(scale);
        transforms.Children.Add(offset);
        symbol.RenderTransform = transforms;
        symbol.RenderTransformOrigin = new Point(0.5, 0.5);
        symbol.Opacity = 0;
        var duration = TimeSpan.FromSeconds(AnimationsEnabled ? 0.4 : 0.1);
        var delay = TimeSpan.FromSeconds(AnimationsEnabled ? 0.04 : 0);
        DoubleAnimation Motion(double from, double to) => new(from, to, duration)
            { BeginTime = delay, EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } };
        symbol.BeginAnimation(UIElement.OpacityProperty, Motion(0, 1));
        scale.BeginAnimation(ScaleTransform.ScaleXProperty, Motion(AnimationsEnabled ? 0.88 : 1, 1));
        scale.BeginAnimation(ScaleTransform.ScaleYProperty, Motion(AnimationsEnabled ? 0.88 : 1, 1));
        offset.BeginAnimation(TranslateTransform.YProperty, Motion(AnimationsEnabled ? 3 : 0, 0));
    }

    internal static void ChangeReadout(TextBlock current, TextBlock previous, string value, bool animate)
    {
        if (current.Text == value) return;
        previous.Text = current.Text;
        previous.FontSize = current.FontSize;
        previous.FontWeight = current.FontWeight;
        previous.LayoutTransform = current.LayoutTransform.CloneCurrentValue();
        current.Text = value;
        var incoming = current.RenderTransform as TranslateTransform ?? new TranslateTransform();
        var outgoing = previous.RenderTransform as TranslateTransform ?? new TranslateTransform();
        current.RenderTransform = incoming;
        previous.RenderTransform = outgoing;
        if (animate && current.IsVisible && previous.Text.Length > 0)
        {
            double distance = AnimationsEnabled ? 6 : 0;
            current.BeginAnimation(UIElement.OpacityProperty, Fade(0, 1, 0.26));
            previous.BeginAnimation(UIElement.OpacityProperty, Fade(0.8, 0, 0.2));
            incoming.BeginAnimation(TranslateTransform.YProperty, Fade(distance, 0, 0.26));
            outgoing.BeginAnimation(TranslateTransform.YProperty, Fade(0, -distance, 0.2));
        }
        else
        {
            current.BeginAnimation(UIElement.OpacityProperty, null);
            previous.BeginAnimation(UIElement.OpacityProperty, null);
            incoming.BeginAnimation(TranslateTransform.YProperty, null);
            outgoing.BeginAnimation(TranslateTransform.YProperty, null);
            current.Opacity = 1;
            previous.Opacity = 0;
            incoming.Y = outgoing.Y = 0;
        }
    }

    private static DoubleAnimation Fade(double from, double to, double seconds) =>
        new(from, to, TimeSpan.FromSeconds(AnimationsEnabled ? seconds : 0.1))
        { EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } };
}
