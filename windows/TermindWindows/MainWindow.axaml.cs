using Avalonia.Controls;
using Avalonia.Media;
using System.Collections.Generic;

namespace TermindWindows;

/// 一条 SSH 连接（占位；后续接真实连接数据 + ssh）
/// Bar=分组色条，Dot=在线状态点，GroupName/ShowHeader=分组标题（组内第一个显示）
public record ConnItem(string Name, string Addr, IBrush Bar, IBrush Dot, string GroupName, bool ShowHeader);

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        // 连接列表（按分组聚合，组内第一个显分组标题；ListBox 自带选中/hover/键盘导航）
        ConnList.ItemsSource = new List<ConnItem>
        {
            new("数据库主机", "admin@db.internal.net:22", Brush.Parse("#3B82F6"), Brush.Parse("#3FB950"), "生产环境", true),
            new("生产服务器", "root@192.168.1.10:22", Brush.Parse("#EF4444"), Brush.Parse("#6B7280"), "生产环境", false),
            new("开发机", "deploy@dev.example.com:2222", Brush.Parse("#3FB950"), Brush.Parse("#3FB950"), "开发环境", true),
        };
        ConnList.SelectedIndex = 0;
    }
}
