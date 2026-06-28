using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Controls.Documents;
using Avalonia.Threading;
using System.Collections.Generic;
using System.Linq;
using System.ComponentModel;
using System.Net.Http;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace TermindWindows;

/// 一条 SSH 连接（占位；后续接真实连接数据 + ssh）
/// Bar=分组色条，Dot=在线状态点(可达探测后更新)，GroupName/ShowHeader=分组标题，
/// Reach/ReachColor=可达指示(TCP 探测后更新)，Note/HasNote=备注，LastUsed/HasLastUsed=最近使用
public class ConnItem : INotifyPropertyChanged
{
    public string Name { get; }
    public string Addr { get; }
    public IBrush Bar { get; }
    public string GroupName { get; }
    public bool ShowHeader { get; }
    public string Note { get; }
    public bool HasNote { get; }
    public string LastUsed { get; }
    public bool HasLastUsed { get; }

    private IBrush _dot; public IBrush Dot { get => _dot; set { _dot = value; Notify(nameof(Dot)); } }
    private string _reach; public string Reach { get => _reach; set { _reach = value; Notify(nameof(Reach)); } }
    private IBrush _reachColor; public IBrush ReachColor { get => _reachColor; set { _reachColor = value; Notify(nameof(ReachColor)); } }

    public ConnItem(string name, string addr, IBrush bar, IBrush dot, string groupName, bool showHeader,
        string reach, IBrush reachColor, string note, bool hasNote, string lastUsed, bool hasLastUsed)
    {
        Name = name; Addr = addr; Bar = bar; _dot = dot; GroupName = groupName; ShowHeader = showHeader;
        _reach = reach; _reachColor = reachColor; Note = note; HasNote = hasNote; LastUsed = lastUsed; HasLastUsed = hasLastUsed;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void Notify(string n) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
}

public partial class MainWindow : Window
{
    private readonly List<string> _cmdHistory = new();   // 命令历史（最近优先），供上下键回溯
    private int _histIdx = -1;                            // 当前回溯位置（-1=未回溯）
    private System.Collections.ObjectModel.ObservableCollection<ConnItem> _conns = new();   // 连接列表（可增删自动刷新）

    public MainWindow()
    {
        InitializeComponent();
        var green = Brush.Parse("#3FB950");
        var gray = Brush.Parse("#6B7280");
        // 连接列表（ObservableCollection：新建连接后自动刷新 UI）
        _conns = new System.Collections.ObjectModel.ObservableCollection<ConnItem>
        {
            new("测试服务器", "root@47.85.19.31:22", Brush.Parse("#3B82F6"), gray, "生产环境", true, "⏳", gray, "📝 Ubuntu 测试机", true, "上次使用 · 5 分钟前", true),
            new("生产服务器", "root@192.168.1.10:22", Brush.Parse("#EF4444"), gray, "生产环境", false, "⏳", gray, "📝 官网 + API", true, "上次使用 · 1 小时前", true),
            new("开发机", "deploy@dev.example.com:2222", gray, gray, "开发环境", true, "⏳", gray, "", false, "", false),
        };
        ConnList.ItemsSource = _conns;
        ConnList.SelectedIndex = 0;
        // 真实 TCP 可达性探测（对照 linux probe_tcp）：异步探测每个连接，结果回 UI 线程更新
        foreach (var item in _conns)
            _ = ProbeReachabilityAsync(item);
        // 加载持久化配置（API Key/地址）→ 填回设置框；失焦自动保存
        LoadConfig();
        ApiKeyBox.LostFocus += (_, _) => SaveConfig();
        BaseUrlBox.LostFocus += (_, _) => SaveConfig();
        // 状态条指标定时自动刷新（每 30s SSH 重取，实时反映远程服务器，对照 apple 周期巡检）
        var timer = new Avalonia.Threading.DispatcherTimer { Interval = System.TimeSpan.FromSeconds(30) };
        timer.Tick += (_, _) => { if (_activeHost != null) _ = RefreshMetricsAsync(); };
        timer.Start();
        _ = RefreshMetricsAsync();   // 启动先取一次（SelectedIndex=0 已选中测试机）
        RenderQuickCmds();           // 渲染快捷命令栏（默认 + 自定义，覆盖 axaml 默认）
        RenderQuickAsks();           // 渲染快捷追问栏（默认 + 自定义）
        LoadSessions();              // 恢复持久化的 AI 多会话
        RenderSession();
    }

    /// 配置文件路径（用户 AppData，跨重启持久化）
    private static string ConfigPath =>
        System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.ApplicationData), "Termind", "config.json");

    /// AI 多会话持久化文件（独立于 config，避免膨胀；对照 apple ai-persist）
    private static string SessionsPath =>
        System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.ApplicationData), "Termind", "sessions.json");

    /// 保存 AI 多会话到磁盘（会话切换/新建/删除 + 每轮对话后调用）
    private void SaveSessions()
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(SessionsPath); if (dir != null) System.IO.Directory.CreateDirectory(dir);
            var data = _sessions.Select(s => s.Select(m => new { role = m.role, content = m.content }).ToArray()).ToArray();
            System.IO.File.WriteAllText(SessionsPath, JsonSerializer.Serialize(data));
        }
        catch { /* 持久化失败不影响使用 */ }
    }

    /// 启动恢复 AI 多会话（空则保留默认单会话）
    private void LoadSessions()
    {
        try
        {
            if (!System.IO.File.Exists(SessionsPath)) return;
            using var doc = JsonDocument.Parse(System.IO.File.ReadAllText(SessionsPath));
            var loaded = new List<List<(string, string)>>();
            foreach (var sess in doc.RootElement.EnumerateArray())
            {
                var msgs = new List<(string, string)>();
                foreach (var m in sess.EnumerateArray())
                    msgs.Add((m.GetProperty("role").GetString() ?? "", m.GetProperty("content").GetString() ?? ""));
                loaded.Add(msgs);
            }
            if (loaded.Count > 0) { _sessions.Clear(); _sessions.AddRange(loaded); _curSession = 0; }
        }
        catch { /* 损坏则用默认 */ }
    }

    /// 加载持久化配置（API Key/地址）填回设置框
    private void LoadConfig()
    {
        try
        {
            if (!System.IO.File.Exists(ConfigPath)) return;
            using var doc = JsonDocument.Parse(System.IO.File.ReadAllText(ConfigPath));
            var root = doc.RootElement;
            if (root.TryGetProperty("apiKey", out var k)) ApiKeyBox.Text = k.GetString() ?? "";
            if (root.TryGetProperty("baseUrl", out var u)) BaseUrlBox.Text = u.GetString() ?? "";
            if (root.TryGetProperty("fontSize", out var fs) && fs.TryGetDouble(out var fsv)) _termFontSize = System.Math.Clamp(fsv, 9, 22);
            if (root.TryGetProperty("aiFontSize", out var afs) && afs.TryGetDouble(out var afsv)) _aiFontSize = System.Math.Clamp(afsv, 10, 22);
            if (root.TryGetProperty("themeIdx", out var ti) && ti.TryGetInt32(out var tiv)) ApplyTheme(tiv);
            if (root.TryGetProperty("customCmds", out var cc) && cc.ValueKind == JsonValueKind.Array) { _customCmds.Clear(); foreach (var x in cc.EnumerateArray()) { var s = x.GetString(); if (!string.IsNullOrEmpty(s)) _customCmds.Add(s); } }
            if (root.TryGetProperty("customAsks", out var ca) && ca.ValueKind == JsonValueKind.Array) { _customAsks.Clear(); foreach (var x in ca.EnumerateArray()) { var s = x.GetString(); if (!string.IsNullOrEmpty(s)) _customAsks.Add(s); } }
            // 恢复命令历史（上下键回溯，重启可用）
            if (root.TryGetProperty("cmdHistory", out var ch) && ch.ValueKind == JsonValueKind.Array)
                foreach (var c in ch.EnumerateArray())
                { var s = c.GetString(); if (!string.IsNullOrEmpty(s)) _cmdHistory.Add(s); }
            // 恢复用户新建的连接
            if (root.TryGetProperty("conns", out var conns) && conns.ValueKind == JsonValueKind.Array)
            {
                var gray = Brush.Parse("#6B7280");
                bool first = true;
                foreach (var c in conns.EnumerateArray())
                {
                    var name = c.TryGetProperty("name", out var n) ? n.GetString() : null;
                    var addr = c.TryGetProperty("addr", out var a) ? a.GetString() : null;
                    if (string.IsNullOrEmpty(name) || string.IsNullOrEmpty(addr)) continue;
                    var note = c.TryGetProperty("note", out var nt) ? (nt.GetString() ?? "") : "";
                    var item = new ConnItem(name, addr, Brush.Parse("#3FB950"), gray, "我的连接", first, "⏳", gray, note, note.Length > 0, "", false);
                    _conns.Add(item);
                    _ = ProbeReachabilityAsync(item);
                    first = false;
                }
            }
        }
        catch { /* 配置损坏忽略，用默认 */ }
    }

    /// 保存配置（API Key/地址 + 用户新建的连接）到配置文件
    private void SaveConfig()
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(ConfigPath)!;
            System.IO.Directory.CreateDirectory(dir);
            // 只持久化用户新建的连接（"我的连接" 组），默认演示连接不存
            var userConns = _conns.Where(c => c.GroupName == "我的连接")
                .Select(c => new { name = c.Name, addr = c.Addr, note = c.Note }).ToArray();
            var json = JsonSerializer.Serialize(new { apiKey = ApiKeyBox.Text ?? "", baseUrl = BaseUrlBox.Text ?? "", conns = userConns, cmdHistory = _cmdHistory.Take(30).ToArray(), fontSize = _termFontSize, aiFontSize = _aiFontSize, themeIdx = _themeIdx, customCmds = _customCmds.ToArray(), customAsks = _customAsks.ToArray() });
            System.IO.File.WriteAllText(ConfigPath, json);
        }
        catch { /* 写失败忽略，不影响运行 */ }
    }

    /// 真实 TCP 可达性探测（对照 linux）：ConnectAsync + 2s 超时，结果更新连接状态点/可达指示
    /// 整体 try/catch 包裹：fire-and-forget 异步任何未预期异常都不得使进程 abort（修 dotnet run 崩溃隐患）
    private static async Task ProbeReachabilityAsync(ConnItem c)
    {
        try
        {
            // 解析 user@host:port
            var s = c.Addr;
            var at = s.IndexOf('@'); if (at >= 0) s = s[(at + 1)..];
            var host = s; var port = 22;
            var colon = s.IndexOf(':');
            if (colon >= 0) { host = s[..colon]; int.TryParse(s[(colon + 1)..], out port); }
            bool ok = await TcpReachableAsync(host, port);
            var green = Brush.Parse("#3FB950");
            var gray = Brush.Parse("#6B7280");
            Dispatcher.UIThread.Post(() =>
            {
                c.Reach = ok ? "✓" : "✕";
                c.ReachColor = ok ? green : gray;
                c.Dot = ok ? green : gray;
            });
        }
        catch { /* 探测失败静默：保持探测中状态，绝不让后台任务异常崩溃进程 */ }
    }

    private static async Task<bool> TcpReachableAsync(string host, int port)
    {
        try
        {
            using var client = new TcpClient();
            var connect = client.ConnectAsync(host, port);
            var done = await Task.WhenAny(connect, Task.Delay(2000));
            return done == connect && !connect.IsFaulted && client.Connected;
        }
        catch { return false; }
    }

    private string? _activeHost;   // 当前选中连接的 host（驱动 SSH 执行；null=用 env/默认）
    private string? _activeUser;

    // 快捷命令：默认运维命令 + 用户自定义（持久化），可增删
    private static readonly string[] DefaultQuickCmds = { "ls -la", "df -h", "free -h", "ps aux --sort=-%cpu | head", "ss -tlnp", "uptime", "top", "journalctl -xe -n 50", "systemctl status nginx" };
    private readonly List<string> _customCmds = new();
    // 快捷追问：默认 + 用户自定义（持久化），可增删
    private static readonly string[] DefaultQuickAsks = { "如何排查？", "给我具体命令", "有什么风险？" };
    private readonly List<string> _customAsks = new();

    /// 渲染快捷追问栏（默认 + 自定义 chip + 末尾「+」添加按钮）；自定义可右键删除
    private void RenderQuickAsks()
    {
        QuickAsks.Children.Clear();
        foreach (var ask in DefaultQuickAsks) QuickAsks.Children.Add(MakeAskChip(ask, "#3B82F6", false));
        foreach (var ask in _customAsks) QuickAsks.Children.Add(MakeAskChip(ask, "#3FB950", true));
        var add = new Button { Background = Brush.Parse("#22FFFFFF"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(14), Padding = new Thickness(11, 5), Content = "+", Foreground = Brush.Parse("#8B92A8"), FontSize = 12 };
        var box = new TextBox { Width = 220, PlaceholderText = "自定义追问…", FontSize = 12 };
        var ok = new Button { Content = "添加", Background = Brush.Parse("#3FB950"), Foreground = Brush.Parse("#FFFFFF"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(6), Padding = new Thickness(10, 6), Margin = new Thickness(0, 6, 0, 0), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Center };
        ok.Click += (_, _) => { var a = box.Text?.Trim(); if (!string.IsNullOrEmpty(a) && !_customAsks.Contains(a) && !DefaultQuickAsks.Contains(a)) { _customAsks.Add(a); SaveConfig(); RenderQuickAsks(); } add.Flyout?.Hide(); };
        add.Flyout = new Flyout { Content = new StackPanel { Children = { new TextBlock { Text = "添加快捷追问", Foreground = Brush.Parse("#FFFFFF"), FontSize = 13, FontWeight = Avalonia.Media.FontWeight.Bold, Margin = new Thickness(0, 0, 0, 6) }, box, ok } } };
        QuickAsks.Children.Add(add);
    }

    /// 生成单个快捷追问 chip（点击填入 AI 输入框；自定义可右键删除）
    private Button MakeAskChip(string ask, string color, bool custom)
    {
        var chip = new Button { Background = Brush.Parse(custom ? "#1A3FB950" : "#1A3B82F6"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(14), Padding = new Thickness(10, 5), Content = ask, Foreground = Brush.Parse(color), FontSize = 11 };
        chip.Click += (_, _) => { AiInput.Text = ask; AiInput.Focus(); };
        if (custom)
        {
            var del = new MenuItem { Header = $"删除「{ask}」", Foreground = Brush.Parse("#F85149") };
            del.Click += (_, _) => { _customAsks.Remove(ask); SaveConfig(); RenderQuickAsks(); };
            chip.ContextFlyout = new MenuFlyout { Items = { del } };
            ToolTip.SetTip(chip, "点击追问 · 右键删除");
        }
        return chip;
    }

    /// 渲染快捷命令栏（默认 + 自定义 chip + 末尾「+」添加按钮）；自定义可右键删除
    private void RenderQuickCmds()
    {
        QuickCmds.Children.Clear();
        foreach (var cmd in DefaultQuickCmds) QuickCmds.Children.Add(MakeChip(cmd, "#FF4B6E", false));
        foreach (var cmd in _customCmds) QuickCmds.Children.Add(MakeChip(cmd, "#3FB950", true));
        // 末尾「+」添加按钮（Flyout 输入自定义命令）
        var add = new Button { Background = Brush.Parse("#22FFFFFF"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(14), Padding = new Thickness(11, 5), Content = "+", Foreground = Brush.Parse("#8B92A8"), FontSize = 12 };
        var box = new TextBox { Width = 220, PlaceholderText = "自定义命令…", FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, FontSize = 12 };
        var ok = new Button { Content = "添加", Background = Brush.Parse("#3FB950"), Foreground = Brush.Parse("#FFFFFF"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(6), Padding = new Thickness(10, 6), Margin = new Thickness(0, 6, 0, 0), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Center };
        ok.Click += (_, _) => { var c = box.Text?.Trim(); if (!string.IsNullOrEmpty(c) && !_customCmds.Contains(c) && !DefaultQuickCmds.Contains(c)) { _customCmds.Add(c); SaveConfig(); RenderQuickCmds(); } add.Flyout?.Hide(); };
        add.Flyout = new Flyout { Content = new StackPanel { Children = { new TextBlock { Text = "添加快捷命令", Foreground = Brush.Parse("#FFFFFF"), FontSize = 13, FontWeight = Avalonia.Media.FontWeight.Bold, Margin = new Thickness(0, 0, 0, 6) }, box, ok } } };
        QuickCmds.Children.Add(add);
    }

    /// 生成单个快捷命令 chip（点击填入终端；自定义命令右键可删除）
    private Button MakeChip(string cmd, string color, bool custom)
    {
        var chip = new Button { Background = Brush.Parse(custom ? "#1A3FB950" : "#1AFF4B6E"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(14), Padding = new Thickness(10, 5), Content = cmd, Foreground = Brush.Parse(color), FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, FontSize = 11 };
        chip.Click += (_, _) => { CmdInput.Text = cmd; CmdInput.Focus(); };
        if (custom)
        {
            var del = new MenuItem { Header = $"删除「{cmd}」", Foreground = Brush.Parse("#F85149") };
            del.Click += (_, _) => { _customCmds.Remove(cmd); SaveConfig(); RenderQuickCmds(); };
            chip.ContextFlyout = new MenuFlyout { Items = { del } };
            ToolTip.SetTip(chip, "点击填入 · 右键删除");
        }
        return chip;
    }

    /// 命令历史面板打开：填充最近命令列表，点击重用填入输入框（对照 apple/linux history）
    private void OnHistoryOpen(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HistoryList.Children.Clear();
        if (_cmdHistory.Count == 0)
        {
            HistoryList.Children.Add(new TextBlock { Text = "（暂无历史命令）", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
            return;
        }
        foreach (var cmd in _cmdHistory.Take(20))
        {
            var btn = new Button { Background = Brush.Parse("#22FFFFFF"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(4), Padding = new Thickness(8, 5), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Left };
            btn.Content = new TextBlock { Text = cmd, Foreground = Brush.Parse("#C9D1D9"), FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, FontSize = 12, TextTrimming = TextTrimming.CharacterEllipsis };
            var c = cmd;
            btn.Click += (_, _) => { CmdInput.Text = c; CmdInput.Focus(); };
            HistoryList.Children.Add(btn);
        }
    }

    /// 服务管理（状态条服务点 menu）：SSH systemctl start/stop/restart → 终端显示结果 + 刷新状态
    private async void OnServiceAction(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (sender is not MenuItem mi || mi.Tag is not string tag) return;
        var parts = tag.Split(':'); if (parts.Length != 2) return;
        var (action, svc) = (parts[0], parts[1]);
        var danger = action is "stop" or "restart";
        AppendTerm($"# systemctl {action} {svc} …" + (danger ? "（影响线上服务，请确认）" : ""), danger ? "#F59E0B" : "#8B92A8");
        try
        {
            var r = await SshExecAsync($"systemctl {action} {svc} 2>&1 && echo TERMIND_SVC_OK");
            AppendTerm(r.Contains("TERMIND_SVC_OK") ? $"✓ {svc} 已{action}" : $"✕ {svc} {action} 失败：{r.Trim()}",
                r.Contains("TERMIND_SVC_OK") ? "#3FB950" : "#F85149");
            await RefreshMetricsAsync();   // 操作后刷新服务状态点
        }
        catch (System.Exception ex) { AppendTerm($"✕ {svc} {action} 异常：{ex.Message}", "#F85149"); }
    }

    /// 终端输出导出到文件（运维留存会话记录）：拼接 TermOutput 所有行 → StorageProvider 保存
    private async void OnExportTerm(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var top = TopLevel.GetTopLevel(this);
        if (top?.StorageProvider == null) return;
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"# Termind 终端会话导出 · {_activeHost ?? "本地"}");
        foreach (var child in TermOutput.Children) if (child is TextBlock tb) sb.AppendLine(tb.Text);
        try
        {
            var file = await top.StorageProvider.SaveFilePickerAsync(new Avalonia.Platform.Storage.FilePickerSaveOptions
            {
                Title = "导出终端输出",
                SuggestedFileName = "termind-session.txt",
                DefaultExtension = "txt",
            });
            if (file == null) return;
            await using var stream = await file.OpenWriteAsync();
            await using var writer = new System.IO.StreamWriter(stream);
            await writer.WriteAsync(sb.ToString());
            AppendTerm($"# 终端输出已导出到 {file.Name}", "#3FB950");
        }
        catch (System.Exception ex) { AppendTerm($"✕ 导出失败：{ex.Message}", "#F85149"); }
    }

    /// 进程 Top 面板：SSH ps 取 CPU 高占用进程 → 解析展示（深化监控，对照 apple Z6）
    private async void OnTopProcs(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        TopProcsList.Children.Clear();
        TopProcsList.Children.Add(new TextBlock { Text = "采集中…", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        try
        {
            var outp = await SshExecAsync("ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -11");
            var lines = outp.Split('\n', System.StringSplitOptions.RemoveEmptyEntries);
            TopProcsList.Children.Clear();
            foreach (var line in lines)
            {
                var cols = line.Trim().Split(' ', System.StringSplitOptions.RemoveEmptyEntries);
                if (cols.Length < 4) continue;
                var isHeader = cols[0] == "PID";
                var cpu = isHeader ? 0.0 : (double.TryParse(cols[1], out var cv) ? cv : 0);
                var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("48,46,46,*"), Margin = new Thickness(2, 1) };
                var fg = isHeader ? "#6B7280" : (cpu > 50 ? "#F85149" : cpu > 20 ? "#F59E0B" : "#C9D1D9");
                void Cell(string t, int col, string color) { var tb = new TextBlock { Text = t, Foreground = Brush.Parse(color), FontSize = 11, FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, TextTrimming = TextTrimming.CharacterEllipsis }; Grid.SetColumn(tb, col); grid.Children.Add(tb); }
                Cell(cols[0], 0, fg); Cell(cols[1], 1, fg); Cell(cols[2], 2, fg);
                Cell(string.Join(" ", cols[3..]), 3, isHeader ? "#6B7280" : "#C9D1D9");
                // 数据行右键 → 终止进程（危险操作，SSH kill PID + 刷新）
                if (!isHeader)
                {
                    var pid = cols[0]; var pname = string.Join(" ", cols[3..]);
                    var killMi = new MenuItem { Header = $"终止进程 {pid}（{pname}）", Foreground = Brush.Parse("#F85149") };
                    killMi.Click += async (_, _) =>
                    {
                        AppendTerm($"# kill {pid}（{pname}）…", "#F59E0B");
                        try { var rk = await SshExecAsync($"kill {pid} 2>&1 && echo TERMIND_KILL_OK"); AppendTerm(rk.Contains("TERMIND_KILL_OK") ? $"✓ 已终止进程 {pid}" : $"✕ 终止 {pid} 失败：{rk.Trim()}", rk.Contains("TERMIND_KILL_OK") ? "#3FB950" : "#F85149"); }
                        catch (System.Exception ex) { AppendTerm($"✕ 终止 {pid} 异常：{ex.Message}", "#F85149"); }
                    };
                    grid.ContextFlyout = new MenuFlyout { Items = { killMi } };
                    ToolTip.SetTip(grid, "右键终止进程");
                    grid.Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand);
                }
                TopProcsList.Children.Add(grid);
            }
            if (TopProcsList.Children.Count == 0) TopProcsList.Children.Add(new TextBlock { Text = "（未取到进程，检查连接）", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        }
        catch (System.Exception ex) { TopProcsList.Children.Clear(); TopProcsList.Children.Add(new TextBlock { Text = "采集失败：" + ex.Message, Foreground = Brush.Parse("#F85149"), FontSize = 12, Margin = new Thickness(4) }); }
    }

    /// 防火墙状态面板：SSH ufw status / iptables → 展示（安全运维，查防火墙规则）
    private async void OnFirewall(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        FirewallList.Children.Clear();
        FirewallList.Children.Add(new TextBlock { Text = "采集中…", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        try
        {
            // ufw 优先；无则 iptables 摘要（需 root）
            var outp = await SshExecAsync("ufw status 2>/dev/null || (echo 'iptables (filter):'; iptables -L -n 2>/dev/null | head -20) || echo '需 root 或未安装防火墙工具'");
            var lines = outp.Split('\n', System.StringSplitOptions.RemoveEmptyEntries);
            FirewallList.Children.Clear();
            foreach (var line in lines)
            {
                var t = line.TrimEnd();
                if (t.Length == 0) continue;
                // 状态行高亮：active 绿 / inactive 灰 / ACCEPT 绿 / DROP/REJECT 红
                var color = "#C9D1D9";
                if (t.Contains("active") || t.Contains("ACCEPT")) color = "#3FB950";
                else if (t.Contains("inactive")) color = "#F59E0B";
                else if (t.Contains("DROP") || t.Contains("REJECT") || t.Contains("DENY")) color = "#F85149";
                FirewallList.Children.Add(new TextBlock { Text = t, Foreground = Brush.Parse(color), FontSize = 11, FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(2, 1) });
            }
            if (FirewallList.Children.Count == 0) FirewallList.Children.Add(new TextBlock { Text = "（未取到防火墙信息，检查连接/权限）", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        }
        catch (System.Exception ex) { FirewallList.Children.Clear(); FirewallList.Children.Add(new TextBlock { Text = "采集失败：" + ex.Message, Foreground = Brush.Parse("#F85149"), FontSize = 12, Margin = new Thickness(4) }); }
    }

    /// 登录用户/最近登录面板：SSH who（在线）+ last（最近）→ 展示（安全运维，查谁在登录）
    private async void OnLoginUsers(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        LoginUsersList.Children.Clear();
        LoginUsersList.Children.Add(new TextBlock { Text = "采集中…", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        try
        {
            // who：当前在线（user tty time from-ip）；last：最近登录 8 条
            var outp = await SshExecAsync("echo '== 在线 =='; who; echo '== 最近 =='; last -n 8 2>/dev/null | head -8");
            var lines = outp.Split('\n', System.StringSplitOptions.RemoveEmptyEntries);
            LoginUsersList.Children.Clear();
            foreach (var line in lines)
            {
                var t = line.TrimEnd();
                if (t.Length == 0 || t.StartsWith("wtmp")) continue;
                var isHeader = t.StartsWith("==");
                var online = t.Contains("== 在线") ;
                var tb = new TextBlock
                {
                    Text = isHeader ? t.Replace("==", "").Trim() : t,
                    Foreground = Brush.Parse(isHeader ? (online ? "#3FB950" : "#8B92A8") : "#C9D1D9"),
                    FontSize = isHeader ? 11 : 11,
                    FontWeight = isHeader ? Avalonia.Media.FontWeight.SemiBold : Avalonia.Media.FontWeight.Normal,
                    FontFamily = isHeader ? FontFamily.Default : (Avalonia.Media.FontFamily)Resources["MonoFont"]!,
                    TextTrimming = TextTrimming.CharacterEllipsis,
                    Margin = new Thickness(2, isHeader ? 4 : 1, 2, 1),
                };
                LoginUsersList.Children.Add(tb);
            }
            if (LoginUsersList.Children.Count == 0) LoginUsersList.Children.Add(new TextBlock { Text = "（未取到登录信息，检查连接）", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        }
        catch (System.Exception ex) { LoginUsersList.Children.Clear(); LoginUsersList.Children.Add(new TextBlock { Text = "采集失败：" + ex.Message, Foreground = Brush.Parse("#F85149"), FontSize = 12, Margin = new Thickness(4) }); }
    }

    /// 磁盘分区详情面板：SSH df -h 取全分区 → 展示使用率（监控补全，对照状态条聚合磁盘）
    private async void OnDiskParts(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        DiskPartsList.Children.Clear();
        DiskPartsList.Children.Add(new TextBlock { Text = "采集中…", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        try
        {
            // df -hP：真实文件系统分区（排除 tmpfs/overlay 等虚拟）
            var outp = await SshExecAsync("df -hP -x tmpfs -x devtmpfs -x overlay 2>/dev/null | awk 'NR>1{print $5\" \"$6\" \"$3\"/\"$2}'");
            var lines = outp.Split('\n', System.StringSplitOptions.RemoveEmptyEntries);
            DiskPartsList.Children.Clear();
            foreach (var line in lines)
            {
                var cols = line.Trim().Split(' ', System.StringSplitOptions.RemoveEmptyEntries);
                if (cols.Length < 3) continue;
                int.TryParse(cols[0].TrimEnd('%'), out var pct);
                var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,80,Auto"), Margin = new Thickness(2, 2) };
                var mount = new TextBlock { Text = cols[1], Foreground = Brush.Parse("#C9D1D9"), FontSize = 11, FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, TextTrimming = TextTrimming.CharacterEllipsis };
                var bar = new Border { Width = 70, Height = 5, Background = Brush.Parse("#1AFFFFFF"), CornerRadius = new Avalonia.CornerRadius(2), VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left };
                bar.Child = new Border { Width = 70.0 * System.Math.Clamp(pct, 0, 100) / 100, Height = 5, Background = Brush.Parse(pct > 80 ? "#F85149" : pct > 60 ? "#F59E0B" : "#3FB950"), CornerRadius = new Avalonia.CornerRadius(2), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left };
                var info = new TextBlock { Text = $"{cols[0]} · {cols[2]}", Foreground = Brush.Parse(pct > 80 ? "#F85149" : "#8B92A8"), FontSize = 10, FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center, Margin = new Thickness(6, 0, 0, 0) };
                Grid.SetColumn(mount, 0); Grid.SetColumn(bar, 1); Grid.SetColumn(info, 2);
                grid.Children.Add(mount); grid.Children.Add(bar); grid.Children.Add(info);
                DiskPartsList.Children.Add(grid);
            }
            if (DiskPartsList.Children.Count == 0) DiskPartsList.Children.Add(new TextBlock { Text = "（未取到分区，检查连接）", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        }
        catch (System.Exception ex) { DiskPartsList.Children.Clear(); DiskPartsList.Children.Add(new TextBlock { Text = "采集失败：" + ex.Message, Foreground = Brush.Parse("#F85149"), FontSize = 12, Margin = new Thickness(4) }); }
    }

    /// 网络端口监听面板：SSH ss 取监听端口 + 进程 → 展示（深化监控，对照 apple/快捷命令 ss -tlnp）
    private async void OnListenPorts(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        ListenPortsList.Children.Clear();
        ListenPortsList.Children.Add(new TextBlock { Text = "采集中…", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        try
        {
            // ss -tlnp：监听 TCP + 进程；提取 本地地址:端口 + 进程名
            var outp = await SshExecAsync("ss -tlnpH 2>/dev/null | awk '{print $4\" \"$6}' | head -20");
            var lines = outp.Split('\n', System.StringSplitOptions.RemoveEmptyEntries);
            ListenPortsList.Children.Clear();
            foreach (var line in lines)
            {
                var parts = line.Trim().Split(' ', 2, System.StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 0) continue;
                var addr = parts[0];
                var port = addr.Contains(':') ? addr[(addr.LastIndexOf(':') + 1)..] : addr;
                // 进程名从 users:(("nginx",pid=123,...)) 提取
                var proc = "";
                if (parts.Length > 1) { var m = System.Text.RegularExpressions.Regex.Match(parts[1], "\"([^\"]+)\""); if (m.Success) proc = m.Groups[1].Value; }
                var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("70,*"), Margin = new Thickness(2, 1) };
                var p = new TextBlock { Text = ":" + port, Foreground = Brush.Parse("#3FB950"), FontSize = 11, FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]! };
                var c = new TextBlock { Text = proc.Length > 0 ? proc : addr, Foreground = Brush.Parse("#C9D1D9"), FontSize = 11, FontFamily = (Avalonia.Media.FontFamily)Resources["MonoFont"]!, TextTrimming = TextTrimming.CharacterEllipsis };
                Grid.SetColumn(p, 0); Grid.SetColumn(c, 1); grid.Children.Add(p); grid.Children.Add(c);
                ListenPortsList.Children.Add(grid);
            }
            if (ListenPortsList.Children.Count == 0) ListenPortsList.Children.Add(new TextBlock { Text = "（未取到监听端口，检查连接）", Foreground = Brush.Parse("#6B7280"), FontSize = 12, Margin = new Thickness(4) });
        }
        catch (System.Exception ex) { ListenPortsList.Children.Clear(); ListenPortsList.Children.Add(new TextBlock { Text = "采集失败：" + ex.Message, Foreground = Brush.Parse("#F85149"), FontSize = 12, Margin = new Thickness(4) }); }
    }

    /// AI 对话搜索：匹配气泡橙色描边高亮 + 首个滚动到可见（对照终端搜索）
    private void OnAiSearch(object? sender, Avalonia.Controls.TextChangedEventArgs e)
    {
        var q = AiSearchBox.Text?.Trim().ToLowerInvariant() ?? "";
        Control? firstHit = null;
        foreach (var child in AiMessages.Children)
        {
            if (child is not Border b) continue;   // 气泡是 Border（含 TextBlock 或 StackPanel）
            var text = BubbleText(b).ToLowerInvariant();
            var hit = q.Length > 0 && text.Contains(q);
            b.BorderBrush = hit ? Brush.Parse("#F59E0B") : null;
            b.BorderThickness = new Thickness(hit ? 1.5 : 0);
            if (hit && firstHit == null) firstHit = b;
        }
        firstHit?.BringIntoView();
    }

    /// 提取气泡内文本（Border 内可能是 TextBlock 或 StackPanel of TextBlock）
    private static string BubbleText(Border b) => b.Child switch
    {
        TextBlock tb => tb.Text ?? "",
        StackPanel sp => string.Join(" ", sp.Children.OfType<TextBlock>().Select(t => t.Text ?? "")),
        _ => "",
    };

    /// 终端输出搜索：匹配行背景高亮（黄），首个匹配滚动到可见
    private void OnTermSearch(object? sender, Avalonia.Controls.TextChangedEventArgs e)
    {
        var q = TermSearchBox.Text?.Trim().ToLowerInvariant() ?? "";
        Control? firstHit = null;
        foreach (var child in TermOutput.Children)
        {
            if (child is not TextBlock tb) continue;
            var hit = q.Length > 0 && (tb.Text?.ToLowerInvariant().Contains(q) ?? false);
            tb.Background = hit ? Brush.Parse("#33F59E0B") : null;   // 命中行橙色半透明高亮
            if (hit && firstHit == null) firstHit = tb;
        }
        firstHit?.BringIntoView();
    }

    /// 搜索框过滤连接列表（名称/地址匹配，对照 linux/apple 搜索）
    private void OnSearchConn(object? sender, Avalonia.Controls.TextChangedEventArgs e)
    {
        var q = SearchBox.Text?.Trim().ToLowerInvariant() ?? "";
        if (string.IsNullOrEmpty(q)) { ConnList.ItemsSource = _conns; return; }
        ConnList.ItemsSource = _conns.Where(c =>
            c.Name.ToLowerInvariant().Contains(q) || c.Addr.ToLowerInvariant().Contains(q) || c.Note.ToLowerInvariant().Contains(q)).ToList();
    }

    /// 连接列表选中变化 → 终端区状态条反映选中连接 + 驱动 SSH 执行目标（真实连接切换）
    private void OnConnSelected(object? sender, SelectionChangedEventArgs e)
    {
        if (ConnList.SelectedItem is not ConnItem c) return;
        // 地址形如 user@host:port → 解析 user / host
        var addr = c.Addr;
        string? user = null;
        var at = addr.IndexOf('@'); if (at >= 0) { user = addr[..at]; addr = addr[(at + 1)..]; }
        var colon = addr.IndexOf(':'); if (colon >= 0) addr = addr[..colon];
        // 切换连接目标 → 重置复用的 SSH 会话（下次 exec 连新主机）
        if (_activeHost != addr || _activeUser != user)
        {
            lock (_sshLock) { _sshClient?.Dispose(); _sshClient = null; }
            _envCache = null;   // 环境感知缓存也失效
        }
        _activeHost = addr; _activeUser = user;
        var online = c.Reach == "✓";
        StatusHost.Text = $"主机 {addr}";
        StatusDot.Text = online ? "● 已连接" : "○ 离线";
        StatusDot.Foreground = online ? Brush.Parse("#3FB950") : Brush.Parse("#6B7280");
        _ = RefreshMetricsAsync();   // 真实指标刷新（SSH 取 CPU/内存/负载）
    }

    /// 状态条真实指标刷新（SSH 取 CPU/内存/负载，对齐 linux/proc 与 apple）：一条命令取齐再解析
    private async Task RefreshMetricsAsync()
    {
        try
        {
            // /proc/stat 两次采样算 CPU% + free 内存% + df 磁盘% + loadavg + 关键服务 systemctl is-active
            const string cmd = "cat /proc/loadavg | awk '{print $1}'; free -m | awk '/Mem:/{printf \"%d %d\\n\",$3,$2}'; " +
                "df / | tail -1 | awk '{print $5}' | tr -d '%'; " +
                "awk '/^cpu /{u=$2+$4;t=$2+$4+$5;print u\" \"t}' /proc/stat; sleep 0.4; awk '/^cpu /{u=$2+$4;t=$2+$4+$5;print u\" \"t}' /proc/stat; " +
                "for s in nginx docker mysql redis sshd; do echo $s:$(systemctl is-active $s 2>/dev/null); done";
            var outp = await SshExecAsync(cmd);
            var lines = outp.Split('\n', System.StringSplitOptions.RemoveEmptyEntries);
            if (lines.Length < 5) return;
            // 解析服务状态行（svc:active/inactive）
            var svcs = lines.Where(l => l.Contains(':') && !l.Contains(' '))
                .Select(l => l.Split(':')).Where(p => p.Length == 2)
                .Select(p => (Name: p[0].Trim(), Active: p[1].Trim() == "active")).ToList();
            var load = lines[0].Trim();
            var mem = lines[1].Split(' ', System.StringSplitOptions.RemoveEmptyEntries);   // used total
            int.TryParse(lines[2].Trim(), out var diskPct);                                // 磁盘根分区使用%
            var c1 = lines[3].Split(' ', System.StringSplitOptions.RemoveEmptyEntries);    // u t (前)
            var c2 = lines[4].Split(' ', System.StringSplitOptions.RemoveEmptyEntries);    // u t (后)
            int memPct = 0, cpuPct = 0;
            if (mem.Length == 2 && double.TryParse(mem[1], out var mt) && mt > 0 && double.TryParse(mem[0], out var mu))
                memPct = (int)System.Math.Round(mu / mt * 100);
            if (c1.Length == 2 && c2.Length == 2 && double.TryParse(c1[0], out var u1) && double.TryParse(c1[1], out var t1)
                && double.TryParse(c2[0], out var u2) && double.TryParse(c2[1], out var t2) && t2 > t1)
                cpuPct = (int)System.Math.Round((u2 - u1) / (t2 - t1) * 100);
            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                StatusCpu.Text = $"CPU {cpuPct}%"; StatusCpuBar.Width = 54.0 * System.Math.Clamp(cpuPct, 0, 100) / 100;
                StatusCpuBar.Background = Brush.Parse(cpuPct > 80 ? "#F85149" : cpuPct > 60 ? "#F59E0B" : "#3FB950");
                StatusMem.Text = $"内存 {memPct}%"; StatusMemBar.Width = 54.0 * System.Math.Clamp(memPct, 0, 100) / 100;
                StatusMemBar.Background = Brush.Parse(memPct > 80 ? "#F85149" : memPct > 60 ? "#F59E0B" : "#3FB950");
                StatusDisk.Text = $"磁盘 {diskPct}%"; StatusDiskBar.Width = 54.0 * System.Math.Clamp(diskPct, 0, 100) / 100;
                StatusDiskBar.Background = Brush.Parse(diskPct > 80 ? "#F85149" : diskPct > 60 ? "#F59E0B" : "#3FB950");
                StatusLoad.Text = $"负载 {load}";
                // 指标超阈值告警（>90% 预警，运维主动发现风险）
                var alerts = new System.Collections.Generic.List<string>();
                if (cpuPct > 90) alerts.Add($"CPU {cpuPct}%");
                if (memPct > 90) alerts.Add($"内存 {memPct}%");
                if (diskPct > 90) alerts.Add($"磁盘 {diskPct}%");
                StatusAlert.IsVisible = alerts.Count > 0;
                if (alerts.Count > 0) StatusAlertText.Text = $"⚠ {string.Join(" / ", alerts)}";
                // 服务状态点真实填充（绿=active / 灰=非）
                StatusServices.Children.Clear();
                foreach (var s in svcs)
                {
                    var sp = new StackPanel { Orientation = Avalonia.Layout.Orientation.Horizontal, Spacing = 3, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center, Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand) };
                    sp.Children.Add(new TextBlock { Text = "●", Foreground = Brush.Parse(s.Active ? "#3FB950" : "#6B7280"), FontSize = 11, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center });
                    sp.Children.Add(new TextBlock { Text = s.Name, Foreground = Brush.Parse(s.Active ? "#C9D1D9" : "#6B7280"), FontSize = 12, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center });
                    // 服务管理：右键 menu 启停/重启（SSH systemctl，深化护城河，停止/重启标橙警示）
                    var mf = new MenuFlyout();
                    foreach (var (act, label, danger) in new[] { ("restart", "重启", true), ("start", "启动", false), ("stop", "停止", true) })
                    {
                        var mi = new MenuItem { Header = $"{label} {s.Name}", Tag = $"{act}:{s.Name}", Foreground = Brush.Parse(danger ? "#F59E0B" : "#C9D1D9") };
                        mi.Click += OnServiceAction;
                        mf.Items.Add(mi);
                    }
                    sp.ContextFlyout = mf;
                    sp.PointerPressed += (snd, ev) => { if (snd is Control ctl) mf.ShowAt(ctl); };   // 左键点击也弹 menu
                    ToolTip.SetTip(sp, $"{s.Name}：{(s.Active ? "运行中" : "未运行")}（点击管理）");
                    StatusServices.Children.Add(sp);
                }
            });
        }
        catch { /* 离线/取指标失败：保留上次值，不打断 */ }
    }

    private string _sftpCwd = "~";   // SFTP 当前目录（支持导航）
    private string? _sftpRenaming;   // 待重命名文件原路径（非空=重命名模式，复用新建目录输入框）

    /// SFTP 打开按钮 → 浏览 home 目录
    private void OnSftpOpen(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => LoadSftp("~");

    /// SFTP 上传（对照 apple sftpUpload）：选本地文件 → base64 → SSH 写到当前目录
    private async void OnSftpUpload(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var top = TopLevel.GetTopLevel(this);
        if (top?.StorageProvider == null) return;
        var files = await top.StorageProvider.OpenFilePickerAsync(new Avalonia.Platform.Storage.FilePickerOpenOptions { Title = "上传到 " + _sftpCwd, AllowMultiple = false });
        if (files.Count == 0) return;
        var f = files[0];
        try
        {
            await using var stream = await f.OpenReadAsync();
            using var ms = new System.IO.MemoryStream();
            await stream.CopyToAsync(ms);
            var bytes = ms.ToArray();
            if (bytes.Length > 5_000_000) { AppendTerm($"# 上传 {f.Name}：文件 {bytes.Length / 1024 / 1024}MB 过大（base64 经命令行限 5MB）", "#F59E0B"); return; }
            AppendTerm($"# 上传 {f.Name} → {_sftpCwd} …", "#8B92A8");
            var b64 = System.Convert.ToBase64String(bytes);
            var remote = $"{_sftpCwd}/{f.Name}".Replace("'", "");
            // base64 内容经 stdin 传输（printf 避免 echo 长度限制），远端 base64 -d 解码写文件
            var r = await SshExecAsync($"printf '%s' '{b64}' | base64 -d > '{remote}' && echo TERMIND_UP_OK");
            if (r.Contains("TERMIND_UP_OK")) { AppendTerm($"  ✓ 已上传（{bytes.Length} 字节）", "#3FB950"); LoadSftp(_sftpCwd); }
            else AppendTerm($"  ✕ 上传失败：{r}", "#F59E0B");
        }
        catch (System.Exception ex) { AppendTerm($"  ✕ 上传失败：{ex.Message}", "#F59E0B"); }
    }

    /// SFTP 新建目录 / 重命名（输入框复用）：有 _sftpRenaming 则 mv 重命名（对照 apple sftpRename），否则 mkdir
    private async void OnMkdir(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var input = NewDirName.Text?.Trim();
        if (string.IsNullOrEmpty(input)) return;
        if (_sftpRenaming != null)
        {
            // 重命名：mv 原文件 → 同目录新名
            var src = _sftpRenaming.Replace("'", "");
            var dst = $"{_sftpCwd}/{input}".Replace("'", "");
            _sftpRenaming = null;
            AppendTerm($"# 重命名 → {dst} …", "#8B92A8");
            var rr = await SshExecAsync($"mv '{src}' '{dst}' && echo TERMIND_MV_OK");
            if (rr.Contains("TERMIND_MV_OK")) { AppendTerm("  ✓ 已重命名", "#3FB950"); NewDirName.Text = ""; LoadSftp(_sftpCwd); }
            else AppendTerm($"  ✕ 重命名失败：{rr}", "#F59E0B");
            return;
        }
        var target = $"{_sftpCwd}/{input}".Replace("'", "");
        AppendTerm($"# 新建目录 {target} …", "#8B92A8");
        var r = await SshExecAsync($"mkdir -p '{target}' && echo TERMIND_MKDIR_OK");
        if (r.Contains("TERMIND_MKDIR_OK")) { AppendTerm("  ✓ 已创建", "#3FB950"); NewDirName.Text = ""; LoadSftp(_sftpCwd); }
        else AppendTerm($"  ✕ 创建失败：{r}", "#F59E0B");
    }

    /// SFTP 文件删除（对照 apple sftpRemove）：SSH rm + 刷新列表（嵌套确认菜单防误删）
    private async void DeleteSftpFile(string filePath)
    {
        var p = filePath.Replace("'", "");
        AppendTerm($"# 删除 {filePath} …", "#F59E0B");
        var r = await SshExecAsync($"rm -f '{p}' && echo TERMIND_RM_OK");
        if (r.Contains("TERMIND_RM_OK")) { AppendTerm("  ✓ 已删除", "#3FB950"); LoadSftp(_sftpCwd); }
        else AppendTerm($"  ✕ 删除失败：{r}", "#F59E0B");
    }

    /// SFTP 文件下载（对照 apple sftpDownload）：SSH base64 取内容 → 存本地 Downloads
    private async void DownloadFile(string filePath, string fileName)
    {
        var p = filePath.Replace("'", "");
        AppendTerm($"# 下载 {filePath} …", "#8B92A8");
        // 大小守门（>10MB 不下，base64 经终端传输适合中小文件）
        var sizeStr = await SshExecAsync($"stat -c %s '{p}' 2>/dev/null");
        long.TryParse(sizeStr.Trim(), out var size);
        if (size > 10_000_000) { AppendTerm($"  （文件 {size / 1024 / 1024}MB 过大，跳过下载）", "#F59E0B"); return; }
        var b64 = await SshExecAsync($"base64 '{p}' 2>/dev/null");
        if (b64.StartsWith("⚠") || b64.Length == 0) { AppendTerm("  下载失败", "#F59E0B"); return; }
        try
        {
            var bytes = System.Convert.FromBase64String(b64.Replace("\n", "").Replace("\r", ""));
            var dir = System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.UserProfile), "Downloads");
            System.IO.Directory.CreateDirectory(dir);
            var local = System.IO.Path.Combine(dir, fileName);
            await System.IO.File.WriteAllBytesAsync(local, bytes);
            AppendTerm($"  ✓ 已下载到 {local}（{bytes.Length} 字节）", "#3FB950");
        }
        catch (System.Exception ex) { AppendTerm($"  ✕ 下载失败：{ex.Message}", "#F59E0B"); }
    }

    /// SFTP 文件预览：SSH 判断文本/大小，文本则 head 前 200 行到终端区显示
    private async void PreviewFile(string filePath)
    {
        var p = filePath.Replace("'", "");
        AppendTerm($"# 预览 {filePath}", "#8B92A8");
        // file 判类型 + 大小守门：>1MB 或二进制不预览
        var meta = await SshExecAsync($"stat -c %s '{p}' 2>/dev/null; file -b '{p}' 2>/dev/null");
        var mlines = meta.Split('\n');
        long.TryParse(mlines.Length > 0 ? mlines[0].Trim() : "0", out var size);
        var ftype = mlines.Length > 1 ? mlines[1] : "";
        if (size > 1_000_000) { AppendTerm($"  （文件 {size / 1024}KB 过大，跳过预览）", "#F59E0B"); return; }
        if (ftype.Contains("executable") || ftype.Contains("binary") || ftype.Contains("data")) { AppendTerm($"  （{ftype.Trim()}，二进制不预览）", "#F59E0B"); return; }
        var content = await SshExecAsync($"head -n 200 '{p}'");
        foreach (var line in content.Split('\n')) AppendTerm(line.TrimEnd(), "#A0A0A0");
    }

    /// SFTP 真实文件列表（SSH ls 指定目录）；目录可点击导航，".." 返回上级
    private async void LoadSftp(string path)
    {
        SftpList.Children.Clear();
        SftpList.Children.Add(new TextBlock { Text = "加载中…", Foreground = Brush.Parse("#8B92A8"), FontSize = 12 });
        // cd 到目标目录后 ls（path 用单引号防注入空格）
        var result = await SshExecAsync($"cd '{path.Replace("'", "")}' 2>/dev/null && pwd && ls -la --time-style=long-iso");
        SftpList.Children.Clear();
        if (result.StartsWith("⚠")) { SftpList.Children.Add(new TextBlock { Text = result, Foreground = Brush.Parse("#F59E0B"), FontSize = 12, TextWrapping = TextWrapping.Wrap }); return; }
        var lines = result.Split('\n');
        _sftpCwd = lines.Length > 0 ? lines[0].Trim() : path;   // 真实 pwd
        SftpPath.Text = _sftpCwd;
        var mono = (FontFamily)(this.FindResource("MonoFont") ?? FontFamily.Default);
        foreach (var line in lines.Skip(1))
        {
            // 形如：drwxr-xr-x 2 root root 4096 2026-06-22 18:00 projects
            var parts = line.Split(new[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 8 || line.StartsWith("total") || line.StartsWith("合计")) continue;
            var isDir = parts[0].StartsWith("d");
            var size = parts[4];
            var date = parts.Length >= 7 ? $"{parts[5]} {parts[6]}" : "";
            var name = string.Join(" ", parts.Skip(7));
            if (name == "." ) continue;
            var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto,Auto"), Margin = new Thickness(0, 3) };
            var icon = new PathIcon
            {
                Width = 13, Height = 13, Margin = new Thickness(0, 0, 8, 0),
                Foreground = Brush.Parse(isDir ? "#3B82F6" : "#8B92A8"),
                Data = Avalonia.Media.Geometry.Parse(isDir
                    ? "M10,4H4C2.89,4 2,4.89 2,6V18A2,2 0 0,0 4,20H20A2,2 0 0,0 22,18V8C22,6.89 21.1,6 20,6H12L10,4Z"
                    : "M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z")
            };
            Grid.SetColumn(icon, 0); grid.Children.Add(icon);
            var nameTb = new TextBlock { Text = name, Foreground = Brush.Parse(isDir ? "#C9D1D9" : "#C9D1D9"), FontSize = 13, TextTrimming = TextTrimming.CharacterEllipsis };
            Grid.SetColumn(nameTb, 1); grid.Children.Add(nameTb);
            if (!isDir) { var sz = new TextBlock { Text = size, Foreground = Brush.Parse("#6B7280"), FontSize = 11, FontFamily = mono }; Grid.SetColumn(sz, 2); grid.Children.Add(sz); }
            var dt = new TextBlock { Text = date, Foreground = Brush.Parse("#5A6270"), FontSize = 10, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center, Margin = new Thickness(8, 0, 0, 0) };
            Grid.SetColumn(dt, 3); grid.Children.Add(dt);
            // 目录可点击导航（cd 进入 / .. 返回上级）
            if (isDir)
            {
                var btn = new Button { Background = Brush.Parse("#00000000"), BorderThickness = new Thickness(0), Padding = new Thickness(2), Content = grid, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Left, Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand) };
                var target = name == ".." ? $"{_sftpCwd}/.." : $"{_sftpCwd}/{name}";
                btn.Click += (_, _) => LoadSftp(target);
                SftpList.Children.Add(btn);
            }
            else
            {
                // 文件可点击预览（cat 前 200 行，到终端区显示）
                var fbtn = new Button { Background = Brush.Parse("#00000000"), BorderThickness = new Thickness(0), Padding = new Thickness(2), Content = grid, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Left, Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand) };
                var fpath = $"{_sftpCwd}/{name}";
                fbtn.Click += (_, _) => PreviewFile(fpath);
                // 右键菜单：下载到本地（对照 apple sftpDownload）+ 删除（嵌套确认防误删，对照 apple sftpRemove）
                var fname = name;
                var menu = new MenuFlyout();
                var dl = new MenuItem { Header = "下载到本地" };
                dl.Click += (_, _) => DownloadFile(fpath, fname);
                menu.Items.Add(dl);
                var ren = new MenuItem { Header = "重命名" };
                ren.Click += (_, _) => { _sftpRenaming = fpath; NewDirName.Text = fname; NewDirName.Focus(); };
                menu.Items.Add(ren);
                var del = new MenuItem { Header = "删除", Foreground = Brush.Parse("#F87171") };
                var confirmDel = new MenuItem { Header = $"⚠ 确认删除 {fname}" };
                confirmDel.Click += (_, _) => DeleteSftpFile(fpath);
                del.Items.Add(confirmDel);
                menu.Items.Add(del);
                fbtn.ContextFlyout = menu;
                SftpList.Children.Add(fbtn);
            }
        }
        if (SftpList.Children.Count == 0) SftpList.Children.Add(new TextBlock { Text = "(空目录)", Foreground = Brush.Parse("#6B7280"), FontSize = 12 });
    }

    /// 批量群发（护城河：多连接群发命令，对照 apple batch）：对所有连接并发 SSH 执行，聚合结果
    private async void OnBatchExec(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var cmd = CmdInput.Text?.Trim();
        if (string.IsNullOrEmpty(cmd) || _conns.Count == 0) return;
        CmdInput.Text = "";
        AppendTerm($"⇶ 批量群发「{cmd}」→ {_conns.Count} 台连接", "#F59E0B");
        // 各连接并发执行（解析 user@host:port），结果聚合分段显示
        var tasks = _conns.Select(async c =>
        {
            var addr = c.Addr; string user = "root";
            var at = addr.IndexOf('@'); if (at >= 0) { user = addr[..at]; addr = addr[(at + 1)..]; }
            var colon = addr.IndexOf(':'); if (colon >= 0) addr = addr[..colon];
            var r = await SshExecToHostAsync(addr, user, cmd);
            return (c.Name, addr, r);
        }).ToList();
        var results = await Task.WhenAll(tasks);
        foreach (var (name, host, r) in results)
        {
            var ok = !r.StartsWith("⚠");
            AppendTerm($"── {name} ({host}) {(ok ? "✓" : "✕")} ──", "#60A5FA");
            foreach (var line in r.Split('\n')) AppendTerm("  " + line.TrimEnd(), ok ? "#A0A0A0" : "#F59E0B");
        }
        AppendTerm($"⇶ 批量完成（{results.Count(x => !x.r.StartsWith("⚠"))}/{results.Length} 成功）", "#F59E0B");
    }

    /// 指定主机 SSH exec（批量用，不复用 _sshClient 避免冲突）；密码 env TERMIND_SSH_PASS
    private async Task<string> SshExecToHostAsync(string host, string user, string cmd)
    {
        var pass = System.Environment.GetEnvironmentVariable("TERMIND_SSH_PASS") ?? "";
        if (string.IsNullOrEmpty(pass)) return "⚠️ 未配置 SSH 密码";
        return await Task.Run(() =>
        {
            try
            {
                using var client = new Renci.SshNet.SshClient(host, 22, user, pass) { ConnectionInfo = { Timeout = System.TimeSpan.FromSeconds(8) } };
                client.Connect();
                using var c = client.RunCommand(cmd);
                client.Disconnect();
                var outp = (c.Result ?? "") + (c.Error ?? "");
                return outp.Length == 0 ? "(无输出)" : outp.TrimEnd();
            }
            catch (System.Exception ex) { return "⚠️ " + ex.Message; }
        });
    }

    // U3 主题：4 套（午夜/Dracula/Nord/Solarized），各主要背景色（窗口/侧栏/终端/AI）+ 强调色
    // 各主题色：[窗口bg, 侧栏bg, 终端bg, AI bg, 强调色, 次级面板bg]
    private static readonly string[][] Themes =
    {
        new[] { "#1A1A2E", "#16213E", "#0D0E1A", "#10121F", "#FF4B6E", "#16182A" },   // 午夜
        new[] { "#282A36", "#343746", "#21222C", "#282A36", "#FF79C6", "#343746" },   // Dracula
        new[] { "#2E3440", "#3B4252", "#272C36", "#2E3440", "#88C0D0", "#3B4252" },   // Nord
        new[] { "#002B36", "#073642", "#002028", "#002B36", "#D33682", "#073642" },   // Solarized
    };

    /// U3 主题切换（点击配色主题）：改 Application.Resources 主要背景/强调色资源 + 持久化
    private void OnTheme(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (sender is not Button b || b.Tag is not string tag || !int.TryParse(tag, out var idx)) return;
        ApplyTheme(idx);
        SaveConfig();
    }

    private void ApplyTheme(int idx)
    {
        if (idx < 0 || idx >= Themes.Length) idx = 0;
        _themeIdx = idx;
        var t = Themes[idx];
        var res = Application.Current!.Resources;
        res["ThemeWindowBg"] = new SolidColorBrush(Color.Parse(t[0]));
        res["ThemeSideBg"] = new SolidColorBrush(Color.Parse(t[1]));
        res["ThemeTermBg"] = new SolidColorBrush(Color.Parse(t[2]));
        res["ThemeAiBg"] = new SolidColorBrush(Color.Parse(t[3]));
        res["ThemeAccent"] = new SolidColorBrush(Color.Parse(t[4]));
        res["ThemeCardBg"] = new SolidColorBrush(Color.Parse(t[5]));
    }

    private int _themeIdx = 0;

    /// 编辑连接（右键菜单）：解析 user@host:port 填入新建表单 + 移除原项，改后点「添加」重加（CRUD 的 U）
    private void OnEditConn(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (sender is not Control c || c.DataContext is not ConnItem item) return;
        var addr = item.Addr; string user = "root", port = "22";
        var at = addr.IndexOf('@'); if (at >= 0) { user = addr[..at]; addr = addr[(at + 1)..]; }
        var colon = addr.IndexOf(':'); if (colon >= 0) { port = addr[(colon + 1)..]; addr = addr[..colon]; }
        NewConnName.Text = item.Name; NewConnHost.Text = addr; NewConnUser.Text = user; NewConnPort.Text = port;
        _conns.Remove(item);
        SaveConfig();
        AppendTerm($"# 已载入「{item.Name}」到新建连接表单（工具栏 +），修改后点「添加」即可", "#8B92A8");
    }

    /// 删除连接（右键菜单）：从列表移除 + 持久化（连接管理 CRUD）
    private void OnDeleteConn(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        // 从 MenuItem 的 DataContext 取被右键的连接
        if (sender is Control c && c.DataContext is ConnItem item)
        {
            _conns.Remove(item);
            if (ConnList.SelectedItem == null && _conns.Count > 0) ConnList.SelectedIndex = 0;
            SaveConfig();   // 持久化（删除的用户连接不再恢复）
        }
    }

    /// 新建连接：读表单 name/host/user/port → 加入连接列表（ObservableCollection 自动刷新）
    private void OnAddConn(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var name = NewConnName.Text?.Trim();
        var host = NewConnHost.Text?.Trim();
        if (string.IsNullOrEmpty(name) || string.IsNullOrEmpty(host)) return;
        var user = string.IsNullOrWhiteSpace(NewConnUser.Text) ? "root" : NewConnUser.Text.Trim();
        var port = string.IsNullOrWhiteSpace(NewConnPort.Text) ? "22" : NewConnPort.Text.Trim();
        var gray = Brush.Parse("#6B7280");
        var item = new ConnItem(name, $"{user}@{host}:{port}", Brush.Parse("#3FB950"), gray, "我的连接", true, "⏳", gray, "", false, "", false);
        _conns.Add(item);
        ConnList.SelectedItem = item;
        _ = ProbeReachabilityAsync(item);   // 新连接异步探测可达性
        SaveConfig();                        // 持久化新连接（重启恢复）
        NewConnName.Text = ""; NewConnHost.Text = ""; NewConnUser.Text = ""; NewConnPort.Text = "22";
    }

    /// 快捷命令点击 → 填入命令输入框（真实交互，对照 linux/apple/android）
    private void OnQuickCmd(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (sender is Button b && b.Content is string cmd)
        {
            CmdInput.Text = cmd;
            CmdInput.Focus();
        }
    }

    /// 运维快捷入口（对照 apple 护城河 Z1命令解释/Z2报错分析/Z3健康巡检）
    /// 解释/报错 → 预填提问；健康巡检 → 一键直接触发（SSH 取指标 + AI 分析真闭环）
    private void OnOpsQuick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (sender is not Button b || b.Tag is not string tag) return;
        if (tag == "health") { RunHealthCheck(); return; }
        if (tag == "error") { RunErrorAnalysis(); return; }
        AiInput.Text = tag switch
        {
            "explain" => "解释这条命令的作用、参数含义和潜在风险：",
            _ => ""
        };
        AiInput.Focus();
        AiInput.CaretIndex = AiInput.Text.Length;
    }

    /// 一键报错分析（Z2）：SSH 取最近错误日志 → AI 诊断（现象→原因→修复）真闭环
    private async void RunErrorAnalysis()
    {
        AiMessages.Children.Add(new TextBlock { Text = $"你 · {System.DateTime.Now:HH:mm}", Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right });
        AiMessages.Children.Add(new Border
        {
            Background = Brush.Parse("#3B82F6"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right, MaxWidth = 260,
            Child = new TextBlock { Text = "一键分析最近报错", Foreground = Brush.Parse("#FFFFFF"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap }
        });
        var aiPanel = new StackPanel { Spacing = 2 };
        aiPanel.Children.Add(new TextBlock { Text = "采集最近错误日志中…", Foreground = Brush.Parse("#C9D1D9"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap });
        AiMessages.Children.Add(new Border
        {
            Background = Brush.Parse("#0D0E1A"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, MaxWidth = 290, Child = aiPanel
        });
        AiScroll.ScrollToEnd();
        // SSH 取系统级错误日志 + 失败服务（journalctl 优先，兼容无 systemd 回退 dmesg）
        var logs = await SshExecAsync(
            "echo '== 最近错误日志 =='; journalctl -p err -n 40 --no-pager 2>/dev/null | tail -40 || dmesg -l err,crit 2>/dev/null | tail -40; " +
            "echo '== 失败的服务 =='; systemctl --failed --no-pager 2>/dev/null | head -15");
        ((TextBlock)aiPanel.Children[0]).Text = "诊断中…";
        var reply = await CallAiAsync($"以下是这台服务器最近的系统错误日志和失败服务，请按 现象 → 可能原因 → 修复步骤 诊断，给出可执行的修复命令（高危用 ⚠️ 标注）。若日志为空说明系统暂无明显错误。\n\n{logs}",
            delta => { ((TextBlock)aiPanel.Children[0]).Text = delta; AiScroll.ScrollToEnd(); });
        RenderAiReply(aiPanel, reply);
        foreach (Match m in Regex.Matches(reply, @"\[EXECUTE\]([\s\S]*?)\[/EXECUTE\]"))
        {
            var cmd = m.Groups[1].Value.Trim();
            if (cmd.Length > 0) AddCommandCard(cmd);
        }
        AiScroll.ScrollToEnd();
    }

    /// 一键健康巡检（Z3）：SSH 取真实指标 → 直接发 AI 分析（无需手动输入）
    private async void RunHealthCheck()
    {
        // 用户气泡（标识本次巡检）
        AiMessages.Children.Add(new TextBlock { Text = $"你 · {System.DateTime.Now:HH:mm}", Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right });
        AiMessages.Children.Add(new Border
        {
            Background = Brush.Parse("#3B82F6"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right, MaxWidth = 260,
            Child = new TextBlock { Text = "一键健康巡检", Foreground = Brush.Parse("#FFFFFF"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap }
        });
        // AI 气泡（先采集真实指标，再交 AI 分析）
        var aiPanel = new StackPanel { Spacing = 2 };
        aiPanel.Children.Add(new TextBlock { Text = "采集服务器指标中…", Foreground = Brush.Parse("#C9D1D9"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap });
        AiMessages.Children.Add(new Border
        {
            Background = Brush.Parse("#0D0E1A"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, MaxWidth = 290, Child = aiPanel
        });
        AiScroll.ScrollToEnd();
        // SSH 取真实指标（CPU/内存/磁盘/负载/Top 进程/服务），交 AI 分析
        var metrics = await SshExecAsync(
            "echo '== 负载/运行 =='; uptime; echo '== 内存 =='; free -h; echo '== 磁盘 =='; df -h; " +
            "echo '== CPU Top5 =='; ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -6; " +
            "echo '== 服务 =='; for s in nginx docker mysql redis sshd; do printf '%s:' $s; systemctl is-active $s 2>/dev/null; done");
        ((TextBlock)aiPanel.Children[0]).Text = "分析中…";
        var reply = await CallAiAsync($"以下是这台服务器的当前真实状态，请做健康巡检：按 资源水位 → 风险点 → 优化建议 给出诊断，发现异常用 ⚠️ 标注。\n\n{metrics}",
            delta => { ((TextBlock)aiPanel.Children[0]).Text = delta; AiScroll.ScrollToEnd(); });
        RenderAiReply(aiPanel, reply);
        AiScroll.ScrollToEnd();
    }

    /// 快捷追问点击 → 填入 AI 输入框（真实交互，对照 linux/apple/android）
    private void OnQuickAsk(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (sender is Button b && b.Content is string ask)
        {
            AiInput.Text = ask;
            AiInput.Focus();
        }
    }

    /// 命令输入回车 → 追加到终端输出（更深真实交互，对照 linux）
    private void OnCmdKeyDown(object? sender, KeyEventArgs e)
    {
        // ↑/↓ 键回溯命令历史（终端常用交互，对照 linux）
        if (e.Key == Key.Up && _cmdHistory.Count > 0)
        {
            _histIdx = System.Math.Min(_histIdx + 1, _cmdHistory.Count - 1);
            CmdInput.Text = _cmdHistory[_histIdx];
            CmdInput.CaretIndex = CmdInput.Text.Length;
            e.Handled = true;
            return;
        }
        if (e.Key == Key.Down && _histIdx >= 0)
        {
            _histIdx--;
            CmdInput.Text = _histIdx < 0 ? "" : _cmdHistory[_histIdx];
            CmdInput.CaretIndex = CmdInput.Text.Length;
            e.Handled = true;
            return;
        }
        if (e.Key != Key.Enter) return;
        var cmd = CmdInput.Text?.Trim();
        if (string.IsNullOrEmpty(cmd)) return;
        // 入历史（最近优先，去重）+ 持久化（重启可上下键回溯）
        _cmdHistory.Remove(cmd);
        _cmdHistory.Insert(0, cmd);
        _histIdx = -1;
        SaveConfig();
        // clear 清屏（对照 linux）：移除光标行外所有输出
        if (cmd == "clear")
        {
            while (TermOutput.Children.Count > 1) TermOutput.Children.RemoveAt(0);
            CmdInput.Text = "";
            return;
        }
        // 手输命令也真实 SSH 在服务器执行（复用 ExecuteCommand 真实 exec→结果回终端）
        CmdInput.Text = "";
        ExecuteCommand(cmd);
    }

    /// AI 输入回车 → 追加提问气泡（AI 区真实交互，对照 linux/终端）
    private void OnAiKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) AppendAiAsk();
    }

    /// AI 发送按钮点击 → 追加提问气泡
    private void OnAiSend(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => AppendAiAsk();

    /// 清空 AI 对话（新建会话）：清空消息 UI + 多轮历史 + 待执行命令
    private void OnClearChat(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        AiMessages.Children.Clear();
        _aiHistory.Clear();
        _autoLoopDepth = 0;
    }

    /// 导出当前 AI 对话为 Markdown（对照 apple ai-md），保存到桌面
    private async void OnExportChat(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (_aiHistory.Count == 0) { AppendAiBubble("暂无对话可导出", "#F59E0B"); return; }
        var sb = new StringBuilder();
        sb.AppendLine("# Termind AI 运维对话\n");
        foreach (var (role, content) in _aiHistory)
            sb.AppendLine($"## {(role == "user" ? "🧑 你" : "✦ AI")}\n\n{content}\n");
        var top = TopLevel.GetTopLevel(this);
        if (top?.StorageProvider == null) return;
        try
        {
            // StorageProvider 保存对话框（对照终端导出，让用户选保存位置）
            var file = await top.StorageProvider.SaveFilePickerAsync(new Avalonia.Platform.Storage.FilePickerSaveOptions
            {
                Title = "导出 AI 对话为 Markdown",
                SuggestedFileName = "termind-chat.md",
                DefaultExtension = "md",
            });
            if (file == null) return;
            await using var stream = await file.OpenWriteAsync();
            await using var writer = new System.IO.StreamWriter(stream);
            await writer.WriteAsync(sb.ToString());
            AppendAiBubble($"✓ 对话已导出到 {file.Name}", "#3FB950");
        }
        catch (System.Exception ex) { AppendAiBubble("导出失败：" + ex.Message, "#F85149"); }
    }

    // 真实 AI（S3）：HttpClient 调 Anthropic 兼容接口（nexcores）
    private static readonly HttpClient _http = new() { Timeout = System.TimeSpan.FromSeconds(60) };
    private const string AiBaseUrl = "https://www.nexcores.net/v1/messages";
    private const string AiModel = "claude-opus-4-8";
    // AI 多轮对话历史（role/content 累积，AI 记住上下文；为 Auto 闭环铺垫）
    // AI 多会话：每个会话一份历史，_aiHistory 指向当前会话（对照 apple ai-conv）
    private readonly List<List<(string role, string content)>> _sessions = new() { new() };
    private int _curSession = 0;
    private List<(string role, string content)> _aiHistory => _sessions[_curSession];

    /// 重渲染当前会话历史到 AiMessages（切换会话时调用）
    private void RenderSession()
    {
        AiMessages.Children.Clear();
        foreach (var (role, content) in _aiHistory)
        {
            if (role == "user")
            {
                AiMessages.Children.Add(new TextBlock { Text = "你", Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right });
                AiMessages.Children.Add(new Border { Background = Brush.Parse("#3B82F6"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right, MaxWidth = 260, Child = new TextBlock { Text = content, Foreground = Brush.Parse("#FFFFFF"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap } });
            }
            else
            {
                AiMessages.Children.Add(new Border { Background = Brush.Parse("#0D0E1A"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, MaxWidth = 290, Margin = new Thickness(0, 4, 0, 0), Child = new TextBlock { Text = content, Foreground = Brush.Parse("#C9D1D9"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap } });
            }
        }
        AiScroll.ScrollToEnd();
    }

    /// 会话面板打开：列所有会话（标题=首条提问）+ 新建按钮；点击切换、右键删除
    private void OnSessionsOpen(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        SessionsList.Children.Clear();
        for (int i = 0; i < _sessions.Count; i++)
        {
            var idx = i;
            var first = _sessions[i].FirstOrDefault(h => h.role == "user").content;
            var title = string.IsNullOrEmpty(first) ? $"新会话 {i + 1}" : (first.Length > 24 ? first[..24] + "…" : first);
            var cur = i == _curSession;
            var btn = new Button { Background = Brush.Parse(cur ? "#1AFF4B6E" : "#22FFFFFF"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(4), Padding = new Thickness(8, 5), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Left, Content = new TextBlock { Text = (cur ? "● " : "") + title, Foreground = Brush.Parse(cur ? "#FF4B6E" : "#C9D1D9"), FontSize = 12, TextTrimming = TextTrimming.CharacterEllipsis } };
            btn.Click += (_, _) => { _curSession = idx; RenderSession(); SaveSessions(); };
            if (_sessions.Count > 1)
            {
                var del = new MenuItem { Header = "删除此会话", Foreground = Brush.Parse("#F85149") };
                del.Click += (_, _) => { _sessions.RemoveAt(idx); if (_curSession >= _sessions.Count) _curSession = _sessions.Count - 1; RenderSession(); SaveSessions(); OnSessionsOpen(sender, e); };
                btn.ContextFlyout = new MenuFlyout { Items = { del } };
            }
            SessionsList.Children.Add(btn);
        }
        var add = new Button { Background = Brush.Parse("#1A3FB950"), Foreground = Brush.Parse("#3FB950"), BorderThickness = new Thickness(0), CornerRadius = new Avalonia.CornerRadius(4), Padding = new Thickness(8, 6), Margin = new Thickness(0, 4, 0, 0), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Center, Content = "+ 新建会话" };
        add.Click += (_, _) => { _sessions.Add(new()); _curSession = _sessions.Count - 1; RenderSession(); SaveSessions(); OnSessionsOpen(sender, e); };
        SessionsList.Children.Add(add);
    }

    /// 系统级运维提示词（优化 AI 智能运维能力，对齐 apple/android 护城河）
    private const string SysPrompt =
        "你是 Termind 的资深 Linux/SSH 服务器运维专家，精通系统排障、性能调优、安全加固、服务与进程管理、网络与防火墙。\n" +
        "工作原则：\n" +
        "1. 结合用户服务器的真实环境（系统版本/CPU/内存/磁盘/负载/运行中的服务）给出针对性建议，不空泛套话。\n" +
        "2. 给可直接执行的命令，用 ```bash 代码块；复杂操作分步骤并说明每步作用与预期输出。\n" +
        "3. 危险操作（删除/格式化/dd/重启或停服务/改 SSH 或防火墙/kill 进程/改权限）必须：⚠️ 标注风险等级（注意/高风险/极高危）+ 说明影响范围 + 建议先备份或快照。\n" +
        "4. 排障遵循：先诊断（看日志/服务状态/资源占用）→ 定位根因 → 给最小化修复 → 给验证恢复的方法。\n" +
        "5. 识别常见故障：502/Permission denied/磁盘满/端口占用/OOM/Nginx/SSL/MySQL 连接等，直接点出可能原因。\n" +
        "6. 回答精炼专业、用中文，不啰嗦。需在终端执行命令时可用 [EXECUTE]命令[/EXECUTE] 标记（供 Agent 模式自动执行）。";

    /// AI 三模式（安全梯度）：Chat 纯聊天 / Agent 每条确认 / Auto 全自动闭环
    private enum AiMode { Chat, Agent, Auto }
    private AiMode _aiMode = AiMode.Chat;

    private void OnModeChat(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetAiMode(AiMode.Chat);
    private void OnModeAgent(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetAiMode(AiMode.Agent);
    private void OnModeAuto(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetAiMode(AiMode.Auto);

    private void SetAiMode(AiMode mode)
    {
        _aiMode = mode;
        var on = Brush.Parse("#FF4B6E"); var onFg = Brush.Parse("#FFFFFF");
        var off = Brush.Parse("Transparent"); var offFg = Brush.Parse("#8B92A8");
        ModeChat.Background = mode == AiMode.Chat ? on : off; ModeChat.Foreground = mode == AiMode.Chat ? onFg : offFg;
        ModeAgent.Background = mode == AiMode.Agent ? on : off; ModeAgent.Foreground = mode == AiMode.Agent ? onFg : offFg;
        ModeAuto.Background = mode == AiMode.Auto ? on : off; ModeAuto.Foreground = mode == AiMode.Auto ? onFg : offFg;
    }

    private async void AppendAiAsk()
    {
        var ask = AiInput.Text?.Trim();
        if (string.IsNullOrEmpty(ask)) return;
        // 用户提问气泡（蓝，右对齐）
        var label = new TextBlock { Text = $"你 · {System.DateTime.Now:HH:mm}", Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right };
        var bubble = new Border
        {
            Background = Brush.Parse("#3B82F6"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right, MaxWidth = 260,
            Child = new TextBlock { Text = ask, Foreground = Brush.Parse("#FFFFFF"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap }
        };
        AiMessages.Children.Add(label);
        AiMessages.Children.Add(bubble);
        // AI 回复气泡（先显「思考中…」，真实回复后更新）
        var aiLabel = new TextBlock { Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left };
        aiLabel.Inlines!.Add(new Run("✦") { Foreground = Brush.Parse("#FF4B6E") });
        aiLabel.Inlines!.Add(new Run($" AI · {System.DateTime.Now:HH:mm}"));
        var aiPanel = new StackPanel { Spacing = 2 };
        aiPanel.Children.Add(new TextBlock { Text = "思考中…", Foreground = Brush.Parse("#C9D1D9"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap });
        var aiBubble = new Border
        {
            Background = Brush.Parse("#0D0E1A"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, MaxWidth = 290, Child = aiPanel
        };
        AiMessages.Children.Add(aiLabel);
        AiMessages.Children.Add(aiBubble);
        AiInput.Text = "";
        AiScroll.ScrollToEnd();
        // 真实 AI 流式调用（逐字更新气泡）→ 完成后解析代码块 + [EXECUTE]
        var streamText = (TextBlock)aiPanel.Children[0];
        var reply = await CallAiAsync(ask, delta =>
        {
            // 流式逐字显示（隐藏未闭合的 [EXECUTE] 标记尾部）
            streamText.Text = Regex.Replace(delta, @"\[EXECUTE\][\s\S]*$", "").TrimEnd();
            AiScroll.ScrollToEnd();
        });
        var cmds = Regex.Matches(reply, @"\[EXECUTE\]([\s\S]*?)\[/EXECUTE\]");
        // 渲染正文 + ```代码块（去 [EXECUTE] 标记）
        var text = Regex.Replace(reply, @"\[EXECUTE\][\s\S]*?\[/EXECUTE\]", "").Trim();
        if (text.Length == 0 && cmds.Count > 0) text = "建议执行以下命令：";
        RenderAiReply(aiPanel, text);
        SaveSessions();   // 一轮对话后持久化多会话
        // 每条 [EXECUTE] 命令 → 命令卡片（按 AI 模式：Chat 仅建议 / Agent 确认执行 / Auto 自动）
        foreach (Match m in cmds)
        {
            var cmd = m.Groups[1].Value.Trim();
            if (cmd.Length > 0) AddCommandCard(cmd);
        }
        AiScroll.ScrollToEnd();
    }

    /// 渲染 AI 回复：```代码块→等宽深色代码框，其余→正文（Markdown 轻量）
    private void RenderAiReply(StackPanel panel, string text)
    {
        panel.Children.Clear();
        var parts = text.Split(new[] { "```" }, System.StringSplitOptions.None);
        for (int i = 0; i < parts.Length; i++)
        {
            var seg = parts[i];
            if (i % 2 == 1)
            {
                // 代码块：去首行语言标识
                var lines = seg.Split('\n');
                var code = (lines.Length > 1 && lines[0].Trim().Length < 12 && !lines[0].Contains(' '))
                    ? string.Join("\n", lines[1..]) : seg;
                code = code.Trim('\n', ' ');
                if (code.Length == 0) continue;
                // 代码块即命令：点击/右键插入命令框（运维一键执行 AI 给的命令，AI 交互增强）
                var codeBlock = new Border
                {
                    Background = Brush.Parse("#05060C"), CornerRadius = new CornerRadius(6),
                    Padding = new Thickness(10, 8), Margin = new Thickness(0, 4, 0, 4),
                    Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
                    Child = new TextBlock
                    {
                        Text = code, Foreground = Brush.Parse("#3FB950"),
                        FontFamily = (FontFamily)(this.FindResource("MonoFont") ?? FontFamily.Default),
                        FontSize = 12, TextWrapping = TextWrapping.Wrap
                    }
                };
                var firstLine = code.Split('\n')[0];
                codeBlock.PointerPressed += (_, _) => { CmdInput.Text = firstLine; CmdInput.Focus(); };
                var insMi = new MenuItem { Header = "插入到命令框", Foreground = Brush.Parse("#3FB950") };
                insMi.Click += (_, _) => { CmdInput.Text = firstLine; CmdInput.Focus(); };
                codeBlock.ContextFlyout = new MenuFlyout { Items = { insMi } };
                ToolTip.SetTip(codeBlock, "点击插入命令框 · 右键菜单");
                panel.Children.Add(codeBlock);
            }
            else
            {
                var body = seg.Trim('\n', ' ');
                if (body.Length == 0) continue;
                panel.Children.Add(new TextBlock { Text = body, Foreground = Brush.Parse("#C9D1D9"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap });
            }
        }
        if (panel.Children.Count == 0)
            panel.Children.Add(new TextBlock { Text = text, Foreground = Brush.Parse("#C9D1D9"), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap });
    }

    /// 命令风险四级分级（对照 apple CommandRisk Z7）：安全/注意/高风险/极高危
    private enum RiskLevel { Safe = 0, Notice = 1, High = 2, Critical = 3 }

    private static RiskLevel CommandRiskOf(string cmd)
    {
        var c = cmd.ToLowerInvariant();
        // 极高危：删除/格式化/关 SSH/清防火墙/关机等不可逆或致命
        if (c.Contains("rm -rf") || c.Contains("rm -fr") || c.Contains(":(){") || c.Contains("mkfs")
            || c.Contains("dd if=") || c.Contains("> /dev/") || c.Contains("shutdown") || c.Contains("reboot")
            || c.Contains("halt") || c.Contains("init 0") || c.Contains("systemctl stop ssh") || c.Contains("iptables -f")
            || c.Contains("ufw disable") || c.Contains("wipefs") || c.Contains("drop database") || c.Contains("> /etc/"))
            return RiskLevel.Critical;
        // 高风险：重启/重载服务、改权限递归、改防火墙、kill、删容器/卸载
        if (c.Contains("systemctl restart") || c.Contains("systemctl reload") || c.Contains("systemctl stop")
            || c.Contains("systemctl start") || c.StartsWith("service ") || c.Contains("nginx -s")
            || c.Contains("ufw ") || c.Contains("iptables ") || c.Contains("firewall-cmd") || c.Contains("chown -r")
            || c.Contains("chmod -r") || c.Contains("chmod 777") || c.StartsWith("kill ") || c.Contains("killall")
            || c.Contains("pkill") || c.Contains("docker rm") || c.Contains("docker stop") || c.Contains("apt remove")
            || c.Contains("apt purge") || c.Contains("yum remove") || c.Contains("userdel"))
            return RiskLevel.High;
        // 注意：改单文件/编辑/移动/安装
        if (c.StartsWith("vim ") || c.StartsWith("vi ") || c.StartsWith("nano ") || c.Contains("sed -i")
            || c.StartsWith("cp ") || c.StartsWith("mv ") || c.Contains("chmod ") || c.Contains("chown ")
            || c.StartsWith("mkdir ") || c.StartsWith("touch ") || c.Contains("apt install") || c.Contains("yum install")
            || c.Contains("pip install") || c.Contains("npm install") || c.Contains("git push") || c.Contains("git reset")
            || c.Contains("docker run"))
            return RiskLevel.Notice;
        return RiskLevel.Safe;
    }

    private static (string label, string color) RiskStyle(RiskLevel r) => r switch
    {
        RiskLevel.Critical => ("极高危", "#E74C3C"),
        RiskLevel.High => ("高风险", "#E67E22"),
        RiskLevel.Notice => ("注意", "#F39C12"),
        _ => ("", "#3FB950"),
    };

    /// 危险命令检测：高/极高即危险（Auto 也不自动执行，强制确认；委托四级分级）
    private static bool IsDangerous(string cmd) => CommandRiskOf(cmd) >= RiskLevel.High;

    /// AI 回复里的命令 → 可执行卡片（Chat=建议+复制 / Agent=▶执行确认 / Auto=自动执行）
    private void AddCommandCard(string cmd)
    {
        var risk = CommandRiskOf(cmd);
        var danger = risk >= RiskLevel.High;
        var (riskLabel, riskColor) = RiskStyle(risk);
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto") };
        var cmdText = new TextBlock
        {
            // 风险级别前缀（注意/高风险/极高危 + ⚠），按四级配色（对照 apple）
            Text = (riskLabel.Length > 0 ? $"[{riskLabel}] " : "") + cmd, Foreground = Brush.Parse(riskColor),
            FontFamily = (FontFamily)(this.FindResource("MonoFont") ?? FontFamily.Default),
            FontSize = 12, TextWrapping = TextWrapping.Wrap, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
        };
        Grid.SetColumn(cmdText, 0);
        grid.Children.Add(cmdText);
        // 「填入终端」按钮（始终显示，AI 命令一键填入终端输入框，可编辑后手动执行）
        var fillBtn = new Button
        {
            Background = Brush.Parse("#16182A"), BorderThickness = new Thickness(0), CornerRadius = new CornerRadius(6),
            Padding = new Thickness(7, 3), FontSize = 11, Margin = new Thickness(8, 0, 0, 0),
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center, Content = "填入终端", Foreground = Brush.Parse("#8B92A8")
        };
        fillBtn.Click += (_, _) => { CmdInput.Text = cmd; CmdInput.Focus(); CmdInput.CaretIndex = cmd.Length; };
        Grid.SetColumn(fillBtn, 1);
        grid.Children.Add(fillBtn);
        // Agent/Auto 模式显示执行按钮（Chat 模式仅建议不执行）
        if (_aiMode != AiMode.Chat)
        {
            var btn = new Button
            {
                Content = _aiMode == AiMode.Auto && !danger ? "自动执行中…" : "▶ 执行",
                Background = Brush.Parse("#FF4B6E"), Foreground = Brush.Parse("#FFFFFF"),
                BorderThickness = new Thickness(0), CornerRadius = new CornerRadius(6),
                Padding = new Thickness(8, 3), FontSize = 11, Margin = new Thickness(6, 0, 0, 0),
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
            };
            btn.Click += (_, _) => ExecuteCommand(cmd);
            Grid.SetColumn(btn, 2);
            grid.Children.Add(btn);
        }
        var card = new Border
        {
            Background = Brush.Parse("#0A0B14"), CornerRadius = new CornerRadius(8), Padding = new Thickness(10, 8),
            Margin = new Thickness(0, 2, 0, 0), HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left,
            MaxWidth = 300, Child = grid
        };
        AiMessages.Children.Add(card);
        // Auto 模式：非危险命令自动执行；危险命令即使 Auto 也需点「▶ 执行」确认（安全铁律）
        if (_aiMode == AiMode.Auto && !danger) ExecuteCommand(cmd);
    }

    private int _autoLoopDepth = 0;   // Auto 自主闭环轮数（防失控）
    private const int AutoLoopMax = 5;

    /// 执行命令（Agent 确认放行 / Auto 自动）：真实 SSH 在服务器执行 + 结果追加终端（S1 闭环）
    /// Auto 模式：执行结果自动回喂 AI → AI 决策下一步命令（agent loop，限轮+危险中断防失控）
    private async void ExecuteCommand(string cmd)
    {
        // 目标主机优先级：选中连接 > 环境变量 > 默认测试机
        var host = _activeHost ?? System.Environment.GetEnvironmentVariable("TERMIND_SSH_HOST") ?? "47.85.19.31";
        var user = _activeUser ?? System.Environment.GetEnvironmentVariable("TERMIND_SSH_USER") ?? "root";
        AppendTerm($"{user}@{host}:~$ {cmd}", "#C9D1D9");
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var result = await SshExecAsync(cmd);
        sw.Stop();
        foreach (var line in result.Split('\n'))
            AppendTerm(line.TrimEnd(), result.StartsWith("⚠") ? "#F59E0B" : "#A0A0A0");
        // 执行耗时提示（运维参考：命令慢可能是资源/网络问题）
        var ok = !result.StartsWith("⚠");
        AppendTerm($"{(ok ? "✓" : "✕")} 耗时 {sw.ElapsedMilliseconds}ms", ok ? "#6B7280" : "#F59E0B");

        // S5 Auto 自主闭环：把执行结果回喂 AI，让 AI 决策下一步（限轮防失控）
        if (_aiMode == AiMode.Auto && !result.StartsWith("⚠") && _autoLoopDepth < AutoLoopMax)
        {
            _autoLoopDepth++;
            var feedback = $"已执行命令 `{cmd}`，输出如下：\n{result}\n\n请判断是否需要下一步操作。如需继续，用 [EXECUTE]命令[/EXECUTE]；如已完成，直接说明结论，不要再给命令。";
            AppendAiBubble("✦ AI（自主分析执行结果…）", "#6B7280");
            var reply = await CallAiAsync(feedback);
            AppendAiBubble(Regex.Replace(reply, @"\[EXECUTE\][\s\S]*?\[/EXECUTE\]", "").Trim(), "#C9D1D9");
            foreach (Match m in Regex.Matches(reply, @"\[EXECUTE\]([\s\S]*?)\[/EXECUTE\]"))
            {
                var next = m.Groups[1].Value.Trim();
                if (next.Length > 0) AddCommandCard(next);   // Auto 模式 AddCommandCard 内会自动执行（危险则停）
            }
        }
        else { _autoLoopDepth = 0; }   // 非 Auto/出错/到顶 → 重置轮数
    }

    /// 追加一条 AI 气泡（Auto 闭环自主分析用）
    private void AppendAiBubble(string text, string color)
    {
        var bubble = new Border
        {
            Background = Brush.Parse("#0D0E1A"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, MaxWidth = 290,
            Margin = new Thickness(0, 4, 0, 0),
            Child = new TextBlock { Text = text, Foreground = Brush.Parse(color), FontSize = _aiFontSize, TextWrapping = TextWrapping.Wrap }
        };
        AiMessages.Children.Add(bubble);
        AiScroll.ScrollToEnd();
    }

    /// 追加一行到终端输出（插入光标行前）
    // ANSI SGR 前景色 → hex（30-37 标准 / 90-97 亮色，对照常见终端配色）
    private static readonly Dictionary<int, string> AnsiFg = new()
    {
        [30] = "#6B7280", [31] = "#F87171", [32] = "#3FB950", [33] = "#F59E0B", [34] = "#60A5FA", [35] = "#C084FC", [36] = "#22D3EE", [37] = "#C9D1D9",
        [90] = "#8B92A8", [91] = "#FCA5A5", [92] = "#86EFAC", [93] = "#FCD34D", [94] = "#93C5FD", [95] = "#D8B4FE", [96] = "#67E8F9", [97] = "#FFFFFF",
    };

    private double _termFontSize = 12.5;   // 终端字号（U4 可调）
    private double _aiFontSize = 13;       // AI 对话字号（U4 可调）

    /// AI 对话字号 +/-（U4）：调整后更新所有 AI 气泡文本 + 新气泡用新字号 + 持久化
    private void OnAiFontSmaller(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetAiFont(_aiFontSize - 1);
    private void OnAiFontLarger(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetAiFont(_aiFontSize + 1);
    private void SetAiFont(double size)
    {
        _aiFontSize = System.Math.Clamp(size, 10, 22);
        foreach (var child in AiMessages.Children)
        {
            if (child is TextBlock tb && tb.FontSize >= 12) tb.FontSize = _aiFontSize;   // 气泡正文（跳过小号角色标签）
            else if (child is Border b && b.Child is TextBlock t) t.FontSize = _aiFontSize;
            else if (child is Border bp && bp.Child is StackPanel sp)
                foreach (var c in sp.Children) if (c is TextBlock st) st.FontSize = _aiFontSize;
        }
        SaveConfig();
    }

    /// 终端字号 +/-（U4 用户要求）：调整后更新所有现有终端行 + 新行用新字号
    private void OnFontSmaller(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetTermFont(_termFontSize - 1);
    private void OnFontLarger(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => SetTermFont(_termFontSize + 1);
    private void SetTermFont(double size)
    {
        _termFontSize = System.Math.Clamp(size, 9, 22);
        foreach (var child in TermOutput.Children)
            if (child is TextBlock tb) tb.FontSize = _termFontSize;
        SaveConfig();   // 字号持久化（重启恢复）
    }

    private void AppendTerm(string text, string color)
    {
        var line = new TextBlock
        {
            FontFamily = (FontFamily)(this.FindResource("MonoFont") ?? FontFamily.Default),
            FontSize = _termFontSize, Margin = new Thickness(0, 1, 0, 0), TextWrapping = TextWrapping.Wrap
        };
        // 解析 ANSI SGR 转义（\x1b[..m）分段着色；无转义则整段默认色
        if (text.Contains('\x1b'))
        {
            var cur = color;
            bool bold = false;
            foreach (var seg in Regex.Split(text, @"(\x1b\[[0-9;]*m)"))
            {
                if (seg.Length == 0) continue;
                var m = Regex.Match(seg, @"^\x1b\[([0-9;]*)m$");
                if (m.Success)
                {
                    foreach (var codeStr in m.Groups[1].Value.Split(';'))
                    {
                        if (!int.TryParse(codeStr, out var code)) { cur = color; bold = false; continue; }
                        if (code == 0) { cur = color; bold = false; }
                        else if (code == 1) bold = true;
                        else if (AnsiFg.TryGetValue(code, out var hex)) cur = hex;
                    }
                    continue;
                }
                line.Inlines!.Add(new Run(seg) { Foreground = Brush.Parse(cur), FontWeight = bold ? FontWeight.Bold : FontWeight.Normal });
            }
        }
        else { line.Text = text; line.Foreground = Brush.Parse(color); }
        TermOutput.Children.Insert(TermOutput.Children.Count - 1, line);
        TermScroll.ScrollToEnd();
    }

    private string? _envCache;   // 服务器环境摘要缓存（首次提问取一次）

    /// Z3 环境感知：SSH 取服务器系统/资源/服务摘要（缓存，密码缺省时返回空跳过）
    private async Task<string> FetchServerEnvAsync()
    {
        if (_envCache != null) return _envCache;
        if (string.IsNullOrEmpty(System.Environment.GetEnvironmentVariable("TERMIND_SSH_PASS"))) return "";
        var probe = "echo 系统:$(uname -sr); echo CPU核数:$(nproc); " +
            "echo 内存:$(free -m 2>/dev/null|awk '/Mem:/{print $3\"/\"$2\"MB\"}'); " +
            "echo 负载:$(cat /proc/loadavg|cut -d' ' -f1-3); " +
            "echo 磁盘:$(df -h / 2>/dev/null|awk 'NR==2{print $5\" 已用\"}'); " +
            "echo 服务:$(for s in nginx docker mysql redis sshd; do systemctl is-active $s 2>/dev/null|grep -q active && echo -n \"$s \"; done)";
        var env = await SshExecAsync(probe);
        _envCache = env.StartsWith("⚠") ? "" : env;
        return _envCache;
    }

    private Renci.SshNet.SshClient? _sshClient;   // 复用的持久 SSH 会话（避免每次 exec 重连）
    private readonly object _sshLock = new();

    /// 真实 SSH exec（S1：连真实服务器，SSH.NET）；密码从环境变量 TERMIND_SSH_PASS（不硬编码）
    /// 复用持久 Session：连接+握手+认证只在首次或断线后做，多命令/Auto 闭环显著提速
    private async Task<string> SshExecAsync(string cmd)
    {
        // 目标主机优先级：选中连接 > 环境变量 > 默认测试机
        var host = _activeHost ?? System.Environment.GetEnvironmentVariable("TERMIND_SSH_HOST") ?? "47.85.19.31";
        var user = _activeUser ?? System.Environment.GetEnvironmentVariable("TERMIND_SSH_USER") ?? "root";
        var pass = System.Environment.GetEnvironmentVariable("TERMIND_SSH_PASS") ?? "";
        if (string.IsNullOrEmpty(pass)) return "⚠️ 未配置 SSH 密码（环境变量 TERMIND_SSH_PASS）";
        return await Task.Run(() =>
        {
            lock (_sshLock)
            {
                try
                {
                    // 未连接或已断线 → 建立/重建会话（断线重连）
                    if (_sshClient == null || !_sshClient.IsConnected)
                    {
                        _sshClient?.Dispose();
                        _sshClient = new Renci.SshNet.SshClient(host, 22, user, pass);
                        _sshClient.Connect();
                    }
                    using var c = _sshClient.RunCommand(cmd);
                    var outp = c.Result ?? "";
                    if (!string.IsNullOrEmpty(c.Error)) outp += c.Error;
                    return outp.Length == 0 ? "(无输出)" : outp.TrimEnd();
                }
                catch (System.Exception ex)
                {
                    _sshClient?.Dispose(); _sshClient = null;   // 重置以便下次干净重连
                    return "⚠️ SSH 失败：" + ex.Message;
                }
            }
        });
    }

    /// 调 Anthropic 兼容接口（nexcores）；key 从环境变量 TERMIND_AI_KEY 读（不硬编码）
    /// Z3 环境感知：提问前先 SSH 取服务器真实状态注入系统提示，AI 结合真实环境回答
    private async Task<string> CallAiAsync(string userMsg, System.Action<string>? onDelta = null)
    {
        // 配置优先级：设置面板填入 > 环境变量（设置面板填了即生效，便于 UI 配置）
        var key = !string.IsNullOrWhiteSpace(ApiKeyBox?.Text) ? ApiKeyBox.Text.Trim()
            : (System.Environment.GetEnvironmentVariable("TERMIND_AI_KEY") ?? "");
        if (string.IsNullOrEmpty(key)) return "⚠️ 未配置 API Key（在设置面板填入，或设 TERMIND_AI_KEY 环境变量）";
        var baseUrl = !string.IsNullOrWhiteSpace(BaseUrlBox?.Text) ? BaseUrlBox.Text.Trim() : AiBaseUrl;
        // 取服务器真实环境摘要（一次 SSH 拿系统/资源/服务），注入系统提示
        var env = await FetchServerEnvAsync();
        var sys = string.IsNullOrEmpty(env) ? SysPrompt
            : SysPrompt + "\n\n【当前服务器真实环境】\n" + env + "\n请结合以上真实环境给出针对性建议。";
        // 多轮：累积本次提问到历史，整段历史发给 AI（AI 记住上下文）
        _aiHistory.Add(("user", userMsg));
        try
        {
            // 流式输出（stream=true，SSE 逐块解析 content_block_delta，逐字更新 UI）
            var payload = new
            {
                model = AiModel,
                max_tokens = 1024,
                stream = true,
                system = sys,
                messages = _aiHistory.Select(h => new { role = h.role, content = h.content }).ToArray()
            };
            using var req = new HttpRequestMessage(HttpMethod.Post, baseUrl);
            req.Headers.Add("x-api-key", key);
            req.Headers.Add("anthropic-version", "2023-06-01");
            req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
            using var resp = await _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead);
            using var stream = await resp.Content.ReadAsStreamAsync();
            using var reader = new System.IO.StreamReader(stream);
            var sb = new StringBuilder();
            string? line;
            while ((line = await reader.ReadLineAsync()) != null)
            {
                if (!line.StartsWith("data:")) continue;
                var data = line.Substring(5).Trim();
                if (data.Length == 0 || data == "[DONE]") continue;
                try
                {
                    using var doc = JsonDocument.Parse(data);
                    var type = doc.RootElement.TryGetProperty("type", out var t) ? t.GetString() : "";
                    if (type == "content_block_delta"
                        && doc.RootElement.TryGetProperty("delta", out var d)
                        && d.TryGetProperty("text", out var txt))
                    {
                        sb.Append(txt.GetString());
                        onDelta?.Invoke(sb.ToString());   // 逐字更新 UI（已在 UI 上下文）
                    }
                    else if (type == "error" && doc.RootElement.TryGetProperty("error", out var e)
                        && e.TryGetProperty("message", out var em))
                        return "⚠️ " + em.GetString();
                }
                catch { /* 跳过非 JSON 心跳行 */ }
            }
            var full = sb.Length == 0 ? "(无回复)" : sb.ToString();
            _aiHistory.Add(("assistant", full));   // AI 回复入历史，下轮带上下文
            if (_aiHistory.Count > 20) _aiHistory.RemoveRange(0, 2);  // 限长防膨胀
            return full;
        }
        catch (System.Exception ex) { return "⚠️ 请求失败：" + ex.Message; }
    }
}
