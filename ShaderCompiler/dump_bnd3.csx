using System;
using System.IO;
using SoulsFormats;

var bakPath = @"d:\DarkSoulsRemastered\shader\FRPG_Filter_DX11.shaderbnd.dcx.bak";
var bytes = DCX.Decompress(bakPath);
var bnd = BND3.Read(bytes);
Console.WriteLine($"Total files: {bnd.Files.Count}");
foreach (var f in bnd.Files)
    Console.WriteLine(f.Name);
