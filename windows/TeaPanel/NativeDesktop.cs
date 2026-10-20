using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using Forms = System.Windows.Forms;

namespace TeaPanel;

internal static class NativeDesktop
{
    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr window, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr window);
    [DllImport("user32.dll")]
    internal static extern IntPtr GetForegroundWindow();

    internal static void Place(Window window, bool reminder)
    {
        var cursor = Forms.Cursor.Position;
        var work = Forms.Screen.FromPoint(cursor).WorkingArea;
        IntPtr handle = new WindowInteropHelper(window).EnsureHandle();
        const uint noSize = 0x0001, noZOrder = 0x0004, noActivate = 0x0010;
        // Move the hidden HWND to the target monitor before measuring its per-monitor DPI.
        SetWindowPos(handle, IntPtr.Zero, work.Left + 16, work.Top + 16, 0, 0, noSize | noZOrder | noActivate);
        double scale = Math.Max(96u, GetDpiForWindow(handle)) / 96.0;
        window.MaxHeight = Math.Max(150, work.Height / scale - 20);
        window.MaxWidth = Math.Max(200, work.Width / scale - 20);
        window.Width = Math.Min(reminder ? 460 : 404, window.MaxWidth);
        window.Height = Math.Min(reminder ? 320 : 688, window.MaxHeight);
        int width = (int)Math.Round(window.Width * scale);
        int height = (int)Math.Round(window.Height * scale);
        int x = reminder ? work.Left + (work.Width - width) / 2 : cursor.X - width / 2;
        int y = reminder ? work.Top + (int)(18 * scale) : cursor.Y - height - (int)(8 * scale);
        x = Math.Clamp(x, work.Left + 2, Math.Max(work.Left + 2, work.Right - width - 2));
        y = Math.Clamp(y, work.Top + 2, Math.Max(work.Top + 2, work.Bottom - height - 2));
        SetWindowPos(handle, IntPtr.Zero, x, y, width, height, noZOrder | noActivate);
    }
}
