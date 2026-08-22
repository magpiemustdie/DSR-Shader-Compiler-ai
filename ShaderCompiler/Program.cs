using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

class ShaderBuild
{
    static string DSR  = @"D:\DarkSoulsRemastered";
    // Root: walk up from AppContext.BaseDirectory until we find the "source" folder
    // (handles both IDE run from bin/Debug/... and direct execution from project root)
    static string Root = FindProjectRoot(AppContext.BaseDirectory);
    static string FXC  => Path.Combine(Root, "tools", "fxc.exe");

    static string SRC  => Path.Combine(Root, "source", "FRPG_FlverPBL");
    static string SNOW => Path.Combine(Root, "source", "reconstructed", "FRPG_FlverPBL");
    static string FIL  => Path.Combine(Root, "source", "FRPG_Filter");
    static string MENU => Path.Combine(Root, "source", "reconstructed", "FRPG_Menu");

    static string FLVER_OUT     => Path.Combine(DSR, @"shader\FRPG_FlverPBL_fpo_DX11-shaderbnd-dcx");
    static string FLVER_VPO_OUT => Path.Combine(DSR, @"shader\FRPG_FlverPBL_vpo_DX11-shaderbnd-dcx");
    static string FIL_OUT       => Path.Combine(DSR, @"shader\FRPG_Filter_DX11-shaderbnd-dcx");
    static string MENU_OUT      => Path.Combine(DSR, @"shader\FRPG_Menu_DX11-shaderbnd-dcx\Source\Shader\FRPG_Menu\WIN32DX11");
    static string SFXPBL_OUT    => Path.Combine(DSR, @"shader\FRPG_SfxPBL_DX11-shaderbnd-dcx");

    static int built, skipped, errors;
    static bool force;
    static DateTime srcNewest;

    static void Main(string[] args)
    {
        // Parse args
        string target = "flver";
        foreach (var a in args)
        {
            if (a.StartsWith("-dsr:", StringComparison.OrdinalIgnoreCase))
                DSR = a.Substring(5);
            else if (a.Equals("-force", StringComparison.OrdinalIgnoreCase))
                force = true;
            else if (a.StartsWith("-target:", StringComparison.OrdinalIgnoreCase))
                target = a.Substring(8).ToLower();
        }

        // Compute newest source timestamp
        srcNewest = GetNewestFile(SRC, FIL, MENU, Path.Combine(Root, "source", "Common"), Path.Combine(Root, "source", "FRPG_SfxPBL"));

        var sw = Stopwatch.StartNew();
        Console.WriteLine($"DSR: {DSR}");
        Console.WriteLine($"Target: {target}  Force: {force}\n");

        switch (target)
        {
            case "flver":    BuildFlverPBL(); break;
            case "flver-vs": BuildFlverPBLVS(); break;
            case "snow":     BuildSnow();     break;
            case "snow-vs":  BuildSnowVS();   break;
            case "filter": BuildFilter();   break;
            case "filter-dof":        BuildFilterDof();        break;
            case "filter-hdr":        BuildFilterHdr();        break;
            case "filter-motionblur": BuildFilterMotionBlur(); break;
            case "filter-sao":        BuildFilterSao();        break;
            case "filter-ssao":       BuildFilterSsao();       break;
            case "filter-misc":       BuildFilterMisc();       break;
            case "filter-vs":         BuildFilterVs();         break;
            case "filter-compute":    BuildFilterCompute();    break;
            case "menu":   BuildMenu();     break;
            case "sfxpbl": BuildSfxPBL();   break;
            case "all":
                BuildFlverPBL();
                BuildFlverPBLVS();
                BuildSnow();
                BuildSnowVS();
                BuildFilter();
                BuildMenu();
                BuildSfxPBL();
                break;
            default:
                Console.WriteLine($"Unknown target: {target}");
                Console.WriteLine("Usage: ShaderBuild [-dsr:PATH] [-force] [-target:flver|flver-vs|snow|snow-vs|filter|menu|sfxpbl|all]");
                Console.WriteLine("  Filter sub-targets: filter-dof, filter-hdr, filter-motionblur,");
                Console.WriteLine("                      filter-sao, filter-ssao, filter-misc, filter-vs, filter-compute");
                return;
        }

        sw.Stop();
        Console.WriteLine($"\n--- Done in {sw.Elapsed.TotalSeconds:F1}s ---");
        Console.WriteLine($"  Built:   {built}");
        Console.WriteLine($"  Skipped: {skipped}");
        if (errors > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"  Errors:  {errors}");
            Console.ResetColor();
            Environment.Exit(1);
        }
    }

    // ----------------------------------------------------------------
    // FlverPBL — all Gst/Phn/Sfx variants, compiled in parallel
    // ----------------------------------------------------------------
    static void BuildFlverPBL()
    {
        Console.WriteLine("Building FlverPBL...");

        var jobs = new List<(string output, string[] defines)>();

        string[] spcs = { "", "Spc" };
        string[] bmps = { "", "Bmp" };
        string[] muls = { "", "Mul" };
        string[] lits = { "", "Lit" };
        string[] sdws = { "", "Sdw", "Csd" };

        string[] gstSuf = { "_HemEnv","_HemEnvAlp","_HemEnvLerp","_HemEnvLerpAlp",
                             "_HemEnvLerpPntS","_HemEnvLerpPntSS","_HemEnvLerpPntSSSS",
                             "_HemEnvPntS","_HemEnvPntSS","_HemEnvPntSSSS",
                             "_HemDir3","_HemDir3PntS","_HemDir3PntSS","_HemDir3PntSSSS" };

        string[] phnSuf = { "_HemEnv","_HemEnvAlp","_HemEnvLerp","_HemEnvLerpAlp",
                             "_HemEnvLerpParallax","_HemEnvLerpPntS","_HemEnvLerpPntSS","_HemEnvLerpPntSSSS",
                             "_HemEnvLerpSubsurf","_HemEnvParallax","_HemEnvPntS","_HemEnvPntSS","_HemEnvPntSSSS",
                             "_HemEnvSubsurf","_HemDir3","_HemDir3PntS","_HemDir3PntSS","_HemDir3PntSSSS" };

        string[] sfxSuf = { "_HemEnv","_HemEnvLerp","_HemEnvLerpPntS","_HemEnvPntS" };

        foreach (var spc in spcs) foreach (var bmp in bmps) foreach (var mul in muls)
        foreach (var lit in lits) foreach (var sdw in sdws)
        {
            // DSR naming: each slot is 3 chars wide, empty = "___"
            // e.g. Dif___BmpMulLitCsd, Dif______Mul______
            static string Slot(string v) => v.Length == 0 ? "___" : v;
            string base_ = "Dif" + Slot(spc) + Slot(bmp) + Slot(mul) + Slot(lit) + Slot(sdw);
            var baseDefs = new List<string> { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            if (spc == "Spc") baseDefs.Add("WITH_SpecularMap");
            if (bmp == "Bmp") baseDefs.Add("WITH_BumpMap");
            if (mul == "Mul") baseDefs.Add("WITH_MultiTexture");
            if (lit == "Lit") baseDefs.Add("WITH_LightMap");
            if (sdw == "Sdw") baseDefs.Add("WITH_ShadowMap=1");
            if (sdw == "Csd") baseDefs.Add("WITH_ShadowMap=2");

            foreach (var suf in gstSuf)
            {
                var d = new List<string>(baseDefs) { "WITH_GhostMap" };
                AddSufDefs(d, suf);
                jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Gst_{base_}{suf}.fpo"), d.ToArray()));
            }
            foreach (var suf in phnSuf)
            {
                var d = new List<string>(baseDefs);
                AddSufDefs(d, suf);
                jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Phn_{base_}{suf}.fpo"), d.ToArray()));
            }
            foreach (var suf in sfxSuf)
            {
                var d = new List<string>(baseDefs) { "WITH_Glow" };
                AddSufDefs(d, suf);
                jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Sfx_{base_}{suf}.fpo"), d.ToArray()));
            }
        }

        string src = Path.Combine(SRC, "FRPG_FS_HemEnv.fx");
        RunParallel(jobs, src, "FragmentMain", "ps_5_0");
    }

    static void AddSufDefs(List<string> d, string suf)
    {
        if (suf.Contains("Lerp"))     d.Add("WITH_EnvLerp");
        if (suf.Contains("Parallax")) d.Add("WITH_Parallax");
        if (suf.Contains("PntS"))     d.Add("WITH_PntS");
        if (suf.Contains("Subsurf"))  d.Add("FS_SUBSURF");
        if (suf.Contains("Alp"))      d.Add("WITH_AlphaBlend");
        if (suf.Contains("HemDir3"))  d.Add("WITH_HemDir3");
    }

    // ----------------------------------------------------------------
    // Snow
    // ----------------------------------------------------------------
    static void BuildSnow()
    {
        Console.WriteLine("Building Snow...");
        string src = Path.Combine(SNOW, "FRPG_FS_Snow.fx");
        string[] b = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };

        // All 25 pixel shader variants from a single source file.
        // WITH_HeightMap  → HeightMap depth pass
        // WITH_ShadowMap=1 → Ncs, =2 → Csd
        // WITH_LightMap   → Lit variants
        // WITH_PntS       → clustered point lights
        var variants = new (string name, string[] extra)[]
        {
            // Base
            ("FRPG_Snow_______.fpo",            new string[0]),
            ("FRPG_Snow_______PntS.fpo",        new[]{"WITH_PntS"}),
            ("FRPG_Snow_______PntSS.fpo",       new[]{"WITH_PntS"}),
            ("FRPG_Snow_______PntSSSS.fpo",     new[]{"WITH_PntS"}),
            // Shadow Ncs
            ("FRPG_Snow____Ncs.fpo",            new[]{"WITH_ShadowMap=1"}),
            ("FRPG_Snow____NcsPntS.fpo",        new[]{"WITH_ShadowMap=1","WITH_PntS"}),
            ("FRPG_Snow____NcsPntSS.fpo",       new[]{"WITH_ShadowMap=1","WITH_PntS"}),
            ("FRPG_Snow____NcsPntSSSS.fpo",     new[]{"WITH_ShadowMap=1","WITH_PntS"}),
            // Shadow Csd
            ("FRPG_Snow____Csd.fpo",            new[]{"WITH_ShadowMap=2"}),
            ("FRPG_Snow____CsdPntS.fpo",        new[]{"WITH_ShadowMap=2","WITH_PntS"}),
            ("FRPG_Snow____CsdPntSS.fpo",       new[]{"WITH_ShadowMap=2","WITH_PntS"}),
            ("FRPG_Snow____CsdPntSSSS.fpo",     new[]{"WITH_ShadowMap=2","WITH_PntS"}),
            // Lightmap
            ("FRPG_Snow_Lit___.fpo",            new[]{"WITH_LightMap"}),
            ("FRPG_Snow_Lit___PntS.fpo",        new[]{"WITH_LightMap","WITH_PntS"}),
            ("FRPG_Snow_Lit___PntSS.fpo",       new[]{"WITH_LightMap","WITH_PntS"}),
            ("FRPG_Snow_Lit___PntSSSS.fpo",     new[]{"WITH_LightMap","WITH_PntS"}),
            // Lightmap + Ncs
            ("FRPG_Snow_LitNcs.fpo",            new[]{"WITH_LightMap","WITH_ShadowMap=1"}),
            ("FRPG_Snow_LitNcsPntS.fpo",        new[]{"WITH_LightMap","WITH_ShadowMap=1","WITH_PntS"}),
            ("FRPG_Snow_LitNcsPntSS.fpo",       new[]{"WITH_LightMap","WITH_ShadowMap=1","WITH_PntS"}),
            ("FRPG_Snow_LitNcsPntSSSS.fpo",     new[]{"WITH_LightMap","WITH_ShadowMap=1","WITH_PntS"}),
            // Lightmap + Csd
            ("FRPG_Snow_LitCsd.fpo",            new[]{"WITH_LightMap","WITH_ShadowMap=2"}),
            ("FRPG_Snow_LitCsdPntS.fpo",        new[]{"WITH_LightMap","WITH_ShadowMap=2","WITH_PntS"}),
            ("FRPG_Snow_LitCsdPntSS.fpo",       new[]{"WITH_LightMap","WITH_ShadowMap=2","WITH_PntS"}),
            ("FRPG_Snow_LitCsdPntSSSS.fpo",     new[]{"WITH_LightMap","WITH_ShadowMap=2","WITH_PntS"}),
            // HeightMap depth pass
            ("FRPG_Snow_HeightMap.fpo",         new[]{"WITH_HeightMap"}),
        };

        var jobs = variants.Select(v =>
            (Path.Combine(FLVER_OUT, v.name), b.Concat(v.extra).ToArray())).ToList();
        RunParallel(jobs, src, "FragmentMain", "ps_5_0", new[] { SNOW, SRC });
    }

    // ----------------------------------------------------------------
    // FlverPBL Vertex Shaders
    // ----------------------------------------------------------------
    static void BuildFlverPBLVS()
    {
        Console.WriteLine("Building FlverPBL VS...");
        string src = Path.Combine(SRC, "FRPG_VS_FlverPBL.fx");
        string[] b = { "_WIN32=1","_DX11=1" };

        var jobs = new List<(string output, string[] defines)>();

        string[] vtxFmts = { "PIN", "PINT", "PINTT", "PIWN", "PIWNT", "PIWNTT" };
        string[] sdwSufs = { "Non", "Sdw", "Dep", "DepAlp", "Vel", "VelAlp" };
        string[] spcs = { "", "Spc" };
        string[] bmps = { "", "Bmp" };
        string[] muls = { "", "Mul" };
        string[] lits = { "", "Lit" };
        string[] sdws = { "", "Sdw", "Csd" };

        static string Slot(string v) => v.Length == 0 ? "___" : v;

        foreach (var vtx in vtxFmts)
        foreach (var spc in spcs) foreach (var bmp in bmps) foreach (var mul in muls)
        foreach (var lit in lits) foreach (var sdw in sdws)
        foreach (var sdwSuf in sdwSufs)
        {
            string base_ = vtx + "_" + Slot(spc) + Slot(bmp) + Slot(mul) + Slot(lit) + Slot(sdw);
            var bd = new List<string>(b);

            bool hasTan  = vtx.Contains("T");
            bool hasMul  = vtx.Contains("TT") || mul == "Mul";
            bool hasSkin = vtx.Contains("W");

            if (hasTan)  bd.Add("WITH_BumpMap");
            if (hasMul)  bd.Add("WITH_MultiTexture");
            if (hasSkin) bd.Add("WITH_Skin");
            if (spc == "Spc") bd.Add("WITH_SpecularMap");
            if (lit == "Lit") bd.Add("WITH_LightMap");
            if (sdw == "Sdw") bd.Add("WITH_ShadowMap=1");
            if (sdw == "Csd") bd.Add("WITH_ShadowMap=2");
            if (sdwSuf == "Dep" || sdwSuf == "DepAlp") bd.Add("WITH_DepthWrite");
            if (sdwSuf == "DepAlp" || sdwSuf == "VelAlp") bd.Add("WITH_AlphaBlend");
            if (sdwSuf == "Vel" || sdwSuf == "VelAlp") bd.Add("WITH_Velocity");

            jobs.Add((Path.Combine(FLVER_VPO_OUT, $"FRPG_Phn_{base_}_{sdwSuf}.vpo"), bd.ToArray()));
            jobs.Add((Path.Combine(FLVER_VPO_OUT, $"FRPG_Gst_{base_}_{sdwSuf}.vpo"), bd.ToArray()));
            var sfxDefs = new List<string>(bd) { "WITH_Glow" };
            jobs.Add((Path.Combine(FLVER_VPO_OUT, $"FRPG_Sfx_{base_}_{sdwSuf}.vpo"), sfxDefs.ToArray()));
        }

        RunParallel(jobs, src, "VertexMain", "vs_5_0");
    }

    // ----------------------------------------------------------------
    // Snow Vertex Shaders
    // ----------------------------------------------------------------
    static void BuildSnowVS()
    {
        Console.WriteLine("Building Snow VS...");
        string src = Path.Combine(SNOW, "FRPG_VS_Snow.fx");
        string[] b = { "_WIN32=1","_DX11=1" };

        var variants = new (string name, string[] extra)[]
        {
            ("FRPG_Snow_______.vpo",            Array.Empty<string>()),
            ("FRPG_Snow_Lit___.vpo",            new[]{"WITH_LightMap"}),
            ("FRPG_Snow_HeightMap.vpo",          new[]{"WITH_HeightMap"}),
            ("FRPG_Snow_HeightMap_Lit.vpo",      new[]{"WITH_HeightMap","WITH_LightMap"}),
            ("FRPG_Snow_Skin_______.vpo",        new[]{"WITH_Skin"}),
            ("FRPG_Snow_Skin_Lit___.vpo",        new[]{"WITH_Skin","WITH_LightMap"}),
            ("FRPG_Snow_HeightMap_Skin.vpo",     new[]{"WITH_HeightMap","WITH_Skin"}),
            ("FRPG_Snow_HeightMap_Skin_Lit.vpo", new[]{"WITH_HeightMap","WITH_Skin","WITH_LightMap"}),
        };

        var jobs = variants.Select(v =>
            (Path.Combine(FLVER_VPO_OUT, v.name), b.Concat(v.extra).ToArray())).ToList();
        RunParallel(jobs, src, "VertexMain", "vs_5_0", new[] { SNOW, SRC });
    }

    // ----------------------------------------------------------------
    // Filter
    // ----------------------------------------------------------------
    static void BuildFilter()
    {
        Console.WriteLine("Building Filter...");
        string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };

        Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_SingleFragment.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_SingleFragment.fpo"), "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Bloom_improved.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Bloom.fpo"),                    "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_BrightPassFilter.fx"),         Path.Combine(FIL_OUT, "FRPG_Fil_BrightPassFilter.fpo"),         "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_DownScale.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_DownScale2x2.fpo"),             "FragmentMain_2x2","ps_5_0",d);
        Compile(Path.Combine(FIL, "FRPG_Fil_DownScale.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_DownScale4x4.fpo"),             "FragmentMain_4x4","ps_5_0",d);
        Compile(Path.Combine(FIL, "FRPG_Fil_GaussBlur5x5.fx"),             Path.Combine(FIL_OUT, "FRPG_Fil_GaussBlur5x5.fpo"),             "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Dof_DofRate.fx"),              Path.Combine(FIL_OUT, "FRPG_Fil_Dof_DofRate.fpo"),              "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Dof_NearRate.fx"),             Path.Combine(FIL_OUT, "FRPG_Fil_Dof_NearRate.fpo"),             "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Dof_DownSample.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_DownSample.fpo"),           "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Dof_WeightedDownsample.fx"),   Path.Combine(FIL_OUT, "FRPG_Fil_Dof_WeightedDownsample.fpo"),   "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Dof_Unfocus3x3.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_Unfocus3x3.fpo"),           "FragmentMain",   "ps_5_0", d);
        Compile(Path.Combine(FIL, "FRPG_Fil_Dof_BlurUpSample.fx"),         Path.Combine(FIL_OUT, "FRPG_Fil_Dof_BlurUpSample.fpo"),         "FragmentMain",   "ps_5_0", d);
    }

    // ----------------------------------------------------------------
    // Menu
    // ----------------------------------------------------------------
    static void BuildMenu()
    {
        Console.WriteLine("Building Menu...");
        string[] d = { "_WIN32=1","_DX11=1" };
        Compile(Path.Combine(MENU, "FRPG_Menu.fx"), Path.Combine(MENU_OUT, "FRPG_Menu_Col.fpo"),         "FS_Col",         "ps_5_0", d);
        Compile(Path.Combine(MENU, "FRPG_Menu.fx"), Path.Combine(MENU_OUT, "FRPG_Menu_ColTex.fpo"),      "FS_ColTex",      "ps_5_0", d);
        Compile(Path.Combine(MENU, "FRPG_Menu.fx"), Path.Combine(MENU_OUT, "FRPG_Menu_FontSharpen.fpo"), "FS_FontSharpen", "ps_5_0", d);
        Compile(Path.Combine(MENU, "FRPG_Menu.fx"), Path.Combine(MENU_OUT, "FRPG_Menu_Common.vpo"),      "VS_Common",      "vs_5_0", d);
        Compile(Path.Combine(MENU, "FRPG_Menu.fx"), Path.Combine(MENU_OUT, "FRPG_Menu_Font.vpo"),        "VS_Font",        "vs_5_0", d);
        Compile(Path.Combine(MENU, "FRPG_Menu.fx"), Path.Combine(MENU_OUT, "FRPG_Menu_Font_AL.vpo"),     "VS_Font_AL",     "vs_5_0", d);
    }

    // ----------------------------------------------------------------
    // SfxPBL (SFX sprites/post-effects: 34 PS + 29 VS)
    // ----------------------------------------------------------------
    static void BuildSfxPBL()
    {
        Console.WriteLine("Building SfxPBL...");
        string sfxpbl = Path.Combine(Root, "source", "FRPG_SfxPBL");

        // PS: 34 (Blur 0-3, Tracer 0-3, Line 0, PointSprite 0, Distortion 0-5,
        //      SimpleSprite 0-8, SimpleSprite_Depth 0-8)
        var psJobs = new List<(string output, string[] defines)>();
        void AddPs(string fx, string def, int count, string prefix)
        {
            for (int t = 0; t < count; ++t)
                psJobs.Add((Path.Combine(SFXPBL_OUT, $"{prefix}Type{t}.fpo"), new[] { $"{def}={t}" }));
        }
        AddPs("Blur.fx",              "BLUR_TYPE",          4, "FRPG_Sfx_Blur");
        AddPs("Tracer.fx",            "TRACER_TYPE",        4, "FRPG_Sfx_Tracer");
        AddPs("Line.fx",              "LINE_TYPE",          1, "FRPG_Sfx_Line");
        AddPs("PointSprite.fx",       "POINT_SPRITE_TYPE",  1, "FRPG_Sfx_PointSprite");
        AddPs("Distortion.fx",        "DISTORTION_TYPE",    6, "FRPG_Sfx_Distortion");
        AddPs("SimpleSprite.fx",      "SIMPLE_SPRITE_TYPE", 9, "FRPG_Sfx_SimpleSprite");
        AddPs("SimpleSprite_Depth.fx","DEPTH_SPRITE_TYPE",  9, "FRPG_Sfx_SimpleSprite_Depth");
        string fsDir = Path.Combine(sfxpbl, "FRPG_FS_Sfx_");
        foreach (var (out_, defs) in psJobs)
        {
            string base_ = Path.GetFileName(out_).Replace("FRPG_Sfx_", "FRPG_FS_Sfx_")
                                                      .Replace(".fpo", ".fx");
            if (base_.StartsWith("FRPG_FS_Sfx_SimpleSprite_Depth"))
                base_ = "FRPG_FS_Sfx_SimpleSprite_Depth.fx";
            Compile(Path.Combine(fsDir, base_), out_, "FragmentMain", "ps_5_0", defs);
        }

        // VS: 29 (Blur 0-1, Line 0, Tracer 0-1, Distortion 0, PointSprite 0,
        //      SimpleSprite 0-8, SimpleSprite_Depth 0-8, Particle 0-3)
        var vsJobs = new List<(string output, string[] defines)>();
        void AddVs(string kind, int count, string prefix)
        {
            for (int t = 0; t < count; ++t)
                vsJobs.Add((Path.Combine(SFXPBL_OUT, $"{prefix}Type{t}.vpo"),
                            new[] { $"SFX_VS_KIND={kind}", $"SFX_VS_TYPE={t}" }));
        }
        AddVs("0", 2, "FRPG_Sfx_Blur");
        AddVs("1", 1, "FRPG_Sfx_Line");
        AddVs("2", 2, "FRPG_Sfx_Tracer");
        AddVs("3", 1, "FRPG_Sfx_Distortion");
        AddVs("4", 1, "FRPG_Sfx_PointSprite");
        AddVs("5", 9, "FRPG_Sfx_SimpleSprite");
        for (int t = 0; t < 9; ++t)
            vsJobs.Add((Path.Combine(SFXPBL_OUT, $"FRPG_Sfx_SimpleSprite_DepthType{t}.vpo"),
                        new[] { "SFX_VS_KIND=5", $"SFX_VS_TYPE={t}", "SFX_VS_DEPTH=1" }));
        for (int t = 0; t < 4; ++t)
            vsJobs.Add((Path.Combine(SFXPBL_OUT, $"FRPG_Sfx_SimpleSpriteType{t}_Particle.vpo"),
                        new[] { "SFX_VS_KIND=6", $"SFX_VS_TYPE={t}" }));
        string vsSrc = Path.Combine(sfxpbl, "FRPG_VS_Sfx.fx");
        foreach (var job in vsJobs)
            Compile(vsSrc, job.output, "VSFragmentMain", "vs_5_0", job.defines);
    }

    // ----------------------------------------------------------------
    // Parallel runner
    // ----------------------------------------------------------------
    static void RunParallel(List<(string output, string[] defines)> jobs, string src, string entry, string profile)
        => RunParallel(jobs, src, entry, profile, (string[]?)null);

    static void RunParallel(List<(string output, string[] defines)> jobs, string src, string entry, string profile, string? includePath)
        => RunParallel(jobs, src, entry, profile, includePath != null ? new[] { includePath } : null);

    static void RunParallel(List<(string output, string[] defines)> jobs, string src, string entry, string profile, string[]? includePaths)
    {
        int total = jobs.Count;
        int done  = 0;

        Parallel.ForEach(jobs, new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount }, job =>
        {
            Compile(src, job.output, entry, profile, job.defines, includePaths);
            int n = Interlocked.Increment(ref done);
            if (n % 50 == 0 || n == total)
                Console.WriteLine($"  {n}/{total}...");
        });
    }

    // ----------------------------------------------------------------
    // Single compile
    // ----------------------------------------------------------------
    static void Compile(string src, string output, string entry, string profile, string[] defines)
        => Compile(src, output, entry, profile, defines, (string[]?)null);

    static void Compile(string src, string output, string entry, string profile, string[] defines, string? includePath)
        => Compile(src, output, entry, profile, defines, includePath != null ? new[] { includePath } : null);

    static void Compile(string src, string output, string entry, string profile, string[] defines, string[]? includePaths)
    {
        // Incremental: skip if output is newer than sources
        if (!force && File.Exists(output))
        {
            var outTime = File.GetLastWriteTime(output);
            if (outTime > srcNewest)
            {
                Interlocked.Increment(ref skipped);
                return;
            }
        }

        Directory.CreateDirectory(Path.GetDirectoryName(output)!);

        var defArgs  = string.Join(" ", defines.Select(d => $"/D{d}"));
        var inclArgs = includePaths != null
            ? string.Join(" ", includePaths.Select(p => $"/I\"{p}\""))
            : "";
        var args     = $"\"{src}\" /Fo\"{output}\" /T {profile} /nologo {defArgs} {inclArgs} /E{entry}";

        var psi = new ProcessStartInfo(FXC, args)
        {
            RedirectStandardOutput = true,
            RedirectStandardError  = true,
            UseShellExecute        = false,
            CreateNoWindow         = true
        };

        using var proc = Process.Start(psi)!;
        string stderr = proc.StandardError.ReadToEnd();
        string stdout = proc.StandardOutput.ReadToEnd();
        proc.WaitForExit();

        if (proc.ExitCode != 0)
        {
            Interlocked.Increment(ref errors);
            lock (Console.Out)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"FAILED: {Path.GetFileName(output)}");
                Console.ResetColor();
                foreach (var line in (stdout + stderr).Split('\n'))
                    if (line.Contains("error") || line.Contains("warning"))
                        Console.WriteLine($"  {line.Trim()}");
            }
        }
        else
        {
            Interlocked.Increment(ref built);
        }
    }

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------
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
        return start; // fallback
    }

    static DateTime GetNewestFile(params string[] dirs)
    {
        var dt = DateTime.MinValue;
        foreach (var dir in dirs)
        {
            if (!Directory.Exists(dir)) continue;
            foreach (var f in Directory.GetFiles(dir, "*", SearchOption.AllDirectories))
            {
                var t = File.GetLastWriteTime(f);
                if (t > dt) dt = t;
            }
        }
        return dt;
    }
}
