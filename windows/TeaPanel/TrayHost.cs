using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace TeaPanel;

public sealed class TrayHost : IDisposable
{
    private readonly TeaStore store;
    private readonly Action quit;
    private readonly Forms.NotifyIcon tray;
    private readonly Icon icon;
    private readonly PanelMotion menuMotion;
    private readonly PanelMotion reminderMotion;
    private readonly DispatcherTimer clock;
    private Guid? shownReminder;
    private long deactivatedAt;
    private System.Drawing.Point deactivatedCursor;
    private bool disposed;
    public MenuWindow Menu { get; }
    public ReminderWindow Reminder { get; }
    internal bool IsMenuPresented => menuMotion.IsPresented;
    internal bool IsTrayVisible => tray.Visible;
#if TEA_PANEL_TESTING
    // Layout probes must stay visible if the user interacts with another desktop app.
    // The runner enables real dismissal separately for the focus-transfer check.
    internal bool HoldMenuForLayoutChecks { get; set; }
#endif

    public TrayHost(TeaStore store, Action quit)
    {
        this.store = store;
        this.quit = quit;
        Menu = new(store);
        Reminder = new();
        menuMotion = new(Menu, Menu.PanelBody);
        reminderMotion = new(Reminder, Reminder.PanelBody, reminder: true);
        using (var resource = Application.GetResourceStream(new Uri("pack://application:,,,/Assets/AppIcon.ico"))!.Stream)
        using (var source = new Icon(resource)) icon = (Icon)source.Clone();
        var context = new Forms.ContextMenuStrip();
        context.Items.Add("打开茶伴", null, (_, _) => Menu.Dispatcher.Invoke(ShowMenu));
        context.Items.Add("退出", null, (_, _) => Menu.Dispatcher.Invoke(quit));
        tray = new Forms.NotifyIcon { Icon = icon, ContextMenuStrip = context, Visible = true };
        tray.MouseClick += (_, args) =>
        {
            if (args.Button == Forms.MouseButtons.Left)
            {
                // A tray click can deactivate the panel on mouse-down before MouseClick.
                // Consume that same click so its mouse-up cannot immediately reopen it.
                bool justDismissedHere = Stopwatch.GetElapsedTime(deactivatedAt).TotalMilliseconds < 400
                    && Forms.Cursor.Position == deactivatedCursor;
                deactivatedAt = 0;
                if (!justDismissedHere) ToggleMenu();
            }
            else if (args.Button == Forms.MouseButtons.Right) HideMenu();
        };
        Menu.Deactivated += (_, _) =>
        {
#if TEA_PANEL_TESTING
            if (HoldMenuForLayoutChecks) return;
#endif
            if (!menuMotion.IsPresented) return;
            deactivatedAt = Stopwatch.GetTimestamp();
            deactivatedCursor = Forms.Cursor.Position;
            HideMenu();
        };
        Menu.DismissRequested += HideMenu;
        Menu.PrimaryRequested += PerformPrimary;
        Menu.SkipRequested += () => { store.SkipCooling(); HideIfTiming(); };
        Menu.PreviewRequested += () => { HideMenu(); store.PreviewReminder(); };
        Menu.QuitRequested += quit;
        Reminder.ConfirmRequested += id =>
        {
            if (store.Reminder is not { } reminder || reminder.Id != id) return;
            if (!reminder.IsPreview && reminder.Kind == ReminderKind.AddLeaves) store.ConfirmLeaves();
            else store.DismissReminder();
        };
        Reminder.EndRequested += id => { if (store.Reminder?.Id == id) store.EndRound(); };
        store.PropertyChanged += StoreChanged;
        clock = new DispatcherTimer(TimeSpan.FromMilliseconds(500), DispatcherPriority.Background,
            (_, _) => store.Tick(), Menu.Dispatcher);
        SystemEvents.PowerModeChanged += PowerModeChanged;
        SystemEvents.SessionSwitch += SessionSwitch;
        UpdateStatus();
    }

    public void ShowMenu()
    {
        if (disposed) return;
        if (!menuMotion.IsPresented) NativeDesktop.Place(Menu, reminder: false);
        menuMotion.Show();
    }
    public void HideMenu() => menuMotion.Hide();
    public void ToggleMenu() { if (menuMotion.IsPresented) HideMenu(); else ShowMenu(); }

    private void PerformPrimary()
    {
        switch (store.Phase)
        {
            case TeaPhase.Idle: store.StartNewRound(); break;
            case TeaPhase.Cooling: store.SkipCooling(); break;
            case TeaPhase.WaitingForLeaves: store.ConfirmLeaves(); break;
            case TeaPhase.Ready: store.PrepareRefill(); break;
            case TeaPhase.PreparingRefill: store.StartRefill(); break;
        }
        HideIfTiming();
    }
    private void HideIfTiming() { if (store.Phase is TeaPhase.Cooling or TeaPhase.Brewing) HideMenu(); }

    private void StoreChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is null or nameof(TeaStore.StatusText)) UpdateStatus();
        if (e.PropertyName is not null || store.Reminder?.Id == shownReminder) return;
        shownReminder = store.Reminder?.Id;
        if (store.Reminder is { } reminder)
        {
            Reminder.SetReminder(reminder);
            NativeDesktop.Place(Reminder, reminder: true);
            reminderMotion.Show();
        }
        else reminderMotion.Hide();
    }
    private void UpdateStatus()
    {
        string text = "茶伴 · " + store.DisplayName + (store.IsActive ? $" · 第 {store.DisplayedInfusion} 泡 · {store.StatusText}" : "");
        if (text.Length > 63) text = text[..60] + "...";
        if (tray.Text != text) tray.Text = text;
    }
    private void PowerModeChanged(object sender, PowerModeChangedEventArgs e)
    {
        if (e.Mode == PowerModes.Resume) Menu.Dispatcher.BeginInvoke(() => { if (!disposed) store.Tick(); });
    }
    private void SessionSwitch(object sender, SessionSwitchEventArgs e)
    {
        if (e.Reason == SessionSwitchReason.SessionUnlock) Menu.Dispatcher.BeginInvoke(() => { if (!disposed) store.Tick(); });
    }

    public void Dispose()
    {
        if (disposed) return;
        disposed = true;
        clock.Stop();
        SystemEvents.PowerModeChanged -= PowerModeChanged;
        SystemEvents.SessionSwitch -= SessionSwitch;
        store.PropertyChanged -= StoreChanged;
        tray.Visible = false;
        tray.ContextMenuStrip?.Dispose();
        tray.Dispose();
        icon.Dispose();
        menuMotion.Stop();
        reminderMotion.Stop();
        Menu.MayClose = Reminder.MayClose = true;
        Menu.Close();
        Reminder.Close();
    }
}
