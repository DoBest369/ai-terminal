using Avalonia.Controls;
using Avalonia.Media;
using System.Collections.Generic;

namespace TermindWindows;

/// 一条 SSH 连接（占位；后续接真实连接数据 + ssh）
/// Bar=分组色条，Dot=在线状态点
public record ConnItem(string Name, string Addr, IBrush Bar, IBrush Dot);

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        // 连接列表（ListBox 自带选中高亮 / hover / 键盘上下导航）
        ConnList.ItemsSource = new List<ConnItem>
        {
            new("开发机", "deploy@dev.example.com:2222", Brush.Parse("#3FB950"), Brush.Parse("#3FB950")),
            new("数据库主机", "admin@db.internal.net:22", Brush.Parse("#3B82F6"), Brush.Parse("#3FB950")),
            new("生产服务器", "root@192.168.1.10:22", Brush.Parse("#EF4444"), Brush.Parse("#6B7280")),
        };
        ConnList.SelectedIndex = 1;
    }
}
