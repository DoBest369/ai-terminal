using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Controls.Documents;
using Avalonia.Threading;
using System.Collections.Generic;
using System.ComponentModel;
using System.Net.Sockets;
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

    public MainWindow()
    {
        InitializeComponent();
        var green = Brush.Parse("#3FB950");
        var gray = Brush.Parse("#6B7280");
        // 连接列表（分组聚合 + 备注 + 可达 + 最近使用；初始可达=⏳探测中，TCP 探测完更新）
        ConnList.ItemsSource = new List<ConnItem>
        {
            new("数据库主机", "admin@db.internal.net:22", Brush.Parse("#3B82F6"), gray, "生产环境", true, "⏳", gray, "📝 MySQL 主库", true, "上次使用 · 5 分钟前", true),
            new("生产服务器", "root@192.168.1.10:22", Brush.Parse("#EF4444"), gray, "生产环境", false, "⏳", gray, "📝 官网 + API", true, "上次使用 · 1 小时前", true),
            new("开发机", "deploy@dev.example.com:2222", gray, gray, "开发环境", true, "⏳", gray, "", false, "", false),
        };
        ConnList.SelectedIndex = 0;
        // 真实 TCP 可达性探测（对照 linux probe_tcp）：异步探测每个连接，结果回 UI 线程更新
        foreach (var item in (List<ConnItem>)ConnList.ItemsSource)
            _ = ProbeReachabilityAsync(item);
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

    /// 连接列表选中变化 → 终端区状态条反映选中连接（真实交互，对照 linux）
    private void OnConnSelected(object? sender, SelectionChangedEventArgs e)
    {
        if (ConnList.SelectedItem is not ConnItem c) return;
        // 地址形如 user@host:port → 取 host 段
        var host = c.Addr;
        var at = host.IndexOf('@'); if (at >= 0) host = host[(at + 1)..];
        var colon = host.IndexOf(':'); if (colon >= 0) host = host[..colon];
        var online = c.Reach == "✓";
        StatusHost.Text = $"主机 {host}";
        StatusDot.Text = online ? "● 已连接" : "○ 离线";
        StatusDot.Foreground = online ? Brush.Parse("#3FB950") : Brush.Parse("#6B7280");
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
        // 入历史（最近优先，去重）
        _cmdHistory.Remove(cmd);
        _cmdHistory.Insert(0, cmd);
        _histIdx = -1;
        // clear 清屏（对照 linux）：移除光标行外所有输出
        if (cmd == "clear")
        {
            while (TermOutput.Children.Count > 1) TermOutput.Children.RemoveAt(0);
            CmdInput.Text = "";
            return;
        }
        var host = StatusHost.Text?.Replace("主机 ", "") ?? "prod-01";
        var line = new TextBlock
        {
            Text = $"root@{host}:~$ {cmd}",
            Foreground = Brush.Parse("#C9D1D9"),
            FontFamily = new FontFamily("Consolas"),
            FontSize = 12.5,
            Margin = new Thickness(0, 4, 0, 0)
        };
        // 插入到光标行（最后一项）之前
        TermOutput.Children.Insert(TermOutput.Children.Count - 1, line);
        CmdInput.Text = "";
        TermScroll.ScrollToEnd();
    }

    /// AI 输入回车 → 追加提问气泡（AI 区真实交互，对照 linux/终端）
    private void OnAiKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) AppendAiAsk();
    }

    /// AI 发送按钮点击 → 追加提问气泡
    private void OnAiSend(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => AppendAiAsk();

    private void AppendAiAsk()
    {
        var ask = AiInput.Text?.Trim();
        if (string.IsNullOrEmpty(ask)) return;
        // 角色标签「你」（右对齐）
        var label = new TextBlock { Text = "你", Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right };
        // 提问气泡（蓝，右对齐）
        var bubble = new Border
        {
            Background = Brush.Parse("#3B82F6"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right, MaxWidth = 260,
            Child = new TextBlock { Text = ask, Foreground = Brush.Parse("#FFFFFF"), FontSize = 13, TextWrapping = TextWrapping.Wrap }
        };
        AiMessages.Children.Add(label);
        AiMessages.Children.Add(bubble);
        // 占位 AI 回复（✦ AI 标签 + 灰气泡，后续接真实 AI 流式回复，对照 linux）
        var aiLabel = new TextBlock { Foreground = Brush.Parse("#8B92A8"), FontSize = 10, FontWeight = FontWeight.Bold, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left };
        aiLabel.Inlines!.Add(new Run("✦") { Foreground = Brush.Parse("#FF4B6E") });
        aiLabel.Inlines!.Add(new Run(" AI"));
        var aiBubble = new Border
        {
            Background = Brush.Parse("#0D0E1A"), CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, MaxWidth = 290,
            Child = new TextBlock { Text = "已收到，正在结合服务器环境分析…（接入 API Key 后回复）", Foreground = Brush.Parse("#C9D1D9"), FontSize = 13, TextWrapping = TextWrapping.Wrap }
        };
        AiMessages.Children.Add(aiLabel);
        AiMessages.Children.Add(aiBubble);
        AiInput.Text = "";
        AiScroll.ScrollToEnd();
    }
}
