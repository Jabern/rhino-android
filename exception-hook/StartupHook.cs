// .NET startup hook: logs every first-chance exception with the full call
// stack. Enable with DOTNET_STARTUP_HOOKS=<path to this dll>; the log goes to
// RHINO_EXCEPTION_LOG (default C:\rhino-exceptions.log).
// Built against mscorlib with Wine Mono's mcs; .NET (Core) loads it through
// its mscorlib facade.
using System;
using System.IO;

internal class StartupHook
{
    [ThreadStatic] static bool busy;

    public static void Initialize()
    {
        string path = Environment.GetEnvironmentVariable("RHINO_EXCEPTION_LOG");
        if (string.IsNullOrEmpty(path)) path = @"C:\rhino-exceptions.log";
        File.AppendAllText(path, DateTime.Now.ToString("HH:mm:ss.fff") + " hook loaded\n");
        AppDomain.CurrentDomain.FirstChanceException += (sender, e) =>
        {
            if (busy) return;
            busy = true;
            try
            {
                File.AppendAllText(path, DateTime.Now.ToString("HH:mm:ss.fff") + " [thread " +
                    Environment.CurrentManagedThreadId + "] " + e.Exception.GetType().FullName + ": " +
                    e.Exception.Message + "\n" + Environment.StackTrace + "\n---\n");
            }
            catch { }
            finally { busy = false; }
        };
    }
}
