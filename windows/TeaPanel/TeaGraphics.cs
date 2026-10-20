using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace TeaPanel;

public static class TeaIcons
{
    public static readonly string[] Names = ["茶叶", "花朵", "茶杯", "马克杯", "水滴", "太阳", "月亮", "星光", "火焰", "爱心"];
    private static readonly string[] Paths =
    [
        "M3,3 C7,7 13,3 18,6 C23,9 20,14 23,19 C25,22 22,24 21,21 C18,16 15,18 11,17 C5,16 3,12 3,3 Z M7,8 C11,12 16,9 20,16 C16,12 11,13 7,8 Z",
        "M6,1 L10,5 L13,1 L16,5 L20,1 L20,7 C20,12 17,14 14,14 L14,23 L12,23 L12,14 C8,14 5,11 5,7 Z M11,22 C5,22 2,18 2,15 C8,15 11,18 11,22 Z M15,22 C21,22 24,18 24,15 C18,15 15,18 15,22 Z",
        "M4,6 C4,2 20,2 20,6 L20,10 C20,18 4,18 4,10 Z M6,6 C6,8.5 18,8.5 18,6 C18,3.5 6,3.5 6,6 Z M20,6 C28,4 28,13 20,14 L20,11.5 C25,11.5 25,7 20,8.5 Z M2,14 C3,21 22,21 24,14 C30,23 -3,25 2,14 Z",
        "M3,3 L17,3 L17,19 Q17,22 14,22 L6,22 Q3,22 3,19 Z M17,7 L17,16 C25,17 26,6 17,7 Z",
        "M12,1 C9,7 3,11 3,16 A9,8 0 1 0 21,16 C21,11 15,7 12,1 Z",
        "M12,6 A6,6 0 1 1 11.99,6 Z M11,0 L13,0 L13,4 L11,4 Z M11,20 L13,20 L13,24 L11,24 Z M0,11 L4,11 L4,13 L0,13 Z M20,11 L24,11 L24,13 L20,13 Z M3,2 L6,5 L5,6 L2,3 Z M18,18 L21,21 L22,20 L19,17 Z M18,5 L21,2 L22,3 L19,6 Z M2,21 L5,18 L6,19 L3,22 Z",
        "M18,2 A10,10 0 1 0 22,18 A11,11 0 0 1 18,2 Z",
        "M12,1 L15,8 L23,9 L17,14 L19,23 L12,18 L5,23 L7,14 L1,9 L9,8 Z",
        "M12,1 C13,8 23,10 21,18 C19,27 3,25 3,17 C3,12 7,9 8,6 C8,13 13,13 12,1 Z",
        "M12,22 L3,13 C-4,4 6,-2 12,5 C18,-2 28,4 21,13 Z"
    ];
    private static readonly Dictionary<TeaIcon, Geometry> Cache = new();
    public static Geometry Leaf => Get(TeaIcon.Leaf);
    public static Geometry Flower => Get(TeaIcon.Flower);
    public static Geometry Cup => Get(TeaIcon.Cup);
    public static Geometry Settings { get; } = Make("M1,4 L8,4 M13,4 L20,4 M1,10 L4,10 M9,10 L20,10 M1,16 L11,16 M16,16 L20,16 M9,2 L12,2 Q13,2 13,3 L13,5 Q13,6 12,6 L9,6 Q8,6 8,5 L8,3 Q8,2 9,2 Z M5,8 L8,8 Q9,8 9,9 L9,11 Q9,12 8,12 L5,12 Q4,12 4,11 L4,9 Q4,8 5,8 Z M12,14 L15,14 Q16,14 16,15 L16,17 Q16,18 15,18 L12,18 Q11,18 11,17 L11,15 Q11,14 12,14 Z");
    private static readonly Geometry DropOutline = Make("M12,2 C9,7 4,11 4,16 A8,7 0 1 0 20,16 C20,11 15,7 12,2 Z");
    private static readonly Geometry LeavesOutline = Make("M4,14 C3,5 12,3 18,5 C18,13 12,17 5,14 M6,12 L14,7 M3,17 A10,10 0 0 0 21,17 M18,18 L22,17 L22,21");
    private static readonly Geometry CupOutline = Make("M3,6 C3,2 19,2 19,6 C19,10 3,10 3,6 Z M3,6 L3,11 C3,19 19,19 19,11 L19,6 M19,8 C26,5 26,14 19,14 M1,18 C3,23 21,23 24,18");
    private static readonly Geometry CheckOutline = Make("M3,12 L9,18 L22,4");
    private static readonly Geometry RefillOutline = Make("M20,8 A9,9 0 1 0 21,17 M16,8 L21,8 L21,3");
    public static Geometry? State(TeaPhase phase) => phase switch
    {
        TeaPhase.Cooling => DropOutline,
        TeaPhase.WaitingForLeaves => LeavesOutline,
        TeaPhase.Brewing => CupOutline,
        TeaPhase.Ready => CheckOutline,
        TeaPhase.PreparingRefill => RefillOutline,
        _ => null
    };

    private static Geometry Make(string path)
    {
        var geometry = Geometry.Parse(path);
        geometry.Freeze();
        return geometry;
    }

    public static Geometry Get(TeaIcon icon)
    {
        if (!Cache.TryGetValue(icon, out var geometry))
        {
            geometry = Geometry.Parse(Paths[(int)icon]);
            geometry.Freeze();
            Cache[icon] = geometry;
        }
        return geometry;
    }
}

public sealed class TeaProgressRing : FrameworkElement
{
    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(nameof(Progress), typeof(double),
        typeof(TeaProgressRing), new PropertyMetadata(1.0, ProgressChanged));
    public double Progress { get => (double)GetValue(ProgressProperty); set => SetValue(ProgressProperty, value); }
    public static readonly DependencyProperty IsTimingProperty = DependencyProperty.Register(nameof(IsTiming), typeof(bool),
        typeof(TeaProgressRing), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, TimingChanged));
    public bool IsTiming { get => (bool)GetValue(IsTimingProperty); set => SetValue(IsTimingProperty, value); }
    private static readonly DependencyProperty DisplayedProgressProperty = DependencyProperty.Register("DisplayedProgress", typeof(double),
        typeof(TeaProgressRing), new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender));
    private static void TimingChanged(DependencyObject target, DependencyPropertyChangedEventArgs args)
    {
        var ring = (TeaProgressRing)target;
        ring.BeginAnimation(DisplayedProgressProperty, null);
        ring.SetValue(DisplayedProgressProperty, ring.Progress);
    }
    private static void ProgressChanged(DependencyObject target, DependencyPropertyChangedEventArgs args)
    {
        var ring = (TeaProgressRing)target;
        double before = (double)ring.GetValue(DisplayedProgressProperty);
        ring.SetValue(DisplayedProgressProperty, (double)args.NewValue);
        ring.BeginAnimation(DisplayedProgressProperty, ring.IsLoaded && ring.IsTiming && TeaMotion.AnimationsEnabled
            ? new DoubleAnimation(before, (double)args.NewValue, TimeSpan.FromSeconds(0.5)) : null);
    }

    protected override void OnRender(DrawingContext drawing)
    {
        double radius = Math.Max(0, Math.Min(ActualWidth, ActualHeight) / 2 - 1.5);
        var center = new Point(ActualWidth / 2, ActualHeight / 2);
        var background = new Pen((Brush)FindResource("Pale"), 3);
        var foreground = new Pen((Brush)FindResource("Green"), 3) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round };
        drawing.DrawEllipse(null, background, center, radius, radius);
        if (!IsTiming) return;
        double progress = Math.Clamp((double)GetValue(DisplayedProgressProperty), 0, 1);
        if (progress >= 1) drawing.DrawEllipse(null, foreground, center, radius, radius);
        else if (progress > 0)
        {
            double angle = progress * Math.PI * 2 - Math.PI / 2;
            var geometry = new StreamGeometry();
            using (var context = geometry.Open())
            {
                context.BeginFigure(new Point(center.X, center.Y - radius), false, false);
                context.ArcTo(new Point(center.X + Math.Cos(angle) * radius, center.Y + Math.Sin(angle) * radius),
                    new Size(radius, radius), 0, progress > 0.5, SweepDirection.Clockwise, true, false);
            }
            drawing.DrawGeometry(null, foreground, geometry);
        }
    }
}
