using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace TeaPanel;

public sealed class PanelMotion
{
    private readonly Window window;
    private readonly FrameworkElement body;
    private readonly bool reminder;
    private readonly Func<bool> animationsEnabled;
    private readonly TranslateTransform offset = new();
    private int generation;
    private bool dismissing;
    public bool IsPresented { get; private set; }

    public PanelMotion(Window window, FrameworkElement body, bool reminder = false, Func<bool>? animationsEnabled = null)
    {
        this.window = window;
        this.body = body;
        this.reminder = reminder;
        this.animationsEnabled = animationsEnabled ?? (() => TeaMotion.AnimationsEnabled);
        body.RenderTransform = offset;
    }

    public void Show()
    {
        bool fresh = !window.IsVisible || (!IsPresented && !dismissing);
        generation++;
        IsPresented = true;
        dismissing = false;
        body.IsHitTestVisible = true;
        bool animate = animationsEnabled();
        if (fresh)
        {
            body.BeginAnimation(UIElement.OpacityProperty, null);
            offset.BeginAnimation(TranslateTransform.YProperty, null);
            body.Opacity = 0;
            offset.Y = animate ? (reminder ? -12 : 10) : 0;
        }
        window.Show();
        if (!reminder) { window.Activate(); body.Focus(); }
        var duration = TimeSpan.FromSeconds(animate ? (reminder ? 0.36 : 0.3) : 0.1);
        body.BeginAnimation(UIElement.OpacityProperty, Animation(body.Opacity, 1, duration));
        offset.BeginAnimation(TranslateTransform.YProperty, Animation(offset.Y, 0, duration));
    }

    public void Hide()
    {
        if (!IsPresented) return;
        IsPresented = false;
        dismissing = true;
        int dismissal = ++generation;
        body.IsHitTestVisible = false;
        bool animate = animationsEnabled();
        var duration = TimeSpan.FromSeconds(animate ? (reminder ? 0.22 : 0.16) : 0.1);
        var fade = Animation(body.Opacity, 0, duration);
        fade.Completed += (_, _) =>
        {
            if (dismissal != generation || IsPresented) return;
            dismissing = false;
            window.Hide();
        };
        body.BeginAnimation(UIElement.OpacityProperty, fade);
        offset.BeginAnimation(TranslateTransform.YProperty, Animation(offset.Y, animate ? 5 : 0, duration));
    }

    public void Stop()
    {
        generation++;
        IsPresented = false;
        body.BeginAnimation(UIElement.OpacityProperty, null);
        offset.BeginAnimation(TranslateTransform.YProperty, null);
    }

    private static DoubleAnimation Animation(double from, double to, TimeSpan duration) => new(from, to, duration)
    { EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } };
}
