using Avalonia;
using System;
using System.Threading.Tasks;

namespace TermindWindows;

class Program
{
    // Initialization code. Don't use any Avalonia, third-party APIs or any
    // SynchronizationContext-reliant code before AppMain is called: things aren't initialized
    // yet and stuff might break.
    [STAThread]
    public static void Main(string[] args)
    {
        // 全局兜底：后台任务/未观察异常不得使进程 abort（修 dotnet run 崩溃隐患）
        TaskScheduler.UnobservedTaskException += (_, e) => e.SetObserved();
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            Console.Error.WriteLine($"[未处理异常] {(e.ExceptionObject as Exception)?.Message}");
        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    // Avalonia configuration, don't remove; also used by visual designer.
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
#if DEBUG
            .WithDeveloperTools()
#endif
            .WithInterFont()
            .LogToTrace();
}
