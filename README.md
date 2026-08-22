# DSR Shader Mods

Reconstructed HLSL shader sources for **Dark Souls Remastered** (DX11),
compiled with the original fxc v6.3.9600 (Win 8.1 SDK) to produce
byte-exact `.fpo`/`.vpo` binaries.

## Structure

```
source/                      HLSL source code
  Common/                    Shared headers (dx11.h, HALFDefine)
  FRPG_FlverPBL/             Character / object shaders (Phn, Gst, Snow, Water…)
  FRPG_Filter/               Post-effects (DoF, HDR, TAA, SAO, SSAO, MotionBlur…)
  FRPG_Deferred/             Deferred lighting passes
  FRPG_SfxPBL/               SFX sprites / particles
  FRPG_Menu_DX11/            UI shaders
  DbgFont/                   Debug font + primitive shaders

ShaderCompiler/              C# WPF tool — compiles source → game archives
  ShaderBuilder.cs           Compilation logic (fxc invocation, archive packing)
  MainWindow.xaml/.cs        GUI

tools/
  fxc_81/fxc.exe             fxc v6.3.9600.16384 (Win 8.1 SDK) — matches DSR compiler
  fxc_new/fxc.exe            fxc v10 (for cross-reference)
```

## Building

1. Open `ShaderCompiler/ShaderCompiler.sln` in Visual Studio or Rider
2. Set paths in the GUI: DSR game folder, source folder
3. Click **Build All (clean)** — compiles all 7 DX11 shader archives (~13 min)

Or build the solution from the command line:

```powershell
dotnet build ShaderCompiler/ShaderCompiler.sln -c Release
```

## Requirements

- .NET 9 SDK
- `tools/fxc_81/fxc.exe` (included)
- Dark Souls Remastered installation (for deploying compiled shaders)

## Notes

- Float constants are taken from SHEX sections of original `.fpo` binaries,
  not from disassembly (which rounds values for display).
- `BUILD ALL` always uses fxc v6.3.9600 to match the original compiler.
- The `reference/` folder (original game binaries) is not included — provide
  your own from a DSR installation.
