using Avalonia.Controls;
using Avalonia.Media;
using System.Collections.Generic;

namespace TermindWindows;

/// 一条 SSH 连接（占位；后续接真实连接数据 + ssh）
/// Bar=分组色条，Dot=在线状态点，GroupName/ShowHeader=分组标题，Reach/ReachColor=可达指示，
/// Note/HasNote=备注，LastUsed/HasLastUsed=最近使用
public record ConnItem(string Name, string Addr, IBrush Bar, IBrush Dot, string GroupName, bool ShowHeader,
    string Reach, IBrush ReachColor, string Note, bool HasNote, string LastUsed, bool HasLastUsed);

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        var green = Brush.Parse("#3FB950");
        var gray = Brush.Parse("#6B7280");
        // 连接列表（分组聚合 + 备注 + 可达 + 最近使用；ListBox 自带选中/hover/键盘导航）
        ConnList.ItemsSource = new List<ConnItem>
        {
            new("数据库主机", "admin@db.internal.net:22", Brush.Parse("#3B82F6"), green, "生产环境", true, "✓", green, "📝 MySQL 主库", true, "上次使用 · 5 分钟前", true),
            new("生产服务器", "root@192.168.1.10:22", Brush.Parse("#EF4444"), gray, "生产环境", false, "✕", gray, "📝 官网 + API", true, "上次使用 · 1 小时前", true),
            new("开发机", "deploy@dev.example.com:2222", green, green, "开发环境", true, "✓", green, "", false, "", false),
        };
        ConnList.SelectedIndex = 0;
    }
}
