using System;
using System.Threading;
using System.Windows;
using System.Windows.Threading;

namespace TeaPanel;

public partial class App : Application
{
    private Mutex? instance;
    private TrayHost? host;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
#if TEA_PANEL_TESTING
        if (e.Args.Length == 2 && e.Args[0] == "--verify-ui")
        {
            _ = DesktopChecks.Run(this, e.Args[1]);
            return;
        }
#endif
        instance = new Mutex(true, "Local\\TeaPanel.Windows", out bool created);
        if (!created) { instance.Dispose(); instance = null; Shutdown(); return; }
        var storage = new PreferenceStorage();
        var preferences = storage.Load();
        var store = new TeaStore(preferences, save: storage.Save, storageMessage: storage.LoadMessage);
        host = new(store, Quit);
        Dispatcher.BeginInvoke(host.ShowMenu, DispatcherPriority.ApplicationIdle);
    }

    private void Quit()
    {
        host?.Dispose();
        host = null;
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        host?.Dispose();
        if (instance is not null) { instance.ReleaseMutex(); instance.Dispose(); }
        base.OnExit(e);
    }
}
