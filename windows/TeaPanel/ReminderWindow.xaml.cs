using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Input;

namespace TeaPanel;

public partial class ReminderWindow : Window
{
    private Guid currentId;
    internal bool MayClose { get; set; }
    public event Action<Guid>? ConfirmRequested;
    public event Action<Guid>? EndRequested;

    public ReminderWindow()
    {
        InitializeComponent();
        IsVisibleChanged += (_, args) => { if ((bool)args.NewValue) TeaMotion.RevealSymbol(TeaSymbol); };
    }

    public void SetReminder(TeaReminder reminder)
    {
        currentId = reminder.Id;
        PreviewLabel.Text = reminder.IsPreview ? "提醒预览" : "T E A  P A N E L";
        TeaLabel.Text = $"{reminder.Configuration.Name} · 第 {reminder.Infusion} 泡";
        TeaLabel.ToolTip = TeaLabel.Text;
        TeaSymbol.Data = TeaIcons.Get(reminder.Configuration.Icon);
        ReminderTitle.Text = reminder.Kind == ReminderKind.AddLeaves ? "晾水计时结束" : "你的茶，泡好了";
        ReminderSubtitle.Text = reminder.Kind == ReminderKind.TeaReady ? "取出茶滤或倒出茶汤，留一点时间慢慢喝。"
            : reminder.Infusion == 1 ? $"请放入 {TeaText.Grams(reminder.Grams)} 克干茶，投茶后再开始计时。" : "请放回原茶叶，不用再加干茶。";
        ConfirmButton.Content = reminder.IsPreview ? "看到了" : reminder.Kind == ReminderKind.TeaReady ? "知道了，去喝茶"
            : reminder.Infusion == 1 ? "已投茶，开始泡茶" : $"已放回，开始第 {reminder.Infusion} 泡";
        bool canEnd = reminder.Kind == ReminderKind.AddLeaves && !reminder.IsPreview;
        EndButton.Visibility = canEnd ? Visibility.Visible : Visibility.Collapsed;
        FooterText.Visibility = canEnd ? Visibility.Collapsed : Visibility.Visible;
        FooterText.Text = reminder.IsPreview ? "实际到点后也会这样提醒，直到你点击处理" : "静音提醒 · 等你处理后再收起";
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!MayClose) e.Cancel = true;
        base.OnClosing(e);
    }
    private void OnConfirm(object sender, RoutedEventArgs e) => ConfirmRequested?.Invoke(currentId);
    private void OnEnd(object sender, RoutedEventArgs e) => EndRequested?.Invoke(currentId);
    private void OnDrag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed) DragMove();
    }
}
