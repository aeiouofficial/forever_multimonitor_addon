using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
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
    private const uint SwpNoMove = 0x0002;
    private const uint SwpNoSize = 0x0001;
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

    private sealed record WindowState(int ProcessId, long Handle, long OriginalStyle, long OriginalExtendedStyle, WindowPlacement OriginalPlacement, string[] Displays, DateTimeOffset SavedAt, string[]? DisplayIds = null, string? AddonDirectory = null, Rect? OriginalScreenRect = null);

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
                "watch" => Watch(args),
                "restore" => Restore(),
                "self-test" => SelfTest(),
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
        Console.WriteLine("  place --monitors <display1[,display2]> [--single-ultrawide] [--process auto|Wow.exe] [--pid <process-id>]");
        Console.WriteLine("  watch --monitors <display1[,display2]> [--single-ultrawide] [--process auto|Wow.exe] [--interval-ms 1000]");
        Console.WriteLine("  Without --single-ultrawide, spanning requires exactly two selected displays.");
        Console.WriteLine("  --single-ultrawide requires exactly one display and --addon-dir for the addon mode handoff.");
        Console.WriteLine("  restore");
        Console.WriteLine("  self-test");
        Console.WriteLine("  Add --addon-dir <absolute AddOns\\ForeverMultiMonitor path> to place/watch for Lua geometry handoff.");
        Console.WriteLine("  Add --mainmonitor <selected display name> to choose the MainMonitor display.");
        Console.WriteLine("place is one-shot. watch is opt-in and restores the WoW window on selected-display loss or Ctrl+C.");
        Console.WriteLine("No service, startup task, telemetry, network connection or external IPC protocol is used.");
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
        var singleUltrawide = HasSingleUltrawideFlag(args);
        var processName = ValueAfter(args, "--process") ?? "auto";
        var pidArgument = ValueAfter(args, "--pid");
        int? selectedPid = null;
        if (args.Any(arg => arg.Equals("--pid", StringComparison.OrdinalIgnoreCase)))
        {
            if (!int.TryParse(pidArgument, out var parsedPid) || parsedPid <= 0)
                return Fail("--pid must be a positive integer process ID.");
            selectedPid = parsedPid;
        }
        var addonDirArg = ValueAfter(args, "--addon-dir");
        if (args.Any(arg => arg.Equals("--addon-dir", StringComparison.OrdinalIgnoreCase)) && addonDirArg is null)
            return Fail("Missing value after --addon-dir.");
        if (!IsSingleUltrawideHandoffConfigured(singleUltrawide, addonDirArg is not null))
            return Fail("--single-ultrawide requires --addon-dir so the explicit mode reaches the addon.");
        var addonDir = addonDirArg is null ? null : ValidateAddonDirectory(addonDirArg);
        var mainMonitorArgument = ValueAfter(args, "--mainmonitor");
        if (args.Any(arg => arg.Equals("--mainmonitor", StringComparison.OrdinalIgnoreCase)) && mainMonitorArgument is null)
            return Fail("Missing value after --mainmonitor.");
        var available = EnumerateMonitors();
        var requested = monitorArgument.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (requested.Length == 0 || requested.Distinct(StringComparer.OrdinalIgnoreCase).Count() != requested.Length) return Fail("Monitor selection is empty or contains duplicates.");
        var selected = requested.Select(name => available.FirstOrDefault(m => string.Equals(m.Device, name, StringComparison.OrdinalIgnoreCase))).ToArray();
        if (selected.Any(m => m is null)) return Fail("A selected display is no longer connected. Run `list` again.");
        var monitors = selected.Cast<MonitorRecord>().ToArray();
        if (!IsSupportedMonitorSelection(monitors.Length, singleUltrawide))
            return Fail(singleUltrawide
                ? "Select exactly one display with --single-ultrawide."
                : "Select exactly two displays for normal spanning.");
        var mainMonitor = mainMonitorArgument is null
            ? monitors.FirstOrDefault(m => m.Primary) ?? monitors[0]
            : monitors.FirstOrDefault(m => string.Equals(m.Device, mainMonitorArgument, StringComparison.OrdinalIgnoreCase));
        if (mainMonitor is null) return Fail("--mainmonitor must identify a display included in --monitors.");

        var window = FindGameWindow(processName, selectedPid);
        if (window == 0) return Fail($"No visible top-level window found for process `{processName}`.");
        if (File.Exists(StatePath)) return Fail($"Restore state already exists at {StatePath}. Run `restore` before placing again.");
        var originalPlacement = new WindowPlacement { Length = Marshal.SizeOf<WindowPlacement>() };
        if (!GetWindowPlacement(window, ref originalPlacement)) return Fail("Could not read the original WoW window placement.");
        if (!GetWindowRect(window, out var originalScreenRect)) return Fail("Could not read the original WoW window screen rectangle.");

        var left = monitors.Min(m => m.Left);
        var top = monitors.Min(m => m.Top);
        var right = monitors.Max(m => m.Right);
        var bottom = monitors.Max(m => m.Bottom);
        if (right <= left || bottom <= top) return Fail("Selected display bounds are invalid.");

        var processId = GetWindowThreadProcessId(window, out var pid);
        if (processId == 0 || pid == 0) return Fail("Could not resolve the selected window process.");
        var style = GetWindowLongPtr(window, GwlStyle).ToInt64();
        var exStyle = GetWindowLongPtr(window, GwlExStyle).ToInt64();
        var state = new WindowState((int)pid, window.ToInt64(), style, exStyle, originalPlacement,
            monitors.Select(m => m.Device).ToArray(), DateTimeOffset.UtcNow,
            monitors.Select(DisplayIdentity).ToArray(), addonDir, originalScreenRect);
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
        if (addonDir is not null)
        {
            try
            {
                WriteNativeGeometryHandoff(addonDir, monitors, mainMonitor, (int)pid, singleUltrawide);
            }
            catch
            {
                if (RestoreState(state)) File.Delete(StatePath);
                throw; // Never claim successful placement when the requested handoff failed.
            }
        }
        Console.WriteLine($"Placed WoW window across {string.Join(", ", state.Displays)} at ({left},{top}) size {right-left}x{bottom-top}.");
        Console.WriteLine("The addon now sees the combined logical UIParent canvas. Run /forevermultimonitor config and apply its MainMonitor split.");
        Console.WriteLine("Run `restore` to restore the original window bounds and styles.");
        return 0;
    }

    private static int Restore()
    {
        if (!File.Exists(StatePath)) return Fail("No saved window state exists; nothing to restore.");
        var state = JsonSerializer.Deserialize<WindowState>(File.ReadAllText(StatePath)) ?? throw new InvalidDataException("Saved window state is invalid.");
        var connected = EnumerateMonitors();
        if (!RestoreStateSafely(state, connected, out var usedFallback)) return Fail("Restore failed; state file was retained for retry.");
        if (state.AddonDirectory is not null) ClearNativeGeometryHandoff(state.AddonDirectory);
        File.Delete(StatePath);
        Console.WriteLine(usedFallback
            ? "Original styles restored; original position was off-screen, so WoW was moved onto the primary connected display."
            : "Original WoW window bounds and styles restored.");
        return 0;
    }

    private static int Watch(string[] args)
    {
        var interval = 1000;
        var singleUltrawide = HasSingleUltrawideFlag(args);
        var intervalValue = ValueAfter(args, "--interval-ms");
        if (intervalValue is not null && (!int.TryParse(intervalValue, out interval) || interval < 250 || interval > 10000))
            return Fail("--interval-ms must be an integer between 250 and 10000.");

        var placeResult = Place(args);
        if (placeResult != 0) return placeResult;
        var state = JsonSerializer.Deserialize<WindowState>(File.ReadAllText(StatePath)) ?? throw new InvalidDataException("Saved watch state is invalid.");
        var stopRequested = false;
        ConsoleCancelEventHandler cancelHandler = (_, eventArgs) =>
        {
            eventArgs.Cancel = true;
            stopRequested = true;
        };
        Console.CancelKeyPress += cancelHandler;
        var mode = singleUltrawide ? "single-ultrawide" : "dual-display";
        Console.WriteLine($"Hotplug watch active for {string.Join(", ", state.Displays)} in {mode} mode; poll interval {interval} ms. Press Ctrl+C to restore and exit.");
        try
        {
            while (!stopRequested)
            {
                Thread.Sleep(interval);
                if (!File.Exists(StatePath))
                {
                    Console.WriteLine("Restore state was removed by another helper process; watch is stopping.");
                    return 0;
                }
                var connected = EnumerateMonitors();
                var missing = MissingDisplayIdentities(state, connected);
                if (missing.Length > 0)
                {
                    return RestoreAfterTopologyLoss(state, connected,
                        "Selected display disconnected: " + string.Join(", ", missing));
                }
                var hwnd = new nint(state.Handle);
                if (!IsWindow(hwnd)) return Fail("WoW window no longer exists; restore state was retained for diagnosis.");
                GetWindowThreadProcessId(hwnd, out var processId);
                if (processId != (uint)state.ProcessId) return Fail("WoW window handle now belongs to another process; restore state was retained.");
            }
            return RestoreAfterTopologyLoss(state, EnumerateMonitors(), "Watch stopped by user.");
        }
        finally
        {
            Console.CancelKeyPress -= cancelHandler;
        }
    }

    private static int RestoreAfterTopologyLoss(WindowState state, List<MonitorRecord> connected, string reason)
    {
        if (!RestoreStateSafely(state, connected, out var usedFallback))
            return Fail(reason + " Restore failed; state file was retained for retry.");
        if (state.AddonDirectory is not null) ClearNativeGeometryHandoff(state.AddonDirectory);
        if (File.Exists(StatePath)) File.Delete(StatePath);
        Console.WriteLine(reason);
        Console.WriteLine(usedFallback
            ? "Original styles restored; WoW was placed on the primary connected display because its original position is no longer visible."
            : "Original window position and styles restored.");
        return 0;
    }


    private static string ValidateAddonDirectory(string raw)
    {
        if (!Path.IsPathFullyQualified(raw)) throw new ArgumentException("--addon-dir must be an absolute path.");
        var full = Path.GetFullPath(raw);
        var manifest = Path.Combine(full, "ForeverMultiMonitor.toc");
        var runtime = Path.Combine(full, "Core", "RuntimeGeometry.lua");
        if (!IsAddonDirectoryContractSatisfied(raw, File.Exists(manifest), File.Exists(runtime)))
            throw new DirectoryNotFoundException("--addon-dir must point to an installed ForeverMultiMonitor addon containing the TOC and Core/RuntimeGeometry.lua.");
        return full;
    }

    private static bool HasSingleUltrawideFlag(string[] args) =>
        args.Any(arg => arg.Equals("--single-ultrawide", StringComparison.OrdinalIgnoreCase));

    private static bool IsSupportedMonitorSelection(int count, bool singleUltrawide) =>
        singleUltrawide ? count == 1 : count == 2;

    private static bool IsSingleUltrawideHandoffConfigured(bool singleUltrawide, bool addonDirectoryProvided) =>
        !singleUltrawide || addonDirectoryProvided;

    private static bool IsAddonDirectoryContractSatisfied(string raw, bool hasManifest, bool hasRuntime) =>
        Path.IsPathFullyQualified(raw) &&
        hasManifest && hasRuntime;

    private static string LuaString(string value)
    {
        var result = new StringBuilder("\"");
        foreach (var c in value)
        {
            if (c == '\\') result.Append(@"\\");
            else if (c == '"') result.Append("\\\"");
            else if (char.IsControl(c)) result.Append('\\').Append(((int)c).ToString("D3", System.Globalization.CultureInfo.InvariantCulture));
            else result.Append(c);
        }
        return result.Append('"').ToString();
    }

    private static string BuildNativeGeometryLua(IReadOnlyList<MonitorRecord> monitors, MonitorRecord mainMonitor, int processId, bool singleUltrawide = false)
    {
        if (!IsSupportedMonitorSelection(monitors.Count, singleUltrawide) || !monitors.Contains(mainMonitor))
            throw new ArgumentException("Invalid selected displays for handoff.");
        var left = monitors.Min(m => m.Left);
        var top = monitors.Min(m => m.Top);
        var right = monitors.Max(m => m.Right);
        var bottom = monitors.Max(m => m.Bottom);
        var result = new StringBuilder("-- Data-only native monitor handoff; generated by ForeverMultiMonitor.WindowsHelper.\n");
        result.AppendLine("ForeverMultiMonitorNativeGeometry = {");
        result.AppendLine("  schemaVersion = 1,");
        result.AppendLine("  source = \"ForeverMultiMonitor.WindowsHelper\",");
        if (singleUltrawide) result.AppendLine("  mode = \"single-ultrawide\",");
        result.AppendLine($"  processId = {processId},");
        result.AppendLine($"  generatedAtUtc = {LuaString(DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ", System.Globalization.CultureInfo.InvariantCulture))},");
        result.AppendLine($"  mainMonitorDeviceId = {LuaString(DisplayIdentity(mainMonitor))},");
        result.AppendLine($"  bounds = {{ left = {left}, top = {top}, right = {right}, bottom = {bottom} }},");
        result.AppendLine("  displays = {");
        foreach (var monitor in monitors)
        {
            result.AppendLine("    {");
            result.AppendLine($"      device = {LuaString(monitor.Device)}, deviceId = {LuaString(DisplayIdentity(monitor))},");
            result.AppendLine($"      name = {LuaString(monitor.Name)}, primary = {(monitor.Primary ? "true" : "false")},");
            result.AppendLine($"      left = {monitor.Left}, top = {monitor.Top}, right = {monitor.Right}, bottom = {monitor.Bottom},");
            result.AppendLine($"      dpiX = {monitor.DpiX}, dpiY = {monitor.DpiY},");
            result.AppendLine("    },");
        }
        result.AppendLine("  },");
        return result.AppendLine("}").ToString();
    }

    private static void WriteNativeGeometryHandoff(string addonDir, IReadOnlyList<MonitorRecord> monitors, MonitorRecord mainMonitor, int processId, bool singleUltrawide)
    {
        WriteHandoffAtomically(addonDir, BuildNativeGeometryLua(monitors, mainMonitor, processId, singleUltrawide));
        Console.WriteLine("Native monitor handoff written. Use /reload in WoW, then /forevermultimonitor native apply.");
    }

    private static void ClearNativeGeometryHandoff(string addonDir)
    {
        WriteHandoffAtomically(addonDir, "-- Native monitor span inactive. Use manual geometry.\nForeverMultiMonitorNativeGeometry = nil\n");
    }

    private static void WriteHandoffAtomically(string addonDir, string contents)
    {
        var validated = ValidateAddonDirectory(addonDir);
        var target = Path.Combine(validated, "Core", "RuntimeGeometry.lua");
        var temporary = target + ".new";
        try
        {
            File.WriteAllText(temporary, contents, new UTF8Encoding(false));
            File.Move(temporary, target, true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    private static string DisplayIdentity(MonitorRecord monitor) =>
        string.IsNullOrWhiteSpace(monitor.DeviceId) ? monitor.Device : monitor.DeviceId;

    private static string[] MissingDisplayIdentities(WindowState state, IReadOnlyCollection<MonitorRecord> connected)
    {
        var selected = state.DisplayIds is { Length: > 0 } ? state.DisplayIds : state.Displays;
        var available = connected.Select(DisplayIdentity).ToHashSet(StringComparer.OrdinalIgnoreCase);
        return selected.Where(identity => !available.Contains(identity))
            .Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
    }

    private static Rect? BuildSafeRestoreBounds(Rect originalScreen, IReadOnlyList<MonitorRecord> connected, out bool usedFallback)
    {
        usedFallback = false;
        if (connected.Count == 0) return null;
        var bounds = originalScreen;
        var originalWidth = Math.Max(1, bounds.Right - bounds.Left);
        var originalHeight = Math.Max(1, bounds.Bottom - bounds.Top);
        var minimumVisibleWidth = Math.Min(320, originalWidth);
        var minimumVisibleHeight = Math.Min(180, originalHeight);
        var hasUsableIntersection = connected.Any(monitor =>
        {
            var overlapWidth = Math.Min(bounds.Right, monitor.Right) - Math.Max(bounds.Left, monitor.Left);
            var overlapHeight = Math.Min(bounds.Bottom, monitor.Bottom) - Math.Max(bounds.Top, monitor.Top);
            return overlapWidth >= minimumVisibleWidth && overlapHeight >= minimumVisibleHeight;
        });
        if (hasUsableIntersection) return null;

        var target = connected.FirstOrDefault(monitor => monitor.Primary) ?? connected.FirstOrDefault();
        if (target is null || target.Width <= 0 || target.Height <= 0)
            throw new InvalidOperationException("No connected display is available for safe window recovery.");

        var width = Math.Min(Math.Max(1, bounds.Right - bounds.Left), target.Width);
        var height = Math.Min(Math.Max(1, bounds.Bottom - bounds.Top), target.Height);
        var left = target.Left + (target.Width - width) / 2;
        var top = target.Top + (target.Height - height) / 2;
        usedFallback = true;
        return new Rect { Left = left, Top = top, Right = left + width, Bottom = top + height };
    }

    private static bool RestoreStateSafely(WindowState state, IReadOnlyList<MonitorRecord> connected, out bool usedFallback)
    {
        usedFallback = false;
        var hwnd = new nint(state.Handle);
        if (!IsWindow(hwnd)) return false;
        GetWindowThreadProcessId(hwnd, out var pid);
        if (pid != (uint)state.ProcessId) return false;

        Rect? fallback = null;
        if (state.OriginalScreenRect is Rect originalScreen)
            fallback = BuildSafeRestoreBounds(originalScreen, connected, out usedFallback);
        if (!TrySetWindowLong(hwnd, GwlStyle, new nint(state.OriginalStyle))) return false;
        if (!TrySetWindowLong(hwnd, GwlExStyle, new nint(state.OriginalExtendedStyle))) return false;
        // WINDOWPLACEMENT uses workspace coordinates; SetWindowPos expects screen coordinates.
        // Only SetWindowPlacement may consume NormalPosition to avoid taskbar-offset drift.
        var placement = state.OriginalPlacement;
        placement.Length = Marshal.SizeOf<WindowPlacement>();
        if (fallback.HasValue) placement.ShowCommand = SwRestore;
        if (!SetWindowPlacement(hwnd, ref placement)) return false;
        if (fallback is Rect safe)
            return SetWindowPos(hwnd, 0, safe.Left, safe.Top, safe.Right - safe.Left, safe.Bottom - safe.Top,
                SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
        return SetWindowPos(hwnd, 0, 0, 0, 0, 0,
            SwpNoMove | SwpNoSize | SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
    }

    private static int SelfTest()
    {
        var contractFailures = new List<string>();
        var selectionCases = new (int Count, bool SingleUltrawide, bool Expected)[]
        {
            (0, false, false), (1, false, false), (2, false, true), (3, false, false), (8, false, false),
            (0, true, false), (1, true, true), (2, true, false), (3, true, false), (8, true, false)
        };
        if (selectionCases.Any(test => IsSupportedMonitorSelection(test.Count, test.SingleUltrawide) != test.Expected))
            contractFailures.Add("normal mode must accept exactly two displays and explicit single-ultrawide mode exactly one");
        if (HasSingleUltrawideFlag(new[] { "place", "--single-ultrawide" }) == false ||
            HasSingleUltrawideFlag(new[] { "watch", "--SINGLE-ULTRAWIDE" }) == false ||
            HasSingleUltrawideFlag(new[] { "place" }) ||
            IsSingleUltrawideHandoffConfigured(true, false) ||
            !IsSingleUltrawideHandoffConfigured(true, true) ||
            !IsSingleUltrawideHandoffConfigured(false, false))
            contractFailures.Add("single-ultrawide must be explicit, case-insensitive, and require an addon handoff path");
        if (!IsAddonDirectoryContractSatisfied(@"C:\Games\Forever\Interface\AddOns\ForeverMultiMonitor", true, true) ||
            IsAddonDirectoryContractSatisfied("relative\\ForeverMultiMonitor", true, true) ||
            IsAddonDirectoryContractSatisfied(@"D:\Games\Forever\Interface\AddOns\ForeverMultiMonitor", false, true) ||
            IsAddonDirectoryContractSatisfied(@"D:\Games\Forever\Interface\AddOns\ForeverMultiMonitor", true, false))
            contractFailures.Add("addon handoff must accept a valid absolute C: path and require both addon files");
        if (contractFailures.Count > 0)
            return Fail("Reference-contract self-test failed: " + string.Join("; ", contractFailures) + ".");
        Console.WriteLine("PASS reference-contract self-test: explicit two-display and single-ultrawide counts, addon handoff requirement, and absolute addon path.");

        var primary = new MonitorRecord(@"\\.\DISPLAY1", "monitor-primary", "Primary", true, 0, 0, 1920, 1080, 96, 96);
        var secondary = new MonitorRecord(@"\\.\DISPLAY2", "monitor-secondary", "Secondary", false, 1920, 0, 3840, 1080, 96, 96);
        var third = new MonitorRecord(@"\\.\DISPLAY3", "monitor-third", "Third", false, 0, 0, 960, 1080, 96, 96);
        var ultrawide = new MonitorRecord(@"\\.\DISPLAY4", "monitor-ultrawide", "Ultrawide", true, 0, 0, 5120, 1440, 96, 96);
        try
        {
            _ = BuildNativeGeometryLua(new[] { primary, secondary, third }, secondary, 4242);
            return Fail("Native geometry self-test failed: handoff accepted a third display.");
        }
        catch (ArgumentException)
        {
            // Beta 17's normal span is exactly two selected displays.
        }
        try
        {
            var singleHandoff = BuildNativeGeometryLua(new[] { ultrawide }, ultrawide, 4242, true);
            if (!singleHandoff.Contains("mode = \"single-ultrawide\""))
                return Fail("Native geometry self-test failed: single-ultrawide handoff omitted its explicit mode marker.");
        }
        catch (ArgumentException)
        {
            return Fail("Native geometry self-test failed: explicit one-display handoff was rejected.");
        }

        var state = new WindowState(1, 1, 0, 0, new WindowPlacement(),
            new[] { primary.Device, secondary.Device }, DateTimeOffset.UtcNow,
            new[] { DisplayIdentity(primary), DisplayIdentity(secondary) }, null,
            new Rect { Left = 100, Top = 100, Right = 1300, Bottom = 900 });
        var missing = MissingDisplayIdentities(state, new[] { primary });
        if (missing.Length != 1 || missing[0] != "monitor-secondary") return Fail("Hotplug self-test failed: missing display identity was not detected.");

        Rect? zeroMonitorBounds;
        bool zeroMonitorFallback;
        try
        {
            zeroMonitorBounds = BuildSafeRestoreBounds(
                new Rect { Left = 100, Top = 100, Right = 1300, Bottom = 900 },
                Array.Empty<MonitorRecord>(), out zeroMonitorFallback);
        }
        catch (InvalidOperationException)
        {
            return Fail("Hotplug self-test failed: zero enumerated displays abort safe rollback before saved styles and placement can be restored.");
        }
        if (zeroMonitorFallback || zeroMonitorBounds.HasValue)
            return Fail("Hotplug self-test failed: zero enumerated displays must preserve saved placement without attempting an impossible fallback.");

        var offscreen = new WindowPlacement { NormalPosition = new Rect { Left = 2200, Top = 100, Right = 3400, Bottom = 900 } };
        var recovered = BuildSafeRestoreBounds(offscreen.NormalPosition, new[] { primary }, out var usedFallback);
        if (!usedFallback || recovered is not Rect recoveredBounds || recoveredBounds.Left < primary.Left || recoveredBounds.Top < primary.Top ||
            recoveredBounds.Right > primary.Right || recoveredBounds.Bottom > primary.Bottom)
            return Fail("Hotplug self-test failed: off-screen original position was not clamped to the primary display.");

        var partial = new WindowPlacement { NormalPosition = new Rect { Left = 1910, Top = 100, Right = 3110, Bottom = 900 } };
        var partialRecovered = BuildSafeRestoreBounds(partial.NormalPosition, new[] { primary }, out var partialFallback);
        if (!partialFallback) return Fail("Hotplug self-test failed: a barely visible original window was not moved to safety.");

        var visible = new WindowPlacement { NormalPosition = new Rect { Left = 100, Top = 100, Right = 1300, Bottom = 900 } };
        var exact = BuildSafeRestoreBounds(visible.NormalPosition, new[] { primary }, out var exactFallback);
        if (exactFallback || exact.HasValue)
            return Fail("Hotplug self-test failed: visible original position was not preserved.");

        // A top/left taskbar shifts WINDOWPLACEMENT workspace coordinates. Visibility
        // must be decided from the original screen rectangle, not NormalPosition.
        var taskbarShifted = new WindowPlacement { NormalPosition = new Rect { Left = -300, Top = 100, Right = 20, Bottom = 900 } };
        var screenRect = new Rect { Left = 100, Top = 100, Right = 420, Bottom = 900 };
        _ = BuildSafeRestoreBounds(taskbarShifted.NormalPosition, new[] { primary }, out var incorrectFallback);
        var checkedBounds = BuildSafeRestoreBounds(screenRect, new[] { primary }, out var taskbarFallback);
        if (!incorrectFallback || taskbarFallback || checkedBounds.HasValue)
            return Fail("Hotplug self-test failed: screen-visible original window was needlessly relocated.");

        var roundTrip = JsonSerializer.Deserialize<WindowState>(JsonSerializer.Serialize(state, JsonOptions), JsonOptions);
        if (roundTrip is null || roundTrip.ProcessId != state.ProcessId ||
            roundTrip.DisplayIds is not { Length: 2 } || roundTrip.DisplayIds[1] != "monitor-secondary" ||
            roundTrip.OriginalScreenRect is not Rect { Left: 100, Right: 1300 })
            return Fail("Restore-state JSON round-trip failed; safe rollback cannot be guaranteed.");

        var handoff = BuildNativeGeometryLua(new[] { primary, secondary }, secondary, 4242);
        if (!handoff.Contains("schemaVersion = 1") || !handoff.Contains("processId = 4242") ||
            handoff.Contains("mode = \"single-ultrawide\"") ||
            !handoff.Contains("mainMonitorDeviceId = \"monitor-secondary\"") ||
            !handoff.Contains("bounds = { left = 0, top = 0, right = 3840, bottom = 1080 }") ||
            !handoff.Contains("dpiX = 96, dpiY = 96"))
            return Fail("Native geometry handoff self-test failed: invalid output schema or bounds.");
        var escaped = LuaString("monitor\\device\"quote\"\n");
        if (!escaped.Contains("\\\\") || !escaped.Contains("\\\"") || !escaped.Contains("\\010"))
            return Fail("Native geometry handoff self-test failed: Lua string escaping is unsafe.");

        Console.WriteLine("PASS hotplug self-test: stable identity, disconnect detection, zero-display restore path, off-screen fallback and exact visible restore.");
        Console.WriteLine("PASS native handoff self-test: dual-display geometry, single-ultrawide mode marker, schema and escaped strings.");
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
        // Do not pass WINDOWPLACEMENT workspace coordinates to SetWindowPos.
        var placement = state.OriginalPlacement;
        placement.Length = Marshal.SizeOf<WindowPlacement>();
        if (!SetWindowPlacement(hwnd, ref placement)) return false;
        return SetWindowPos(hwnd, 0, 0, 0, 0, 0,
            SwpNoMove | SwpNoSize | SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
    }

    private static bool TrySetWindowLong(nint hwnd, int index, nint value)
    {
        Marshal.SetLastPInvokeError(0);
        var previous = SetWindowLongPtr(hwnd, index, value);
        return previous != 0 || Marshal.GetLastPInvokeError() == 0;
    }

    private static void WriteStateAtomically(WindowState state)
    {
        // CreateNew semantics on the final move prevent concurrent place commands
        // from replacing an earlier session's only recoverable original state.
        var temporary = StatePath + "." + Guid.NewGuid().ToString("N") + ".new";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(state, JsonOptions));
            File.Move(temporary, StatePath); // no overwrite: fails if another place won
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    private static nint FindGameWindow(string processName, int? selectedPid)
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
        var candidates = new List<(nint Handle, uint ProcessId)>();
        EnumWindows((hwnd, _) =>
        {
            if (!IsWindowVisible(hwnd)) return true;
            GetWindowThreadProcessId(hwnd, out var pid);
            if (!ids.Contains(pid)) return true;
            if (selectedPid.HasValue && pid != (uint)selectedPid.Value) return true;
            var title = new System.Text.StringBuilder(256);
            _ = GetWindowText(hwnd, title, title.Capacity);
            if (title.Length == 0) return true;
            candidates.Add((hwnd, pid));
            return true;
        }, 0);
        if (candidates.Count > 1)
            throw new InvalidOperationException("Multiple WoW windows found; specify --pid.");
        return candidates.Count == 1 ? candidates[0].Handle : 0;
    }

    private static string? ValueAfter(string[] args, string key)
    {
        for (var index = 1; index < args.Length - 1; index++) if (args[index].Equals(key, StringComparison.OrdinalIgnoreCase)) return args[index + 1];
        return null;
    }

    private static int Fail(string message) { Console.Error.WriteLine("ERROR: " + message); return 2; }
}
