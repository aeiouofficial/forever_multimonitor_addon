using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace ForeverMultiMonitor.WindowsHelper;

internal static class Program
{
    private const uint MonitorInfoPrimary = 1;
    private const int GwlStyle = -16;
    private const int GwlExStyle = -20;
    private const long WsCaption = 0x00C00000L;
    private const long WsThickFrame = 0x00040000L;
    private const long WsMinimizeBox = 0x00020000L;
    private const long WsMaximizeBox = 0x00010000L;
    private const long WsSysMenu = 0x00080000L;
    private const long WsExDlgModalFrame = 0x00000001L;
    private const long WsExWindowEdge = 0x00000100L;
    private const long WsExClientEdge = 0x00000200L;
    private const long WsExStaticEdge = 0x00020000L;
    private const uint SwpNoZOrder = 0x0004;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpFrameChanged = 0x0020;
    private const int SwRestore = 9;

    private static readonly string StatePath = Path.Combine(AppContext.BaseDirectory, "window-state.json");
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true, IncludeFields = true };

    private delegate bool MonitorEnumProc(nint monitor, nint dc, nint rect, nint data);

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct MonitorInfoEx
    {
        public int Size;
        public Rect Monitor;
        public Rect Work;
        public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Device;
    }

    private sealed record MonitorRecord(string Device, string DeviceId, string Name, bool Primary, int Left, int Top, int Right, int Bottom, uint DpiX, uint DpiY)
    {
        public int Width => Right - Left;
        public int Height => Bottom - Top;
    }

    private sealed record WindowState(int ProcessId, long Handle, long OriginalStyle, long OriginalExtendedStyle, WindowPlacement OriginalPlacement, string[] Displays, DateTimeOffset SavedAt);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)]
    private struct WindowPlacement { public int Length; public uint Flags, ShowCommand; public NativePoint MinPosition, MaxPosition; public Rect NormalPosition; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DisplayDevice
    {
        public int Size;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public uint StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceId;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [DllImport("user32.dll")] private static extern bool SetProcessDpiAwarenessContext(nint value);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool EnumDisplayMonitors(nint dc, nint clip, MonitorEnumProc callback, nint data);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool GetMonitorInfo(nint monitor, ref MonitorInfoEx info);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool EnumDisplayDevices(string? device, uint index, ref DisplayDevice displayDevice, uint flags);
    [DllImport("shcore.dll", SetLastError = true)] private static extern int GetDpiForMonitor(nint monitor, int dpiType, out uint dpiX, out uint dpiY);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool EnumWindows(EnumWindowsProc callback, nint data);
    private delegate bool EnumWindowsProc(nint hwnd, nint data);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(nint hwnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(nint hwnd, System.Text.StringBuilder text, int maxCount);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(nint hwnd, out uint processId);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetWindowRect(nint hwnd, out Rect rect);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetWindowPlacement(nint hwnd, ref WindowPlacement placement);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPlacement(nint hwnd, ref WindowPlacement placement);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)] private static extern nint GetWindowLongPtr(nint hwnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)] private static extern nint SetWindowLongPtr(nint hwnd, int index, nint value);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPos(nint hwnd, nint insertAfter, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] private static extern bool ShowWindow(nint hwnd, int command);
    [DllImport("user32.dll")] private static extern bool IsWindow(nint hwnd);

    private static int Main(string[] args)
    {
        try
        {
            _ = SetProcessDpiAwarenessContext(new nint(-4)); // PER_MONITOR_AWARE_V2; best effort for physical-pixel coordinates.
            if (args.Length == 0 || args[0] is "help" or "--help" or "-h") { PrintHelp(); return 0; }
            return args[0].ToLowerInvariant() switch
            {
                "list" => ListDisplays(),
                "place" => Place(args),
                "restore" => Restore(),
                _ => Fail("Unknown command. Run `ForeverMultiMonitor.WindowsHelper help`.")
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"ERROR {ex.GetType().Name}: {ex.Message}");
            return 1;
        }
    }

    private static void PrintHelp()
    {
        Console.WriteLine("Forever MultiMonitor Windows Helper");
        Console.WriteLine("  list");
        Console.WriteLine("  place --monitors \\\\.\\DISPLAY1[,\\\\.\\DISPLAY2] [--process auto|Wow.exe]");
        Console.WriteLine("  restore");
        Console.WriteLine("Placement is one-shot. Original window style and full WINDOWPLACEMENT are saved for restore.");
        Console.WriteLine("No service, startup task, telemetry, network connection or Companion protocol is used.");
    }

    private static int ListDisplays()
    {
        foreach (var monitor in EnumerateMonitors())
        {
            Console.WriteLine($"{monitor.Device} | {monitor.Name} | {monitor.Width}x{monitor.Height} at ({monitor.Left},{monitor.Top}) | DPI {monitor.DpiX}x{monitor.DpiY} | {(monitor.Primary ? "Primary" : "Secondary")}");
            Console.WriteLine($"  DeviceId: {monitor.DeviceId}");
        }
        return 0;
    }

    private static List<MonitorRecord> EnumerateMonitors()
    {
        var result = new List<MonitorRecord>();
        MonitorEnumProc callback = (handle, _, _, _) =>
        {
            var info = new MonitorInfoEx { Size = Marshal.SizeOf<MonitorInfoEx>(), Device = string.Empty };
            if (!GetMonitorInfo(handle, ref info)) return true;
            var device = new DisplayDevice { Size = Marshal.SizeOf<DisplayDevice>() };
            _ = EnumDisplayDevices(info.Device, 0, ref device, 0);
            uint dpiX = 96, dpiY = 96;
            try { _ = GetDpiForMonitor(handle, 0, out dpiX, out dpiY); } catch (DllNotFoundException) { }
            catch (EntryPointNotFoundException) { }
            result.Add(new MonitorRecord(info.Device, device.DeviceId ?? string.Empty, device.DeviceString ?? info.Device,
                (info.Flags & MonitorInfoPrimary) != 0, info.Monitor.Left, info.Monitor.Top, info.Monitor.Right, info.Monitor.Bottom, dpiX, dpiY));
            return true;
        };
        if (!EnumDisplayMonitors(0, 0, callback, 0)) throw new InvalidOperationException("EnumDisplayMonitors failed.");
        return result.OrderByDescending(m => m.Primary).ThenBy(m => m.Left).ThenBy(m => m.Top).ToList();
    }

    private static int Place(string[] args)
    {
        var monitorArgument = ValueAfter(args, "--monitors");
        if (string.IsNullOrWhiteSpace(monitorArgument)) return Fail("Missing --monitors. Run `list` first.");
        var processName = ValueAfter(args, "--process") ?? "auto";
        var available = EnumerateMonitors();
        var requested = monitorArgument.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (requested.Length == 0 || requested.Distinct(StringComparer.OrdinalIgnoreCase).Count() != requested.Length) return Fail("Monitor selection is empty or contains duplicates.");
        var selected = requested.Select(name => available.FirstOrDefault(m => string.Equals(m.Device, name, StringComparison.OrdinalIgnoreCase))).ToArray();
        if (selected.Any(m => m is null)) return Fail("A selected display is no longer connected. Run `list` again.");
        var monitors = selected.Cast<MonitorRecord>().ToArray();
        if (monitors.Length > 8) return Fail("At most eight displays may be selected.");

        var window = FindGameWindow(processName);
        if (window == 0) return Fail($"No visible top-level window found for process `{processName}`.");
        if (File.Exists(StatePath)) return Fail($"Restore state already exists at {StatePath}. Run `restore` before placing again.");
        var originalPlacement = new WindowPlacement { Length = Marshal.SizeOf<WindowPlacement>() };
        if (!GetWindowPlacement(window, ref originalPlacement)) return Fail("Could not read the original WoW window placement.");

        var left = monitors.Min(m => m.Left);
        var top = monitors.Min(m => m.Top);
        var right = monitors.Max(m => m.Right);
        var bottom = monitors.Max(m => m.Bottom);
        if (right <= left || bottom <= top) return Fail("Selected display bounds are invalid.");

        var processId = GetWindowThreadProcessId(window, out var pid);
        if (processId == 0 || pid == 0) return Fail("Could not resolve the selected window process.");
        var style = GetWindowLongPtr(window, GwlStyle).ToInt64();
        var exStyle = GetWindowLongPtr(window, GwlExStyle).ToInt64();
        var state = new WindowState((int)pid, window.ToInt64(), style, exStyle, originalPlacement, monitors.Select(m => m.Device).ToArray(), DateTimeOffset.UtcNow);
        Directory.CreateDirectory(Path.GetDirectoryName(StatePath)!);
        WriteStateAtomically(state);

        ShowWindow(window, SwRestore);
        var borderlessStyle = style & ~(WsCaption | WsThickFrame | WsMinimizeBox | WsMaximizeBox | WsSysMenu);
        var borderlessExStyle = exStyle & ~(WsExDlgModalFrame | WsExWindowEdge | WsExClientEdge | WsExStaticEdge);
        if (!TrySetWindowLong(window, GwlStyle, new nint(borderlessStyle)) || !TrySetWindowLong(window, GwlExStyle, new nint(borderlessExStyle)))
        {
            var styleError = Marshal.GetLastWin32Error();
            if (RestoreState(state)) File.Delete(StatePath);
            throw new InvalidOperationException($"Could not set borderless window styles (Win32 error {styleError}).");
        }
        if (!SetWindowPos(window, 0, left, top, right - left, bottom - top, SwpNoZOrder | SwpNoActivate | SwpFrameChanged))
        {
            var error = Marshal.GetLastWin32Error();
            if (RestoreState(state)) File.Delete(StatePath);
            throw new InvalidOperationException($"SetWindowPos failed with Win32 error {error}; original window state restore was attempted.");
        }
        Console.WriteLine($"Placed WoW window across {string.Join(", ", state.Displays)} at ({left},{top}) size {right-left}x{bottom-top}.");
        Console.WriteLine("The addon now sees the combined logical UIParent canvas. Run /fmm config and apply its Mainhand split.");
        Console.WriteLine("Run `restore` to restore the original window bounds and styles.");
        return 0;
    }

    private static int Restore()
    {
        if (!File.Exists(StatePath)) return Fail("No saved window state exists; nothing to restore.");
        var state = JsonSerializer.Deserialize<WindowState>(File.ReadAllText(StatePath)) ?? throw new InvalidDataException("Saved window state is invalid.");
        if (!RestoreState(state)) return Fail("Restore failed; state file was retained for retry.");
        File.Delete(StatePath);
        Console.WriteLine("Original WoW window bounds and styles restored.");
        return 0;
    }

    private static bool RestoreState(WindowState state)
    {
        var hwnd = new nint(state.Handle);
        if (!IsWindow(hwnd)) return false;
        GetWindowThreadProcessId(hwnd, out var pid);
        if (pid != (uint)state.ProcessId) return false;
        if (!TrySetWindowLong(hwnd, GwlStyle, new nint(state.OriginalStyle))) return false;
        if (!TrySetWindowLong(hwnd, GwlExStyle, new nint(state.OriginalExtendedStyle))) return false;
        if (!SetWindowPos(hwnd, 0, state.OriginalPlacement.NormalPosition.Left, state.OriginalPlacement.NormalPosition.Top, state.OriginalPlacement.NormalPosition.Right - state.OriginalPlacement.NormalPosition.Left, state.OriginalPlacement.NormalPosition.Bottom - state.OriginalPlacement.NormalPosition.Top, SwpNoZOrder | SwpNoActivate | SwpFrameChanged)) return false;
        var placement = state.OriginalPlacement;
        placement.Length = Marshal.SizeOf<WindowPlacement>();
        return SetWindowPlacement(hwnd, ref placement);
    }

    private static bool TrySetWindowLong(nint hwnd, int index, nint value)
    {
        Marshal.SetLastPInvokeError(0);
        var previous = SetWindowLongPtr(hwnd, index, value);
        return previous != 0 || Marshal.GetLastPInvokeError() == 0;
    }

    private static void WriteStateAtomically(WindowState state)
    {
        var temporary = StatePath + ".new";
        File.WriteAllText(temporary, JsonSerializer.Serialize(state, JsonOptions));
        if (File.Exists(StatePath)) File.Delete(StatePath);
        File.Move(temporary, StatePath);
    }

    private static nint FindGameWindow(string processName)
    {
        var processNames = processName.Equals("auto", StringComparison.OrdinalIgnoreCase)
            ? new[] { "Wow", "Wow-64", "WowClassic", "World of Warcraft" }
            : new[] { Path.GetFileNameWithoutExtension(processName) };
        var ids = new HashSet<uint>();
        foreach (var name in processNames)
        {
            foreach (var process in Process.GetProcessesByName(name)) ids.Add((uint)process.Id);
        }
        if (ids.Count == 0) return 0;
        nint found = 0;
        EnumWindows((hwnd, _) =>
        {
            if (!IsWindowVisible(hwnd)) return true;
            GetWindowThreadProcessId(hwnd, out var pid);
            if (!ids.Contains(pid)) return true;
            var title = new System.Text.StringBuilder(256);
            _ = GetWindowText(hwnd, title, title.Capacity);
            if (title.Length == 0) return true;
            found = hwnd;
            return false;
        }, 0);
        return found;
    }

    private static string? ValueAfter(string[] args, string key)
    {
        for (var index = 1; index < args.Length - 1; index++) if (args[index].Equals(key, StringComparison.OrdinalIgnoreCase)) return args[index + 1];
        return null;
    }

    private static int Fail(string message) { Console.Error.WriteLine("ERROR: " + message); return 2; }
}