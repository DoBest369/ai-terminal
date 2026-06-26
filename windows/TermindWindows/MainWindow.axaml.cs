using Avalonia.Controls;
using Avalonia.Media;
using System.Collections.Generic;

namespace TermindWindows;

/// 一条 SSH 连接（占位；后续接真实连接数据 + ssh）
/// Bar=分组色条，Dot=在线状态点，GroupName/ShowHeader=分组标题，Reach/ReachColor=可达指示
public record ConnItem(string Name, string Addr, IBrush Bar, IBrush Dot, string GroupName, bool ShowHeader, string Reach, IBrush ReachColor);

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        var green = Brush.Parse("#3FB950");
        var gray = Brush.Parse("#6B7280");
        // 连接列表（按分组聚合，组内第一个显分组标题；可达指示 ✓/✕；ListBox 自带选中/hover/键盘导航）
        ConnList.ItemsSource = new List<ConnItem>
        {
            new("数据库主机", "admin@db.internal.net:22", Brush.Parse("#3B82F6"), green, "生产环境", true, "✓", green),
            new("生产服务器", "root@192.168.1.10:22", Brush.Parse("#EF4444"), gray, "生产环境", false, "✕", gray),
            new("开发机", "deploy@dev.example.com:2222", green, green, "开发环境", true, "✓", green),
        };
        ConnList.SelectedIndex = 0;
    }
}
