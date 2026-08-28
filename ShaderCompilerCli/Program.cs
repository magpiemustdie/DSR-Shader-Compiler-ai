using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using ShaderCompiler;

string root   = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
string fxc81  = Path.Combine(root, "tools", "fxc_81", "fxc.exe");
string source = Path.Combine(root, "source");
string dsr    = @"D:\DarkSoulsRemastered";

Console.WriteLine("=== BUILD ALL (clean) ===");
Console.WriteLine($"FXC81 : {fxc81}");
Console.WriteLine($"Source: {source}");
Console.WriteLine($"DSR   : {dsr}");
Console.WriteLine();

var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

var builder = new ShaderBuilder(dsr, fxc81, source, force: true, cts.Token, originalDir: "");

int lastDone = 0;
builder.OnLog += msg => Console.WriteLine(msg);
builder.OnProgress += (done, total) =>
{
    if (done - lastDone >= 100 || done == total)
    {
        Console.Error.Write($"\r  {done}/{total}   ");
        lastDone = done;
    }
};

var sw = Stopwatch.StartNew();
try
{
    builder.BuildAll();
    Console.Error.WriteLine();
    Console.WriteLine($"\nCompile: {builder.Built} built, {builder.Skipped} skipped, {builder.Errors} errors ({sw.Elapsed.TotalSeconds:0}s)");

    if (builder.Errors > 0)
    {
        Console.WriteLine($"[ABORT] {builder.Errors} compile errors — not packing.");
        Environment.Exit(1);
    }

    Console.WriteLine("\n--- Packing archives ---");
    builder.BuildArchivesFromStructure();
    Console.WriteLine($"\n=== Done in {sw.Elapsed.TotalSeconds:0}s ===");
    Environment.Exit(0);
}
catch (OperationCanceledException) { Console.WriteLine("Cancelled."); Environment.Exit(2); }
catch (Exception ex)               { Console.WriteLine($"Error: {ex}"); Environment.Exit(3); }
