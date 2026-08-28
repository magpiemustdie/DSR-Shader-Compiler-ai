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
  ShaderBuilder.cs           Compilation logic (fxc invocation, archive packing via archive_structures.json)
  MainWindow.xaml/.cs        GUI (Build / Build All + Pack, Bundle Unpack/Pack)

ShaderCompilerCli/           Headless CLI — same builder, no GUI
  Program.cs                 `dotnet run --project ShaderCompilerCli` → BuildAll + Pack

SoulsFormatsNEXT/            Vendored JKAnderson/SoulsFormats (BND3/DCX)

tools/
  fxc_81/fxc.exe             fxc v6.3.9600.16384 (Win 8.1 SDK) — matches DSR compiler
  fxc_new/fxc.exe            fxc v10 (for cross-reference)
  DiffShader/                WARP differential tester (ref vs our, EPS 2e-3)
  bnd3tool/                  BND3/DCX packer (used by ShaderBuilder.BuildArchivesFromStructure)
  verify_all.py              Byte-identity check (BYTE / SHEX_small / SHEX_big)

build.cmd / pack.ps1         One-shot build & pack (see below)
```

## Building

**GUI:**
1. Open `ShaderCompiler/ShaderCompiler.sln` in Visual Studio/Rider
2. Set paths: DSR game folder (`D:\DarkSoulsRemastered`), source folder
3. Click **Build All (clean)** — compiles 2872 shaders → 7 `*.shaderbnd.dcx` in `DSR\shader\` (~10 min, then `BuildArchivesFromStructure`)

**CLI (headless, same as GUI Build All):**
```powershell
dotnet run --project ShaderCompilerCli -c Release
# or
.\build.cmd                 # full rebuild + pack
.\build.cmd -inc            # incremental (skip up-to-date)
ShaderCompiler\bin\Release\net10.0-windows\ShaderCompiler.exe -build          # all
ShaderCompiler\bin\Release\net10.0-windows\ShaderCompiler.exe -build -target:flver -inc
```

`ShaderCompiler -build` with `target:all` now packs `*.shaderbnd.dcx` via `archive_structures.json` (no need for `pack.ps1` separately; `pack.ps1` remains as `bnd3tool swapall` helper for `make`).

**7 DX11 archives:** `FRPG_FlverPBL_fpo_DX11` (1989), `FRPG_FlverPBL_vpo_DX11` (676), `FRPG_Filter_DX11` (116), `FRPG_SfxPBL_DX11` (63), `FRPG_Menu_DX11` (6), `DbgFont_DX11` (8), `FRPG_Deferred_DX11` (6) — `verify_all.py` → `1227/2864 42.8% BYTE`, rest `SHEX_small` (scheduler, GPU-identical via `DiffShader`).

Or build the solution from the command line:

```powershell
dotnet build ShaderCompiler/ShaderCompiler.sln -c Release
```

## Requirements

- .NET 10 SDK (`ShaderCompiler` targets `net10.0-windows`, `ShaderCompilerCli` `net9.0` → `net10.0` via `SoulsFormatsNEXT`)
- `tools/fxc_81/fxc.exe` 6.3.9600.16384 (included, Win 8.1 SDK)
- Dark Souls Remastered installation (`D:\DarkSoulsRemastered\shader\` + `shader-original\` for packing)
- Python 3.12 + Git + GNU Make 3.81 for `tools\verify_all.py` / `DiffShader` / `Makefile`

## Notes

- Float constants are taken from SHEX sections of original `.fpo` binaries,
  not from disassembly (which rounds values for display).
- `BUILD ALL` always uses fxc v6.3.9600 to match the original compiler.
- The `reference/` folder (original game binaries) is not included — provide
  your own from a DSR installation.
