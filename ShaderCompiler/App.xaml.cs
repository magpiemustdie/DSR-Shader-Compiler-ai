using System;
using System.Windows;
using System.IO;
using System.Linq;
using System.Diagnostics;

namespace ShaderCompiler
{
    public partial class App : Application
    {
        [STAThread]
        protected override void OnStartup(StartupEventArgs e)
        {
            // Console mode: ShaderCompiler.exe -build [-target:xxx] [-inc]
            if (e.Args.Any(a => a.Equals("-build", StringComparison.OrdinalIgnoreCase) ||
                                a.StartsWith("-target:", StringComparison.OrdinalIgnoreCase)))
            {
                string target = null;
                bool inc = e.Args.Any(a => a.Equals("-inc", StringComparison.OrdinalIgnoreCase));
                foreach (var a in e.Args)
                {
                    if (a.StartsWith("-target:", StringComparison.OrdinalIgnoreCase))
                        target = a.Substring(8).ToLower();
                    else if (!a.StartsWith("-"))
                        target = a.ToLower();          // positional target: build.cmd snow
                }
                int errors = RunConsoleBuild(target ?? "all", inc);
                Environment.Exit(errors == 0 ? 0 : 1);
                return;
            }

            // GUI mode — show MainWindow manually
            var win = new MainWindow();
            win.Show();
        }

        static int RunConsoleBuild(string target, bool inc)
        {
            var sw = Stopwatch.StartNew();
            string root = FindProjectRoot(AppContext.BaseDirectory);
            string dsr = @"D:\DarkSoulsRemastered";
            string fxc = Path.Combine(root, "tools", "fxc_81", "fxc.exe");
            string source = Path.Combine(root, "source");

            var builder = new ShaderBuilder(dsr, fxc, source, force: !inc,
                                            System.Threading.CancellationToken.None);

            switch (target)
            {
                case "flver": builder.BuildFlverPBL(); break;
                case "flver-vs": builder.BuildFlverPBLVS(); break;
                case "snow": builder.BuildSnow(); break;
                case "snow-vs": builder.BuildSnowVS(); break;
                case "filter": builder.BuildFilter(); break;
                case "menu": builder.BuildMenu(); break;
                case "sfxpbl": builder.BuildSfxPBL(); break;
                case "deferred": builder.BuildDeferred(); break;
                case "dbgfont": builder.BuildDbgFont(); break;
                case "everything":
                case "buildall":
                    builder.BuildAll();
                    builder.BuildArchivesFromStructure();
                    break;
                case "all":
                    builder.BuildFlverPBL();
                    builder.BuildFlverPBLVS();
                    builder.BuildSnow();
                    builder.BuildSnowVS();
                    builder.BuildFilter();
                    builder.BuildMenu();
                    builder.BuildSfxPBL();
                    builder.BuildDeferred();
                    builder.BuildDbgFont();
                    builder.BuildArchivesFromStructure();
                    break;
                default:
                    Console.Error.WriteLine($"Unknown target: {target}");
                    Console.Error.WriteLine("Targets: all | everything | flver | flver-vs | snow | snow-vs | filter | menu | sfxpbl | deferred | dbgfont");
                    return -1;
            }

            sw.Stop();
            Console.WriteLine($"Target '{target}' done in {sw.Elapsed.TotalSeconds:F0}s. Built: {builder.Built}, Skipped: {builder.Skipped}, Errors: {builder.Errors}");
            if (builder.Errors > 0)
                Console.Error.WriteLine($"{builder.Errors} shaders FAILED to compile");
            return builder.Errors;
        }

        static string FindProjectRoot(string start)
        {
            var dir = new DirectoryInfo(start);
            while (dir != null)
            {
                if (Directory.Exists(Path.Combine(dir.FullName, "source")) &&
                    Directory.Exists(Path.Combine(dir.FullName, "tools")))
                    return dir.FullName;
                dir = dir.Parent;
            }
            return start;
        }
    }
}
