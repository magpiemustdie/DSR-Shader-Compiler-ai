using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using SoulsFormats;

namespace ShaderCompiler
{
    public class ShaderBuilder
    {
        public int Built;
        public int Skipped;
        public int Errors;

        // Files actually compiled (written) in this run
        private readonly System.Collections.Concurrent.ConcurrentBag<string> _builtFiles = new();
        public IReadOnlyCollection<string> BuiltFiles => _builtFiles;

        public event Action<string>?   OnLog;
        public event Action<int, int>? OnProgress;

        private readonly string _dsr;
        private readonly string _fxc;
        private readonly string _source;
        private readonly bool   _force;
        private readonly CancellationToken _token;
        private readonly string _origDir;

        // Dedicated lock object — never lock on strings or public objects
        private readonly object _logLock = new();
        private readonly object _dirLock = new();

        private string SRC    => Path.Combine(_source, "FRPG_FlverPBL");
        private string FIL    => Path.Combine(_source, "FRPG_Filter");
        private string MENU   => Path.Combine(_source, "FRPG_Menu_DX11");
        private string SNOW   => Path.Combine(_source, "FRPG_FlverPBL");
        private string COMMON => Path.Combine(_source, "Common");

        private string FLVER_OUT     => Path.Combine(_dsr, @"shader\FRPG_FlverPBL_fpo_DX11-shaderbnd-dcx");
        private string FLVER_VPO_OUT => Path.Combine(_dsr, @"shader\FRPG_FlverPBL_vpo_DX11-shaderbnd-dcx");
        private string FIL_OUT       => Path.Combine(_dsr, @"shader\FRPG_Filter_DX11-shaderbnd-dcx");
        private string MENU_OUT      => Path.Combine(_dsr, @"shader\FRPG_Menu_DX11-shaderbnd-dcx");
        private string SFXPBL_OUT    => Path.Combine(_dsr, @"shader\FRPG_SfxPBL_DX11-shaderbnd-dcx");

        private DateTime _srcNewest;

        public ShaderBuilder(string dsr, string fxc, string source, bool force, CancellationToken token, string originalDir = "")
        {
            _dsr    = dsr;
            _fxc    = fxc;
            _source = source;
            _force  = force;
            _token  = token;
            _origDir = originalDir;
            _srcNewest = GetNewestFile(_source);
        }

        // ----------------------------------------------------------------
        // FlverPBL fpo — orchestrator (all sub-groups)
        // ----------------------------------------------------------------
        public void BuildFlverPBL()
        {
            BuildFlverPBLPhnGstSfx();
            BuildNon();
            BuildSfxBase();
            BuildWaterWWS();
            BuildFlverPBLMisc();
        }

        // ----------------------------------------------------------------
        // FlverPBL fpo — Core: Phn / Gst / Sfx HemEnv suffix variants
        // FlverPBL fpo — Phn / Gst / Sfx HemEnv suffix variants
        // (~1536 fpo — the bulk of the FlverPBL archive)
        // ----------------------------------------------------------------
        public void BuildFlverPBLPhnGstSfx()
        {
            Log("Building FlverPBL...");
            var jobs = new List<(string output, string[] defines)>();

            string[] spcs = { "", "Spc" };
            string[] bmps = { "", "Bmp" };
            string[] muls = { "", "Mul" };
            string[] lits = { "", "Lit" };
            string[] sdws = { "", "Sdw", "Csd" };

            // DSR naming: each slot is 3 chars wide, empty = "___"
            // e.g. Dif___BmpMulLitCsd, Dif______Mul______
            static string Slot(string v) => v.Length == 0 ? "___" : v;

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
                string base_ = "Dif" + Slot(spc) + Slot(bmp) + Slot(mul) + Slot(lit) + Slot(sdw);
                var bd = new List<string> { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
                if (spc == "Spc") bd.Add("WITH_SpecularMap");
                if (bmp == "Bmp") bd.Add("WITH_BumpMap");
                if (mul == "Mul") bd.Add("WITH_MultiTexture");
                if (lit == "Lit") bd.Add("WITH_LightMap");
                if (sdw == "Sdw") bd.Add("WITH_ShadowMap=1");
                if (sdw == "Csd") bd.Add("WITH_ShadowMap=2");

                foreach (var suf in gstSuf)
                {
                    var d = new List<string>(bd) { "WITH_GhostMap" };
                    AddSufDefs(d, suf);
                    jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Gst_{base_}{suf}.fpo"), d.ToArray()));
                }
                foreach (var suf in phnSuf)
                {
                    var d = new List<string>(bd);
                    AddSufDefs(d, suf);
                    jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Phn_{base_}{suf}.fpo"), d.ToArray()));
                }
                foreach (var suf in sfxSuf)
                {
                    var d = new List<string>(bd) { "WITH_Glow" };
                    AddSufDefs(d, suf);
                    jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Sfx_{base_}{suf}.fpo"), d.ToArray()));
                }
            }

            string src = Path.Combine(SRC, "FRPG_FS_HemEnv.fx");
            string srcAlp = Path.Combine(SRC, "FRPG_FS_HemEnv_Alpha.fx");

            // AlphaBlend variants use a separate shader (ref: Makefile rules for *_HemEnvAlp/*_HemEnvLerpAlp)
            var (hemEnvJobs, alpJobs) = (new List<(string, string[])>(jobs.Count),
                                          new List<(string, string[])>(jobs.Count / 4));
            foreach (var job in jobs)
            {
                if (job.Item1.Contains("Alp"))
                    alpJobs.Add(job);
                else
                    hemEnvJobs.Add(job);
            }

            RunParallel(hemEnvJobs, src, "FragmentMain", "ps_5_0");
            RunParallel(alpJobs, srcAlp, "FragmentMain", "ps_5_0");
        }

        // ----------------------------------------------------------------
        // FlverPBL fpo — Water + WWS (26 forward + 12 GBuffer + 2 WWS)
        // ----------------------------------------------------------------
        public void BuildWaterWWS()
        {
            BuildWater();
            BuildWWS();
        }

        // ----------------------------------------------------------------
        // FlverPBL fpo — Misc small families
        // DeferredDisney(16) + Dbg(14) + NtoA(4) + Ghost(1) + FaceEye(24) + DepVel(5)
        // ----------------------------------------------------------------
        public void BuildFlverPBLMisc()
        {
            BuildDisney();
            BuildDbg();
            BuildNtoA();
            BuildGhost();
            BuildFaceEye();
            BuildDepVel();
        }

        static void AddSufDefs(List<string> d, string suf)
        {
            // Mirror Makefile add_variant rules (lines 164-174)
            // ref: _HemEnvLerpPntS is BINARY-EQUAL to _HemEnvPntS (no second
            // cube pair) — same precedent as LerpParallax == LerpSubsurf
            if (suf.Contains("Lerp") && !suf.EndsWith("LerpPntS")) d.Add("WITH_EnvLerp");
            if (suf.Contains("HemEnvParallax")) d.Add("WITH_Parallax");
            else if (suf.Contains("LerpParallax")) d.Add("FS_SUBSURF"); // ref: LerpParallax = LerpSubsurf
            if (suf.Contains("PntSSSS"))
            {
                d.Add("WITH_PntS"); d.Add("WITH_GBuffer"); d.Add("OLD_VERSION=1");
                d.Add("USE_SH=1"); d.Add("WITH_GBUFFER_4LIGHTS");
            }
            else if (suf.Contains("PntSS"))
            {
                d.Add("WITH_PntS"); d.Add("WITH_GBuffer"); d.Add("OLD_VERSION=1"); d.Add("USE_SH=1");
            }
            else if (suf.Contains("PntS")) d.Add("WITH_PntS");
            if (suf.Contains("Subsurf"))  d.Add("FS_SUBSURF");
            if (suf.Contains("Alp"))      d.Add("WITH_AlphaBlend");
            if (suf.Contains("HemDir3"))  { d.Add("WITH_HemDir3"); d.Add("OLD_VERSION=1"); }
        }

        // ----------------------------------------------------------------
        // Snow
        // ----------------------------------------------------------------
        public void BuildSnow()
        {
            Log("Building Snow...");
            string src = Path.Combine(SNOW, "FRPG_Snow_All.fx");
            string[] b = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };

            // All 25 pixel shader variants from a single source file.
            // WITH_HeightMap  → HeightMap depth pass
            // WITH_ShadowMap=1 → Ncs, =2 → Csd
            // WITH_LightMap   → Lit variants
            // WITH_PntS       → clustered point lights
            var jobs = new List<(string name, string[] extra)>
            {
                // Base
                ("FRPG_Snow_______.fpo",            Array.Empty<string>()),
                ("FRPG_Snow_______PntS.fpo",        new[]{"WITH_PntS"}),
                // Shadow Ncs
                ("FRPG_Snow____Ncs.fpo",            new[]{"WITH_ShadowMap=1"}),
                ("FRPG_Snow____NcsPntS.fpo",        new[]{"WITH_ShadowMap=1","WITH_PntS"}),
                // Shadow Csd
                ("FRPG_Snow____Csd.fpo",            new[]{"WITH_ShadowMap=2"}),
                ("FRPG_Snow____CsdPntS.fpo",        new[]{"WITH_ShadowMap=2","WITH_PntS"}),
                // Lightmap
                ("FRPG_Snow_Lit___.fpo",            new[]{"WITH_LightMap"}),
                ("FRPG_Snow_Lit___PntS.fpo",        new[]{"WITH_LightMap","WITH_PntS"}),
                // Lightmap + Ncs
                ("FRPG_Snow_LitNcs.fpo",            new[]{"WITH_LightMap","WITH_ShadowMap=1"}),
                ("FRPG_Snow_LitNcsPntS.fpo",        new[]{"WITH_LightMap","WITH_ShadowMap=1","WITH_PntS"}),
                // Lightmap + Csd
                ("FRPG_Snow_LitCsd.fpo",            new[]{"WITH_LightMap","WITH_ShadowMap=2"}),
                ("FRPG_Snow_LitCsdPntS.fpo",        new[]{"WITH_LightMap","WITH_ShadowMap=2","WITH_PntS"}),
                // HeightMap depth pass
                ("FRPG_Snow_HeightMap.fpo",         new[]{"WITH_HeightMap"}),
            };

            // GBuffer variants (PntSS/PntSSSS) — separate shader with WITH_GBuffer (Makefile: SNOW_GBUFFER_TARGETS)
            string[][] gbDefs = {
                new[]{"WITH_GBuffer"},
                new[]{"WITH_GBuffer","WITH_GBUFFER_4LIGHTS"},
                new[]{"WITH_ShadowMap=1","WITH_GBuffer"},
                new[]{"WITH_ShadowMap=1","WITH_GBuffer","WITH_GBUFFER_4LIGHTS"},
                new[]{"WITH_ShadowMap=2","WITH_GBuffer"},
                new[]{"WITH_ShadowMap=2","WITH_GBuffer","WITH_GBUFFER_4LIGHTS"},
                new[]{"WITH_LightMap","WITH_GBuffer"},
                new[]{"WITH_LightMap","WITH_GBuffer","WITH_GBUFFER_4LIGHTS"},
                new[]{"WITH_LightMap","WITH_ShadowMap=1","WITH_GBuffer"},
                new[]{"WITH_LightMap","WITH_ShadowMap=1","WITH_GBuffer","WITH_GBUFFER_4LIGHTS"},
                new[]{"WITH_LightMap","WITH_ShadowMap=2","WITH_GBuffer"},
                new[]{"WITH_LightMap","WITH_ShadowMap=2","WITH_GBuffer","WITH_GBUFFER_4LIGHTS"},
            };
            string[] gbNames = {
                "FRPG_Snow_______PntSS.fpo", "FRPG_Snow_______PntSSSS.fpo",
                "FRPG_Snow____NcsPntSS.fpo", "FRPG_Snow____NcsPntSSSS.fpo",
                "FRPG_Snow____CsdPntSS.fpo", "FRPG_Snow____CsdPntSSSS.fpo",
                "FRPG_Snow_Lit___PntSS.fpo", "FRPG_Snow_Lit___PntSSSS.fpo",
                "FRPG_Snow_LitNcsPntSS.fpo", "FRPG_Snow_LitNcsPntSSSS.fpo",
                "FRPG_Snow_LitCsdPntSS.fpo", "FRPG_Snow_LitCsdPntSSSS.fpo",
            };

            var fwdJobs = jobs.Select(v =>
                (Path.Combine(FLVER_OUT, v.name), b.Concat(v.extra).ToArray())).ToList();
            var gbJobs = gbNames.Zip(gbDefs, (n, e) =>
                (Path.Combine(FLVER_OUT, n), b.Concat(e).ToArray())).ToList();

            RunParallel(fwdJobs, Path.Combine(SNOW, "FRPG_Snow_All.fx"), "FragmentMain", "ps_5_0", new[] { SNOW, SRC });
            RunParallel(gbJobs, Path.Combine(SNOW, "FRPG_Snow_GBuffer.fx"), "FragmentMain", "ps_5_0", new[] { SNOW, SRC });
        }

        // ----------------------------------------------------------------
        // Filter вЂ” grouped sub-targets for easier debugging
        // Usage: -target:filter-dof, filter-hdr, filter-motionblur,
        //        filter-sao, filter-ssao, filter-misc, filter-vs, filter-compute
        // ----------------------------------------------------------------
        public void BuildFilter()
        {
            BuildFilterDof();
            BuildFilterHdr();
            BuildFilterMotionBlur();
            BuildFilterSao();
            BuildFilterSsao();
            BuildFilterMisc();
            BuildFilterVs();
            BuildFilterCompute();
        }

        // ----------------------------------------------------------------
        // Non shaders (Phn/Gst/Sfx): FRPG_FS_Non.fx, WITHOUT_DETAILBUMP=1
        // (Makefile: FRPG_%_Non.fpo / FRPG_Sfx_%_Non.fpo)
        // ----------------------------------------------------------------
        public void BuildNon()
        {
            Log("Building Non shaders...");
            string[] spcs = { "", "Spc" }, bmps = { "", "Bmp" }, muls = { "", "Mul" },
                     lits = { "", "Lit" }, sdws = { "", "Sdw", "Csd" };
            static string Slot(string v) => v.Length == 0 ? "___" : v;

            var jobs = new List<(string output, string[] defines)>();
            foreach (var spc in spcs) foreach (var bmp in bmps) foreach (var mul in muls)
            foreach (var lit in lits) foreach (var sdw in sdws)
            {
                string base_ = "Dif" + Slot(spc) + Slot(bmp) + Slot(mul) + Slot(lit) + Slot(sdw);
                var bd = new List<string> { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1",
                                            "WITHOUT_DETAILBUMP=1" };
                if (spc == "Spc") bd.Add("WITH_SpecularMap");
                if (bmp == "Bmp") bd.Add("WITH_BumpMap");
                if (mul == "Mul") bd.Add("WITH_MultiTexture");
                if (lit == "Lit") bd.Add("WITH_LightMap");
                if (sdw == "Sdw") bd.Add("WITH_ShadowMap=1");
                if (sdw == "Csd") bd.Add("WITH_ShadowMap=2");
                // ref has _Non only for Phn and Sfx (no Gst_*_Non)
                // build_non.py: Sfx gets WITH_Glow (gates tone-map block), Gst gets WITH_GhostMap
                jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Phn_{base_}_Non.fpo"), bd.ToArray()));
                jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Sfx_{base_}_Non.fpo"),
                          bd.Concat(new[]{"WITH_Glow"}).ToArray()));
            }
            RunParallel(jobs, Path.Combine(SRC, "FRPG_FS_Non.fx"), "FragmentMain", "ps_5_0");
        }

        // ----------------------------------------------------------------
        // Sfx base (no suffix): FRPG_FS_Sfx.fx with WITH_Glow
        // (Makefile: FRPG_Sfx_%.fpo → FRPG_FS_Sfx.fx)
        // ----------------------------------------------------------------
        public void BuildSfxBase()
        {
            Log("Building Sfx base...");
            string[] spcs = { "", "Spc" }, bmps = { "", "Bmp" }, muls = { "", "Mul" },
                     lits = { "", "Lit" }, sdws = { "", "Sdw", "Csd" };
            static string Slot(string v) => v.Length == 0 ? "___" : v;

            var jobs = new List<(string output, string[] defines)>();
            foreach (var spc in spcs) foreach (var bmp in bmps) foreach (var mul in muls)
            foreach (var lit in lits) foreach (var sdw in sdws)
            {
                string base_ = "Dif" + Slot(spc) + Slot(bmp) + Slot(mul) + Slot(lit) + Slot(sdw);
                var bd = new List<string> { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1","WITH_Glow" };
                if (spc == "Spc") bd.Add("WITH_SpecularMap");
                if (bmp == "Bmp") bd.Add("WITH_BumpMap");
                if (mul == "Mul") bd.Add("WITH_MultiTexture");
                if (lit == "Lit") bd.Add("WITH_LightMap");
                if (sdw == "Sdw") bd.Add("WITH_ShadowMap=1");
                if (sdw == "Csd") bd.Add("WITH_ShadowMap=2");
                jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Sfx_{base_}.fpo"), bd.ToArray()));
            }
            RunParallel(jobs, Path.Combine(SRC, "FRPG_FS_Sfx.fx"), "FragmentMain", "ps_5_0");
        }

        // ----------------------------------------------------------------
        // Water (26 forward + 12 GBuffer): FRPG_Water_All.fx / _GBuffer.fx
        // ----------------------------------------------------------------
        public void BuildWater()
        {
            Log("Building Water...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };

            var jobs = new List<(string output, string[] defines)>();
            void W(string name, params string[] extra)
                => jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_{name}.fpo"), d.Concat(extra).ToArray()));

            W("Water_Env____", "WATER_ENV");
            W("Water_Env____PntS", "WATER_ENV", "WITH_PntS");
            W("Water_Env_Ncs", "WATER_ENV", "WITH_ShadowMap=1");
            W("Water_Env_NcsPntS", "WATER_ENV", "WITH_ShadowMap=1", "WITH_PntS");
            W("Water_Env_Csd", "WATER_ENV", "WITH_ShadowMap=2");
            W("Water_Env_CsdPntS", "WATER_ENV", "WITH_ShadowMap=2", "WITH_PntS");
            W("Water_Reflect____", "WATER_REFLECT");
            W("Water_Reflect____PntS", "WATER_REFLECT", "WITH_PntS");
            W("Water_Reflect_Ncs", "WATER_REFLECT", "WITH_ShadowMap=1");
            W("Water_Reflect_NcsPntS", "WATER_REFLECT", "WITH_ShadowMap=1", "WITH_PntS");
            W("Water_Reflect_Csd", "WATER_REFLECT", "WITH_ShadowMap=2");
            W("Water_Reflect_CsdPntS", "WATER_REFLECT", "WITH_ShadowMap=2", "WITH_PntS");
            W("Water_Mask", "WATER_MASK");
            W("Water_HeightMap", "WATER_HEIGHTMAP");

            RunParallel(jobs, Path.Combine(SRC, "FRPG_Water_All.fx"), "FragmentMain", "ps_5_0", new[] { SRC });

            var gbJobs = new List<(string output, string[] defines)>();
            void G(string name, params string[] extra)
                => gbJobs.Add((Path.Combine(FLVER_OUT, $"FRPG_{name}.fpo"), d.Concat(extra).ToArray()));

            G("Water_Env____PntSS", "WATER_ENV", "WITH_GBuffer");
            G("Water_Env____PntSSSS", "WATER_ENV", "WITH_GBuffer", "WITH_GBUFFER_4LIGHTS");
            G("Water_Env_NcsPntSS", "WATER_ENV", "WITH_ShadowMap=1", "WITH_GBuffer");
            G("Water_Env_NcsPntSSSS", "WATER_ENV", "WITH_ShadowMap=1", "WITH_GBuffer", "WITH_GBUFFER_4LIGHTS");
            G("Water_Env_CsdPntSS", "WATER_ENV", "WITH_ShadowMap=2", "WITH_GBuffer");
            G("Water_Env_CsdPntSSSS", "WATER_ENV", "WITH_ShadowMap=2", "WITH_GBuffer", "WITH_GBUFFER_4LIGHTS");
            G("Water_Reflect____PntSS", "WATER_REFLECT", "WITH_GBuffer");
            G("Water_Reflect____PntSSSS", "WATER_REFLECT", "WITH_GBuffer", "WITH_GBUFFER_4LIGHTS");
            G("Water_Reflect_NcsPntSS", "WATER_REFLECT", "WITH_ShadowMap=1", "WITH_GBuffer");
            G("Water_Reflect_NcsPntSSSS", "WATER_REFLECT", "WITH_ShadowMap=1", "WITH_GBuffer", "WITH_GBUFFER_4LIGHTS");
            G("Water_Reflect_CsdPntSS", "WATER_REFLECT", "WITH_ShadowMap=2", "WITH_GBuffer");
            G("Water_Reflect_CsdPntSSSS", "WATER_REFLECT", "WITH_ShadowMap=2", "WITH_GBuffer", "WITH_GBUFFER_4LIGHTS");

            RunParallel(gbJobs, Path.Combine(SRC, "FRPG_Water_All_GBuffer.fx"), "FragmentMain", "ps_5_0", new[] { SRC });
        }

        // ----------------------------------------------------------------
        // WWS WaterWave (2 variants)
        // ----------------------------------------------------------------
        public void BuildWWS()
        {
            Log("Building WWS...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            string src = Path.Combine(SRC, "FRPG_WWS_WaterWave_new.fx");
            var jobs = new List<(string output, string[] defines)>
            {
                (Path.Combine(FLVER_OUT, "FRPG_WWS_Dif________________WaterWave.fpo"), d),
                (Path.Combine(FLVER_OUT, "FRPG_WWS_Dif______Mul_______WaterWave.fpo"),
                    d.Concat(new[]{"WITH_MultiTexture"}).ToArray()),
            };
            Compile(src, jobs[0].output, "FragmentMain_WaterWave",    "ps_5_0", jobs[0].defines, new[] { COMMON, SRC });
            Compile(src, jobs[1].output, "FragmentMain_WaterWaveMul", "ps_5_0", jobs[1].defines, new[] { COMMON, SRC });
        }

        // ----------------------------------------------------------------
        // Deferred Disney (16 variants)
        // ----------------------------------------------------------------
        public void BuildDisney()
        {
            Log("Building DeferredDisney...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            var variants = new (string name, string[] extra)[]
            {
                ("Dif_________",      Array.Empty<string>()),
                ("Dif_________Mul",   new[]{"WITH_MultiTexture"}),
                ("DifSpc______",      new[]{"WITH_SpecularMap"}),
                ("DifSpc______Mul",   new[]{"WITH_SpecularMap","WITH_MultiTexture"}),
                ("Dif___Bmp___",      new[]{"WITH_BumpMap"}),
                ("Dif___Bmp___Mul",   new[]{"WITH_BumpMap","WITH_MultiTexture"}),
                ("DifSpcBmp___",      new[]{"WITH_SpecularMap","WITH_BumpMap"}),
                ("DifSpcBmp___Mul",   new[]{"WITH_SpecularMap","WITH_BumpMap","WITH_MultiTexture"}),
                ("Dif______Lit",      new[]{"WITH_LightMap"}),
                ("Dif______LitMul",   new[]{"WITH_LightMap","WITH_MultiTexture"}),
                ("DifSpc___Lit",      new[]{"WITH_SpecularMap","WITH_LightMap"}),
                ("DifSpc___LitMul",   new[]{"WITH_SpecularMap","WITH_LightMap","WITH_MultiTexture"}),
                ("Dif___BmpLit",      new[]{"WITH_BumpMap","WITH_LightMap"}),
                ("Dif___BmpLitMul",   new[]{"WITH_BumpMap","WITH_LightMap","WITH_MultiTexture"}),
                ("DifSpcBmpLit",      new[]{"WITH_SpecularMap","WITH_BumpMap","WITH_LightMap"}),
                ("DifSpcBmpLitMul",   new[]{"WITH_SpecularMap","WITH_BumpMap","WITH_LightMap","WITH_MultiTexture"}),
            };
            var jobs = variants.Select(v =>
                (Path.Combine(FLVER_OUT, $"FRPG_DeferredDisney_{v.name}.fpo"),
                 d.Concat(v.extra).ToArray())).ToList();
            RunParallel(jobs, Path.Combine(SRC, "FRPG_FS_DeferredDisney.fx"), "FragmentMain", "ps_5_0");
        }

        // ----------------------------------------------------------------
        // Dbg visualizers: Nrm (8), PntNum (5), Snow_Nrm (1)
        // ----------------------------------------------------------------
        public void BuildDbg()
        {
            Log("Building Dbg...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };

            var nrmJobs = new List<(string output, string[] defines)>();
            void N(string name, params string[] extra)
                => nrmJobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Dbg_{name}.fpo"), d.Concat(extra).ToArray()));
            N("Dif________________Nrm");
            N("Dif________________NrmErr", "WITH_NrmErr");
            N("Dif___Bmp__________Nrm", "WITH_BumpMap");
            N("Dif___Bmp__________NrmErr", "WITH_BumpMap", "WITH_NrmErr");
            N("Dif______Mul_______Nrm", "WITH_MultiTexture");
            N("Dif______Mul_______NrmErr", "WITH_MultiTexture", "WITH_NrmErr");
            N("Dif___BmpMul_______Nrm", "WITH_BumpMap", "WITH_MultiTexture");
            N("Dif___BmpMul_______NrmErr", "WITH_BumpMap", "WITH_MultiTexture", "WITH_NrmErr");
            RunParallel(nrmJobs, Path.Combine(SRC, "FRPG_FS_Dbg_Nrm.fx"), "FragmentMain", "ps_5_0");

            var pntJobs = new List<(string output, string[] defines)>();
            void P(string name, params string[] extra)
                => pntJobs.Add((Path.Combine(FLVER_OUT, $"FRPG_Dbg_{name}.fpo"), d.Concat(extra).ToArray()));
            P("PntNum_Pnt");
            P("PntNum_PntS", "WITH_S");
            P("PntNum_PntSS", "WITH_S", "WITH_SS");
            P("PntNum_PntSSS", "WITH_S", "WITH_SS", "WITH_SSS");
            P("PntNum_PntSSSS", "WITH_S", "WITH_SS", "WITH_SSS", "WITH_SSSS");
            RunParallel(pntJobs, Path.Combine(SRC, "FRPG_FS_Dbg_PntNum.fx"), "FragmentMain", "ps_5_0");

            Compile(Path.Combine(SRC, "FRPG_FS_Dbg_Snow_Nrm.fx"),
                    Path.Combine(FLVER_OUT, "FRPG_Dbg_Snow_Nrm.fpo"),
                    "FragmentMain", "ps_5_0", d);
        }

        // ----------------------------------------------------------------
        // NtoA (Normal-to-Alpha, 4 variants)
        // ----------------------------------------------------------------
        public void BuildNtoA()
        {
            Log("Building NtoA...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            var jobs = new List<(string output, string[] defines)>
            {
                (Path.Combine(FLVER_OUT, "FRPG_NtoA_Non.fpo"),    d),
                (Path.Combine(FLVER_OUT, "FRPG_NtoA_Sdw.fpo"),    d.Concat(new[]{"WITH_ShadowMap=1"}).ToArray()),
                (Path.Combine(FLVER_OUT, "FRPG_NtoA_Csd.fpo"),    d.Concat(new[]{"WITH_ShadowMap=2"}).ToArray()),
                (Path.Combine(FLVER_OUT, "FRPG_NtoA_DepAlp.fpo"), d.Concat(new[]{"WITH_DepAlp"}).ToArray()),
            };
            RunParallel(jobs, Path.Combine(SRC, "FRPG_FS_NtoA.fx"), "FragmentMain", "ps_5_0");
        }

        // ----------------------------------------------------------------
        // Ghost
        // ----------------------------------------------------------------
        public void BuildGhost()
        {
            Log("Building Ghost...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(SRC, "FRPG_FS_Ghost.fx"),
                    Path.Combine(FLVER_OUT, "FRPG_Ghost.fpo"),
                    "FragmentMain", "ps_5_0", d);
        }

        // ----------------------------------------------------------------
        // FaceEye (12 forward + 12 GBuffer) — dead code (MTD LightingType=1)
        // ----------------------------------------------------------------
        public void BuildFaceEye()
        {
            Log("Building FaceEye...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            string src  = Path.Combine(SRC, "FRPG_FS_FaceEye.fx");
            string gbSrc = Path.Combine(SRC, "FRPG_FS_FaceEye_GBuffer.fx");

            var jobs = new List<(string output, string[] defines)>();
            void F(string fam, string name, params string[] extra)
                => jobs.Add((Path.Combine(FLVER_OUT, $"FRPG_{fam}_FaceEye{name}.fpo"),
                             d.Concat(extra).ToArray()));

            // Phn (no GhostMap)
            F("Phn", "____");
            F("Phn", "____PntS", "WITH_PntS");
            F("Phn", "_Sdw", "WITH_ShadowMap=1", "FACEEYE_SHADOW_PROJ");
            F("Phn", "_SdwPntS", "WITH_ShadowMap=1", "WITH_PntS", "FACEEYE_SHADOW_PROJ");
            F("Phn", "_Csd", "WITH_ShadowMap=2");
            F("Phn", "_CsdPntS", "WITH_ShadowMap=2", "WITH_PntS");
            // Gst (with GhostMap)
            F("Gst", "____", "WITH_GhostMap");
            F("Gst", "____PntS", "WITH_GhostMap", "WITH_PntS");
            F("Gst", "_Sdw", "WITH_ShadowMap=1", "WITH_GhostMap", "FACEEYE_SHADOW_PROJ");
            F("Gst", "_SdwPntS", "WITH_ShadowMap=1", "WITH_GhostMap", "WITH_PntS", "FACEEYE_SHADOW_PROJ");
            F("Gst", "_Csd", "WITH_ShadowMap=2", "WITH_GhostMap");
            F("Gst", "_CsdPntS", "WITH_ShadowMap=2", "WITH_GhostMap", "WITH_PntS");
            RunParallel(jobs, src, "FragmentMain", "ps_5_0");

            var gbJobs = new List<(string output, string[] defines)>();
            void G(string fam, string name, params string[] extra)
                => gbJobs.Add((Path.Combine(FLVER_OUT, $"FRPG_{fam}_FaceEye{name}.fpo"),
                               d.Concat(new[]{"WITH_PntS","WITH_GBuffer","OLD_VERSION=1","USE_SH=1"})
                                .Concat(name.Contains("PntSSSS") ? new[]{"WITH_GBUFFER_4LIGHTS"} : Array.Empty<string>())
                                .Concat(extra).ToArray()));
            G("Phn", "____PntSS");
            G("Phn", "____PntSSSS");
            G("Phn", "_SdwPntSS", "WITH_ShadowMap=1");
            G("Phn", "_SdwPntSSSS", "WITH_ShadowMap=1");
            G("Phn", "_CsdPntSS", "WITH_ShadowMap=2");
            G("Phn", "_CsdPntSSSS", "WITH_ShadowMap=2");
            G("Gst", "____PntSS", "WITH_GhostMap");
            G("Gst", "____PntSSSS", "WITH_GhostMap");
            G("Gst", "_SdwPntSS", "WITH_ShadowMap=1", "WITH_GhostMap");
            G("Gst", "_SdwPntSSSS", "WITH_ShadowMap=1", "WITH_GhostMap");
            G("Gst", "_CsdPntSS", "WITH_ShadowMap=2", "WITH_GhostMap");
            G("Gst", "_CsdPntSSSS", "WITH_ShadowMap=2", "WITH_GhostMap");
            RunParallel(gbJobs, gbSrc, "FragmentMain", "ps_5_0");
        }

        // ----------------------------------------------------------------
        // Dep/Vel (5 variants) — depth/velocity stubs
        // ----------------------------------------------------------------
        public void BuildDepVel()
        {
            Log("Building Dep/Vel...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            string depSrc = Path.Combine(SRC, "FRPG_FS_Dep.fx");
            string velSrc = Path.Combine(SRC, "FRPG_FS_Vel.fx");

            Compile(depSrc, Path.Combine(FLVER_OUT, "FRPG_Phn_Dif________________Dep.fpo"),
                    "FragmentMain", "ps_5_0", d, new[] { COMMON });
            Compile(depSrc, Path.Combine(FLVER_OUT, "FRPG_Phn_Dif________________DepAlp.fpo"),
                    "FragmentMain_Alp", "ps_5_0", d, new[] { COMMON });
            Compile(depSrc, Path.Combine(FLVER_OUT, "FRPG_Phn_Dif______Mul_______DepAlp.fpo"),
                    "FragmentMain", "ps_5_0", d, new[] { COMMON });
            Compile(velSrc, Path.Combine(FLVER_OUT, "FRPG_Phn_Dif________________Vel.fpo"),
                    "FragmentMain", "ps_5_0", d, new[] { COMMON });
            Compile(velSrc, Path.Combine(FLVER_OUT, "FRPG_Phn_Dif________________VelAlp.fpo"),
                    "FragmentMain_Alp", "ps_5_0", d, new[] { COMMON });
        }

        public void BuildFilterDof()
        {
            Log("Building Filter/DOF...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_DofRate.fx"),              Path.Combine(FIL_OUT, "FRPG_Fil_Dof_DofRate.fpo"),              "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_DofRate_CB.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_DofRate_CB.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_NearRate.fx"),             Path.Combine(FIL_OUT, "FRPG_Fil_Dof_NearRate.fpo"),             "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_DownSample.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_DownSample.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_WeightedDownsample.fx"),   Path.Combine(FIL_OUT, "FRPG_Fil_Dof_WeightedDownsample.fpo"),   "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_Unfocus3x3.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_Unfocus3x3.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_UnfocusNearRate3x3.fx"),   Path.Combine(FIL_OUT, "FRPG_Fil_Dof_UnfocusNearRate3x3.fpo"),   "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_BlurUpSample.fx"),         Path.Combine(FIL_OUT, "FRPG_Fil_Dof_BlurUpSample.fpo"),         "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_GaussX.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_Dof_GaussX.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_GaussY.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_Dof_GaussY.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_GaussX_Adv.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_GaussX_Adv.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_GaussY_Adv.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Dof_GaussY_Adv.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_StretchAlphaX.fx"),        Path.Combine(FIL_OUT, "FRPG_Fil_Dof_StretchAlphaX.fpo"),        "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_StretchAlphaY.fx"),        Path.Combine(FIL_OUT, "FRPG_Fil_Dof_StretchAlphaY.fpo"),        "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_CB.fx"),                   Path.Combine(FIL_OUT, "FRPG_Fil_Dof_CB.fpo"),                   "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof.fx"),                      Path.Combine(FIL_OUT, "FRPG_Fil_Dof.fpo"),                      "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_VS.fx"),                   Path.Combine(FIL_OUT, "FRPG_Fil_Dof.vpo"),                      "VertexMain",      "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_GaussX.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_Dof_GaussX.vpo"),        "VertexMain", "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_GaussY.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_Dof_GaussY.vpo"),        "VertexMain", "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_GaussX.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_Dof_StretchAlphaX.vpo"), "VertexMain", "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_GaussY.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_Dof_StretchAlphaY.vpo"), "VertexMain", "vs_5_0", d);
            // Dof_CB.vpo == Dof.vpo byte-equal pair (ref) — same KIND0 VS with two TEXCOORD outputs
            Compile(Path.Combine(FIL, "FRPG_Fil_Dof_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_Dof_CB.vpo"), "VertexMain", "vs_5_0", d);
            // Quad VS for DOF pixel shaders (simple passthrough)
            foreach (var name in new[]{ "FRPG_Fil_Dof_DofRate","FRPG_Fil_Dof_DofRate_CB",
                "FRPG_Fil_Dof_DownSample","FRPG_Fil_Dof_NearRate","FRPG_Fil_Dof_WeightedDownsample" })
                Compile(Path.Combine(FIL, "FRPG_Fil_Quad.fx"), Path.Combine(FIL_OUT, $"{name}.vpo"), "VertexMain", "vs_5_0", d);
            // Special VS with UV offsets for multi-tap DOF shaders
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_BlurUpSample.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_Dof_BlurUpSample.vpo"), "VertexMain", "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_Unfocus3x3.fx"),   Path.Combine(FIL_OUT, "FRPG_Fil_Dof_Unfocus3x3.vpo"),        "VertexMain", "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Quad_Unfocus3x3.fx"),   Path.Combine(FIL_OUT, "FRPG_Fil_Dof_UnfocusNearRate3x3.vpo"), "VertexMain", "vs_5_0", d);
        }

        public void BuildFilterHdr()
        {
            Log("Building Filter/HDR...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Fil_SampleLumInitial.fx"),         Path.Combine(FIL_OUT, "FRPG_Fil_SampleLumInitial.fpo"),         "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SampleLumFinal.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_SampleLumFinal.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_CalcAdaptedLum.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_CalcAdaptedLum.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_CalcAdaptedLum_PBL.fx"),       Path.Combine(FIL_OUT, "FRPG_Fil_CalcAdaptedLum_PBL.fpo"),       "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_HDR.fx"),                      Path.Combine(FIL_OUT, "FRPG_Fil_HDR.fpo"),                      "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_HDR_ColAdj.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_HDR_ColAdj.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_HDR_Menu.fx"),                 Path.Combine(FIL_OUT, "FRPG_Fil_HDR_Menu.fpo"),                 "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_HDR_PBL.fx"),                  Path.Combine(FIL_OUT, "FRPG_Fil_HDR_PBL.fpo"),                  "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_HDR_PBL_ColAdj.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_HDR_PBL_ColAdj.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Bloom_improved.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_Bloom.fpo"),                    "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_BrightPassFilter.fx"),         Path.Combine(FIL_OUT, "FRPG_Fil_BrightPassFilter.fpo"),         "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Star.fx"),                     Path.Combine(FIL_OUT, "FRPG_Fil_Star.fpo"),                     "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_GaussBlur5x5.fx"),             Path.Combine(FIL_OUT, "FRPG_Fil_GaussBlur5x5.fpo"),             "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DownScale.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_DownScale2x2.fpo"),             "FragmentMain_2x2","ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DownScale.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_DownScale4x4.fpo"),             "FragmentMain_4x4","ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_LightShaft.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_LightShaft.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Sfx_Glow_Blur.fx"),            Path.Combine(FIL_OUT, "FRPG_Fil_Sfx_Glow_Blur.fpo"),            "FragmentMain",    "ps_5_0", d);
            foreach (var name in new[]{ "FRPG_Fil_HDR_ColAdj","FRPG_Fil_HDR_PBL","FRPG_Fil_HDR_PBL_ColAdj","FRPG_Fil_HDR" })
                Compile(Path.Combine(FIL, "FRPG_Fil_HDR_VS.fx"), Path.Combine(FIL_OUT, $"{name}.vpo"), "VertexMain", "vs_5_0", d);
            // HDR_Menu VS is a PLAIN quad (no cb0[68] noise UV) - separate source
            Compile(Path.Combine(FIL, "FRPG_Fil_HDR_Menu_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_HDR_Menu.vpo"), "VertexMain", "vs_5_0", d);
        }

        public void BuildFilterMotionBlur()
        {
            Log("Building Filter/MotionBlur...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Fil_MotionBlurPre.fx"),            Path.Combine(FIL_OUT, "FRPG_Fil_MotionBlurPre.fpo"),            "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_MotionBlurFinal.fx"),          Path.Combine(FIL_OUT, "FRPG_Fil_MotionBlurFinal.fpo"),          "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_MotionBlurPre_CB.fx"),         Path.Combine(FIL_OUT, "FRPG_Fil_MotionBlurPre_CB.fpo"),         "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_ResolveTAA.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_ResolveTAA.fpo"),               "FragmentMain",    "ps_5_0", d);
            foreach (var name in new[]{ "FRPG_Fil_MotionBlurFinal","FRPG_Fil_MotionBlurPre","FRPG_Fil_MotionBlurPre_CB","FRPG_Fil_ResolveTAA" })
                Compile(Path.Combine(FIL, "FRPG_Fil_Quad.fx"), Path.Combine(FIL_OUT, $"{name}.vpo"), "VertexMain", "vs_5_0", d);
        }

        public void BuildFilterSao()
        {
            Log("Building Filter/SAO...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Fil_SAO_Main.fx"),                 Path.Combine(FIL_OUT, "FRPG_Fil_SAO_Main.fpo"),                 "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SAO_Depth.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_SAO_Depth.fpo"),                "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SAO_Blur.fx"),                 Path.Combine(FIL_OUT, "FRPG_Fil_SAO_Blur.fpo"),                 "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SAO_Minify.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_SAO_Minify.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SAO_Combine.fx"),              Path.Combine(FIL_OUT, "FRPG_Fil_SAO_Combine.fpo"),              "FragmentMain",    "ps_5_0", d);
            foreach (var name in new[]{ "FRPG_Fil_SAO_Blur","FRPG_Fil_SAO_Combine","FRPG_Fil_SAO_Depth","FRPG_Fil_SAO_Main","FRPG_Fil_SAO_Minify" })
                Compile(Path.Combine(FIL, "FRPG_Fil_Quad.fx"), Path.Combine(FIL_OUT, $"{name}.vpo"), "VertexMain", "vs_5_0", d);
        }

        public void BuildFilterSsao()
        {
            Log("Building Filter/SSAO (Compute)...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Compute_SAO_Depth.fx"),                      Path.Combine(FIL_OUT, "FRPG_Compute_SAO_Depth.cpo"),                      "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SAO_Blur.fx"),                       Path.Combine(FIL_OUT, "FRPG_Compute_SAO_Blur.cpo"),                       "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SAO_Main.fx"),                       Path.Combine(FIL_OUT, "FRPG_Compute_SAO_Main.cpo"),                       "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_PrepareDepthBuffers1.fx"),      Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_PrepareDepthBuffers1.cpo"),      "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_PrepareDepthBuffers1CB.fx"),    Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_PrepareDepthBuffers1CB.cpo"),    "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_PrepareDepthBuffers2.fx"),      Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_PrepareDepthBuffers2.cpo"),      "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_Render1.fx"),                   Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_Render1.cpo"),                   "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_Render2.fx"),                   Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_Render2.cpo"),                   "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_BlurUpsample.fx"),              Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_BlurUpsample.cpo"),              "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_BlurUpsampleBlendOut.fx"),      Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_BlurUpsampleBlendOut.cpo"),      "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_BlurUpsamplePreMin.fx"),        Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_BlurUpsamplePreMin.cpo"),        "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_SSAO_BlurUpsamplePreMinBlendOut.fx"), Path.Combine(FIL_OUT, "FRPG_Compute_SSAO_BlurUpsamplePreMinBlendOut.cpo"), "ComputeMain", "cs_5_0", d);
        }

        public void BuildFilterMisc()
        {
            Log("Building Filter/Misc...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_SingleFragment.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_SingleFragment.fpo"), "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy.fpo"),                "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_Fragment0.fx"),      Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_Fragment0.fpo"),      "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_Fragment1.fx"),      Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_Fragment1.fpo"),      "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_MSAA.fx"),           Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_MSAA.fpo"),           "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_BlackBars.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_BlackBars.fpo"),                "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_CubeBlend.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_CubeBlend.fpo"),                "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_ThruWithDepth.fx"),            Path.Combine(FIL_OUT, "FRPG_Fil_ThruWithDepth.fpo"),            "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_CameraBlur.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_CameraBlur.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_CameraBlurPower.fx"),          Path.Combine(FIL_OUT, "FRPG_Fil_CameraBlurPower.fpo"),          "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Bilateral.fx"),                Path.Combine(FIL_OUT, "FRPG_Fil_Bilateral.fpo"),                "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_FxAA2.fx"),                    Path.Combine(FIL_OUT, "FRPG_Fil_FxAA2.fpo"),                    "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_FxAA2_High.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_FxAA2_High.fpo"),               "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SubsurfX.fx"),                 Path.Combine(FIL_OUT, "FRPG_Fil_SubsurfX.fpo"),                 "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_SubsurfY.fx"),                 Path.Combine(FIL_OUT, "FRPG_Fil_SubsurfY.fpo"),                 "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_ShadowMapDbg.fx"),             Path.Combine(FIL_OUT, "FRPG_Fil_ShadowMapDbg.fpo"),             "FragmentMain",    "ps_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_Dbg_LogTex.fx"),               Path.Combine(FIL_OUT, "FRPG_Fil_Dbg_LogTex.fpo"),               "FragmentMain",    "ps_5_0", d);
        }

        public void BuildFilterVs()
        {
            Log("Building Filter/VS (Quad)...");
            string[] d = { "_WIN32=1","_VERTEX_SHADER=1","_DX11=1" };

            // Standard quad VS (SV_VertexID, TEXCOORD0)
            string[] vsQuad = new[] { "FRPG_Fil_Quad", "FRPG_Fil_Bilateral", "FRPG_Fil_CameraBlur",
                "FRPG_Fil_CameraBlurPower", "FRPG_Fil_CubeBlend", "FRPG_Fil_DepthCopy",
                "FRPG_Fil_ShadowMapDbg" };
            foreach (var name in vsQuad)
                Compile(Path.Combine(FIL, "FRPG_Fil_Quad.fx"), Path.Combine(FIL_OUT, $"{name}.vpo"), "VertexMain", "vs_5_0", d);

            // BlackBars VS — takes POSITION input (not SV_VertexID)
            Compile(Path.Combine(FIL, "FRPG_Fil_BlackBars_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_BlackBars.vpo"), "VertexMain", "vs_5_0", d);

            // DepthCopy_Fragment VS — uses ICB with 6 positions
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_Fragment_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_Fragment0.vpo"), "VertexMain", "vs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_Fragment_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_Fragment1.vpo"), "VertexMain", "vs_5_0", d);

            // DepthCopy_MSAA VS — outputs TEXCOORD0 xyzw
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_MSAA_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_MSAA.vpo"), "VertexMain", "vs_5_0", d);

            // DepthCopy_SingleFragment VS — uses ICB with 6 positions AND 6 UVs
            Compile(Path.Combine(FIL, "FRPG_Fil_DepthCopy_SingleFragment_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_DepthCopy_SingleFragment.vpo"), "VertexMain", "vs_5_0", d);

            // FxAA2 VS — outputs TEXCOORD1 xyzw with z = cb0[12].z + UV.x
            Compile(Path.Combine(FIL, "FRPG_Fil_FxAA2_VS.fx"), Path.Combine(FIL_OUT, "FRPG_Fil_FxAA2.vpo"), "VertexMain", "vs_5_0", d);

            // HDR VS are compiled in BuildFilterHdr — not duplicated here
        }

        public void BuildFilterCompute()
        {
            Log("Building Filter/Compute (MotionBlur tiles)...");
            string[] d = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(FIL, "FRPG_Compute_CopyExpandedHTile.fx"),   Path.Combine(FIL_OUT, "FRPG_Compute_CopyExpandedHTile.cpo"),   "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_MotionBlurTiles.fx"),     Path.Combine(FIL_OUT, "FRPG_Compute_MotionBlurTiles.cpo"),     "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_MotionBlurTiles_CB.fx"),  Path.Combine(FIL_OUT, "FRPG_Compute_MotionBlurTiles_CB.cpo"),  "ComputeMain", "cs_5_0", d);
            Compile(Path.Combine(FIL, "FRPG_Compute_ResolveCB.fx"),           Path.Combine(FIL_OUT, "FRPG_Compute_ResolveCB.cpo"),           "ComputeMain", "cs_5_0", d);
        }


        // ----------------------------------------------------------------
        // FlverPBL Vertex Shaders — all 676 VPO, data-driven from reference
        // ----------------------------------------------------------------
        public void BuildFlverPBLVS()
        {
            Log("Building FlverPBL VS (676 VPO)...");

            // Base defines common to all VPO
            string[] vsBase = { "_WIN32=1", "_DX11=1", "WITH_ClipPlane" };

            // Family → (VS source file, extra family defines)
            var famVS = new Dictionary<string, (string fx, string[] extra)>(StringComparer.Ordinal)
            {
                ["FRPG_Phn"]       = ("FRPG_VS_FlverPBL.fx", Array.Empty<string>()),
                ["FRPG_Gst"]       = ("FRPG_VS_FlverPBL.fx", new[]{"WITH_GhostMap"}),
                ["FRPG_NtoA"]      = ("FRPG_VS_FlverPBL.fx", new[]{"WITH_NtoA"}),
                ["FRPG_Ghost"]     = ("FRPG_VS_FlverPBL.fx", new[]{"WITH_Ghost","WITH_BumpMap"}),
                ["FRPG_Wind"]      = ("FRPG_VS_Wind.fx",      Array.Empty<string>()),
                ["FRPG_Ivy"]       = ("FRPG_VS_Ivy.fx",       Array.Empty<string>()),
                ["FRPG_Inst"]      = ("FRPG_VS_FlverPBL.fx",  new[]{"WITH_INSTANCE"}),
                ["FRPG_Inst_Ivy"]  = ("FRPG_VS_Ivy.fx",       new[]{"WITH_INSTANCE"}),
                ["FRPG_Inst_Wind"] = ("FRPG_VS_Wind.fx",       new[]{"WITH_INSTANCE"}),
                ["FRPG_Inst_WWS"]  = ("FRPG_VS_WWS_WaterWave.fx", new[]{"WITH_INSTANCE"}),
                ["FRPG_Sfx"]       = ("FRPG_VS_Sfx.fx",       Array.Empty<string>()),
                ["FRPG_WWS"]       = ("FRPG_VS_WWS_WaterWave.fx", Array.Empty<string>()),
                ["FRPG_Dbg"]       = ("FRPG_VS_Dbg.fx",       Array.Empty<string>()),
                ["FRPG_Dbg_Snow"]  = ("FRPG_VS_Dbg_Snow.fx",  Array.Empty<string>()),
                ["FRPG_Snow"]      = ("FRPG_VS_Snow.fx",       Array.Empty<string>()),
                ["FRPG_Water"]     = ("FRPG_VS_Water.fx",      Array.Empty<string>()),
            };

            // VPO names are hardcoded — no dependency on reference folder at runtime.
            // Generated from reference\DSR_Windows\FRPG_FlverPBL_vpo_DX11 (676 files).
            var allVpos = new List<string>
            {
                "FRPG_Dbg_PIN_D_Nrm.vpo",
                "FRPG_Dbg_PIN_D_PntNum.vpo",
                "FRPG_Dbg_PIN_DD_Nrm.vpo",
                "FRPG_Dbg_PIN_DD_PntNum.vpo",
                "FRPG_Dbg_PIN_DDL_Nrm.vpo",
                "FRPG_Dbg_PIN_DDL_PntNum.vpo",
                "FRPG_Dbg_PIN_DL_Nrm.vpo",
                "FRPG_Dbg_PIN_DL_PntNum.vpo",
                "FRPG_Dbg_PINT_D_Nrm.vpo",
                "FRPG_Dbg_PINT_D_PntNum.vpo",
                "FRPG_Dbg_PINT_DL_Nrm.vpo",
                "FRPG_Dbg_PINT_DL_PntNum.vpo",
                "FRPG_Dbg_PINTT_DD_Nrm.vpo",
                "FRPG_Dbg_PINTT_DD_PntNum.vpo",
                "FRPG_Dbg_PINTT_DDL_Nrm.vpo",
                "FRPG_Dbg_PINTT_DDL_PntNum.vpo",
                "FRPG_Dbg_PIWN_D_Nrm.vpo",
                "FRPG_Dbg_PIWN_D_PntNum.vpo",
                "FRPG_Dbg_PIWN_DD_Nrm.vpo",
                "FRPG_Dbg_PIWN_DD_PntNum.vpo",
                "FRPG_Dbg_PIWN_DDL_Nrm.vpo",
                "FRPG_Dbg_PIWN_DDL_PntNum.vpo",
                "FRPG_Dbg_PIWN_DL_Nrm.vpo",
                "FRPG_Dbg_PIWN_DL_PntNum.vpo",
                "FRPG_Dbg_PIWNT_D_Nrm.vpo",
                "FRPG_Dbg_PIWNT_D_PntNum.vpo",
                "FRPG_Dbg_PIWNT_DL_Nrm.vpo",
                "FRPG_Dbg_PIWNT_DL_PntNum.vpo",
                "FRPG_Dbg_PIWNTT_DD_Nrm.vpo",
                "FRPG_Dbg_PIWNTT_DD_PntNum.vpo",
                "FRPG_Dbg_PIWNTT_DDL_Nrm.vpo",
                "FRPG_Dbg_PIWNTT_DDL_PntNum.vpo",
                "FRPG_Dbg_Snow_D_Nrm.vpo",
                "FRPG_Dbg_Snow_DL_Nrm.vpo",
                "FRPG_Dbg_Snow_Skin_D_Nrm.vpo",
                "FRPG_Dbg_Snow_Skin_DL_Nrm.vpo",
                "FRPG_Ghost_Skin.vpo",
                "FRPG_Ghost_Tod.vpo",
                "FRPG_Gst_PIN_D_Non.vpo",
                "FRPG_Gst_PIN_D_Sdw.vpo",
                "FRPG_Gst_PIN_DD_Non.vpo",
                "FRPG_Gst_PIN_DD_Sdw.vpo",
                "FRPG_Gst_PIN_DDL_Non.vpo",
                "FRPG_Gst_PIN_DDL_Sdw.vpo",
                "FRPG_Gst_PIN_DL_Non.vpo",
                "FRPG_Gst_PIN_DL_Sdw.vpo",
                "FRPG_Gst_PINT_D_Non.vpo",
                "FRPG_Gst_PINT_D_Sdw.vpo",
                "FRPG_Gst_PINT_DL_Non.vpo",
                "FRPG_Gst_PINT_DL_Sdw.vpo",
                "FRPG_Gst_PINTT_DD_Non.vpo",
                "FRPG_Gst_PINTT_DD_Sdw.vpo",
                "FRPG_Gst_PINTT_DDL_Non.vpo",
                "FRPG_Gst_PINTT_DDL_Sdw.vpo",
                "FRPG_Gst_PIWN_D_Non.vpo",
                "FRPG_Gst_PIWN_D_Sdw.vpo",
                "FRPG_Gst_PIWN_DD_Non.vpo",
                "FRPG_Gst_PIWN_DD_Sdw.vpo",
                "FRPG_Gst_PIWN_DDL_Non.vpo",
                "FRPG_Gst_PIWN_DDL_Sdw.vpo",
                "FRPG_Gst_PIWN_DL_Non.vpo",
                "FRPG_Gst_PIWN_DL_Sdw.vpo",
                "FRPG_Gst_PIWNT_D_Non.vpo",
                "FRPG_Gst_PIWNT_D_Sdw.vpo",
                "FRPG_Gst_PIWNT_DL_Non.vpo",
                "FRPG_Gst_PIWNT_DL_Sdw.vpo",
                "FRPG_Gst_PIWNTT_DD_Non.vpo",
                "FRPG_Gst_PIWNTT_DD_Sdw.vpo",
                "FRPG_Gst_PIWNTT_DDL_Non.vpo",
                "FRPG_Gst_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIN_D_Dep.vpo",
                "FRPG_Inst_Ivy_PIN_D_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIN_D_Non.vpo",
                "FRPG_Inst_Ivy_PIN_D_Sdw.vpo",
                "FRPG_Inst_Ivy_PIN_D_Vel.vpo",
                "FRPG_Inst_Ivy_PIN_D_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIN_DD_Dep.vpo",
                "FRPG_Inst_Ivy_PIN_DD_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIN_DD_Non.vpo",
                "FRPG_Inst_Ivy_PIN_DD_Sdw.vpo",
                "FRPG_Inst_Ivy_PIN_DD_Vel.vpo",
                "FRPG_Inst_Ivy_PIN_DD_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIN_DDL_Dep.vpo",
                "FRPG_Inst_Ivy_PIN_DDL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIN_DDL_Non.vpo",
                "FRPG_Inst_Ivy_PIN_DDL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIN_DDL_Vel.vpo",
                "FRPG_Inst_Ivy_PIN_DDL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIN_DL_Dep.vpo",
                "FRPG_Inst_Ivy_PIN_DL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIN_DL_Non.vpo",
                "FRPG_Inst_Ivy_PIN_DL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIN_DL_Vel.vpo",
                "FRPG_Inst_Ivy_PIN_DL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PINT_D_Dep.vpo",
                "FRPG_Inst_Ivy_PINT_D_DepAlp.vpo",
                "FRPG_Inst_Ivy_PINT_D_Non.vpo",
                "FRPG_Inst_Ivy_PINT_D_Sdw.vpo",
                "FRPG_Inst_Ivy_PINT_D_Vel.vpo",
                "FRPG_Inst_Ivy_PINT_D_VelAlp.vpo",
                "FRPG_Inst_Ivy_PINT_DL_Dep.vpo",
                "FRPG_Inst_Ivy_PINT_DL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PINT_DL_Non.vpo",
                "FRPG_Inst_Ivy_PINT_DL_Sdw.vpo",
                "FRPG_Inst_Ivy_PINT_DL_Vel.vpo",
                "FRPG_Inst_Ivy_PINT_DL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PINTT_DD_Dep.vpo",
                "FRPG_Inst_Ivy_PINTT_DD_DepAlp.vpo",
                "FRPG_Inst_Ivy_PINTT_DD_Non.vpo",
                "FRPG_Inst_Ivy_PINTT_DD_Sdw.vpo",
                "FRPG_Inst_Ivy_PINTT_DD_Vel.vpo",
                "FRPG_Inst_Ivy_PINTT_DD_VelAlp.vpo",
                "FRPG_Inst_Ivy_PINTT_DDL_Dep.vpo",
                "FRPG_Inst_Ivy_PINTT_DDL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PINTT_DDL_Non.vpo",
                "FRPG_Inst_Ivy_PINTT_DDL_Sdw.vpo",
                "FRPG_Inst_Ivy_PINTT_DDL_Vel.vpo",
                "FRPG_Inst_Ivy_PINTT_DDL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_D_Dep.vpo",
                "FRPG_Inst_Ivy_PIWN_D_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_D_Non.vpo",
                "FRPG_Inst_Ivy_PIWN_D_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWN_D_Vel.vpo",
                "FRPG_Inst_Ivy_PIWN_D_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_DD_Dep.vpo",
                "FRPG_Inst_Ivy_PIWN_DD_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_DD_Non.vpo",
                "FRPG_Inst_Ivy_PIWN_DD_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWN_DD_Vel.vpo",
                "FRPG_Inst_Ivy_PIWN_DD_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_DDL_Dep.vpo",
                "FRPG_Inst_Ivy_PIWN_DDL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_DDL_Non.vpo",
                "FRPG_Inst_Ivy_PIWN_DDL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWN_DDL_Vel.vpo",
                "FRPG_Inst_Ivy_PIWN_DDL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_DL_Dep.vpo",
                "FRPG_Inst_Ivy_PIWN_DL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWN_DL_Non.vpo",
                "FRPG_Inst_Ivy_PIWN_DL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWN_DL_Vel.vpo",
                "FRPG_Inst_Ivy_PIWN_DL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWNT_D_Dep.vpo",
                "FRPG_Inst_Ivy_PIWNT_D_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWNT_D_Non.vpo",
                "FRPG_Inst_Ivy_PIWNT_D_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWNT_D_Vel.vpo",
                "FRPG_Inst_Ivy_PIWNT_D_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWNT_DL_Dep.vpo",
                "FRPG_Inst_Ivy_PIWNT_DL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWNT_DL_Non.vpo",
                "FRPG_Inst_Ivy_PIWNT_DL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWNT_DL_Vel.vpo",
                "FRPG_Inst_Ivy_PIWNT_DL_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DD_Dep.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DD_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DD_Non.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DD_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DD_Vel.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DD_VelAlp.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DDL_Dep.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DDL_DepAlp.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DDL_Non.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DDL_Vel.vpo",
                "FRPG_Inst_Ivy_PIWNTT_DDL_VelAlp.vpo",
                "FRPG_Inst_Phn_PIN_D_Dep.vpo",
                "FRPG_Inst_Phn_PIN_D_DepAlp.vpo",
                "FRPG_Inst_Phn_PIN_D_Non.vpo",
                "FRPG_Inst_Phn_PIN_D_Sdw.vpo",
                "FRPG_Inst_Phn_PIN_D_Vel.vpo",
                "FRPG_Inst_Phn_PIN_D_VelAlp.vpo",
                "FRPG_Inst_Phn_PIN_DD_Dep.vpo",
                "FRPG_Inst_Phn_PIN_DD_DepAlp.vpo",
                "FRPG_Inst_Phn_PIN_DD_Non.vpo",
                "FRPG_Inst_Phn_PIN_DD_Sdw.vpo",
                "FRPG_Inst_Phn_PIN_DD_Vel.vpo",
                "FRPG_Inst_Phn_PIN_DD_VelAlp.vpo",
                "FRPG_Inst_Phn_PIN_DDL_Dep.vpo",
                "FRPG_Inst_Phn_PIN_DDL_DepAlp.vpo",
                "FRPG_Inst_Phn_PIN_DDL_Non.vpo",
                "FRPG_Inst_Phn_PIN_DDL_Sdw.vpo",
                "FRPG_Inst_Phn_PIN_DDL_Vel.vpo",
                "FRPG_Inst_Phn_PIN_DDL_VelAlp.vpo",
                "FRPG_Inst_Phn_PIN_DL_Dep.vpo",
                "FRPG_Inst_Phn_PIN_DL_DepAlp.vpo",
                "FRPG_Inst_Phn_PIN_DL_Non.vpo",
                "FRPG_Inst_Phn_PIN_DL_Sdw.vpo",
                "FRPG_Inst_Phn_PIN_DL_Vel.vpo",
                "FRPG_Inst_Phn_PIN_DL_VelAlp.vpo",
                "FRPG_Inst_Phn_PINT_D_Dep.vpo",
                "FRPG_Inst_Phn_PINT_D_DepAlp.vpo",
                "FRPG_Inst_Phn_PINT_D_Non.vpo",
                "FRPG_Inst_Phn_PINT_D_Sdw.vpo",
                "FRPG_Inst_Phn_PINT_D_Vel.vpo",
                "FRPG_Inst_Phn_PINT_D_VelAlp.vpo",
                "FRPG_Inst_Phn_PINT_DL_Dep.vpo",
                "FRPG_Inst_Phn_PINT_DL_DepAlp.vpo",
                "FRPG_Inst_Phn_PINT_DL_Non.vpo",
                "FRPG_Inst_Phn_PINT_DL_Sdw.vpo",
                "FRPG_Inst_Phn_PINT_DL_Vel.vpo",
                "FRPG_Inst_Phn_PINT_DL_VelAlp.vpo",
                "FRPG_Inst_Phn_PINTT_DD_Dep.vpo",
                "FRPG_Inst_Phn_PINTT_DD_DepAlp.vpo",
                "FRPG_Inst_Phn_PINTT_DD_Non.vpo",
                "FRPG_Inst_Phn_PINTT_DD_Sdw.vpo",
                "FRPG_Inst_Phn_PINTT_DD_Vel.vpo",
                "FRPG_Inst_Phn_PINTT_DD_VelAlp.vpo",
                "FRPG_Inst_Phn_PINTT_DDL_Dep.vpo",
                "FRPG_Inst_Phn_PINTT_DDL_DepAlp.vpo",
                "FRPG_Inst_Phn_PINTT_DDL_Non.vpo",
                "FRPG_Inst_Phn_PINTT_DDL_Sdw.vpo",
                "FRPG_Inst_Phn_PINTT_DDL_Vel.vpo",
                "FRPG_Inst_Phn_PINTT_DDL_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWN_D_Dep.vpo",
                "FRPG_Inst_Phn_PIWN_D_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWN_D_Non.vpo",
                "FRPG_Inst_Phn_PIWN_D_Sdw.vpo",
                "FRPG_Inst_Phn_PIWN_D_Vel.vpo",
                "FRPG_Inst_Phn_PIWN_D_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWN_DD_Dep.vpo",
                "FRPG_Inst_Phn_PIWN_DD_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWN_DD_Non.vpo",
                "FRPG_Inst_Phn_PIWN_DD_Sdw.vpo",
                "FRPG_Inst_Phn_PIWN_DD_Vel.vpo",
                "FRPG_Inst_Phn_PIWN_DD_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWN_DDL_Dep.vpo",
                "FRPG_Inst_Phn_PIWN_DDL_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWN_DDL_Non.vpo",
                "FRPG_Inst_Phn_PIWN_DDL_Sdw.vpo",
                "FRPG_Inst_Phn_PIWN_DDL_Vel.vpo",
                "FRPG_Inst_Phn_PIWN_DDL_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWN_DL_Dep.vpo",
                "FRPG_Inst_Phn_PIWN_DL_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWN_DL_Non.vpo",
                "FRPG_Inst_Phn_PIWN_DL_Sdw.vpo",
                "FRPG_Inst_Phn_PIWN_DL_Vel.vpo",
                "FRPG_Inst_Phn_PIWN_DL_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWNT_D_Dep.vpo",
                "FRPG_Inst_Phn_PIWNT_D_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWNT_D_Non.vpo",
                "FRPG_Inst_Phn_PIWNT_D_Sdw.vpo",
                "FRPG_Inst_Phn_PIWNT_D_Vel.vpo",
                "FRPG_Inst_Phn_PIWNT_D_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWNT_DL_Dep.vpo",
                "FRPG_Inst_Phn_PIWNT_DL_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWNT_DL_Non.vpo",
                "FRPG_Inst_Phn_PIWNT_DL_Sdw.vpo",
                "FRPG_Inst_Phn_PIWNT_DL_Vel.vpo",
                "FRPG_Inst_Phn_PIWNT_DL_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWNTT_DD_Dep.vpo",
                "FRPG_Inst_Phn_PIWNTT_DD_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWNTT_DD_Non.vpo",
                "FRPG_Inst_Phn_PIWNTT_DD_Sdw.vpo",
                "FRPG_Inst_Phn_PIWNTT_DD_Vel.vpo",
                "FRPG_Inst_Phn_PIWNTT_DD_VelAlp.vpo",
                "FRPG_Inst_Phn_PIWNTT_DDL_Dep.vpo",
                "FRPG_Inst_Phn_PIWNTT_DDL_DepAlp.vpo",
                "FRPG_Inst_Phn_PIWNTT_DDL_Non.vpo",
                "FRPG_Inst_Phn_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Inst_Phn_PIWNTT_DDL_Vel.vpo",
                "FRPG_Inst_Phn_PIWNTT_DDL_VelAlp.vpo",
                "FRPG_Inst_Wind_PIN_D_Dep.vpo",
                "FRPG_Inst_Wind_PIN_D_DepAlp.vpo",
                "FRPG_Inst_Wind_PIN_D_Non.vpo",
                "FRPG_Inst_Wind_PIN_D_Sdw.vpo",
                "FRPG_Inst_Wind_PIN_D_Vel.vpo",
                "FRPG_Inst_Wind_PIN_D_VelAlp.vpo",
                "FRPG_Inst_Wind_PIN_DD_Dep.vpo",
                "FRPG_Inst_Wind_PIN_DD_DepAlp.vpo",
                "FRPG_Inst_Wind_PIN_DD_Non.vpo",
                "FRPG_Inst_Wind_PIN_DD_Sdw.vpo",
                "FRPG_Inst_Wind_PIN_DD_Vel.vpo",
                "FRPG_Inst_Wind_PIN_DD_VelAlp.vpo",
                "FRPG_Inst_Wind_PIN_DDL_Dep.vpo",
                "FRPG_Inst_Wind_PIN_DDL_DepAlp.vpo",
                "FRPG_Inst_Wind_PIN_DDL_Non.vpo",
                "FRPG_Inst_Wind_PIN_DDL_Sdw.vpo",
                "FRPG_Inst_Wind_PIN_DDL_Vel.vpo",
                "FRPG_Inst_Wind_PIN_DDL_VelAlp.vpo",
                "FRPG_Inst_Wind_PIN_DL_Dep.vpo",
                "FRPG_Inst_Wind_PIN_DL_DepAlp.vpo",
                "FRPG_Inst_Wind_PIN_DL_Non.vpo",
                "FRPG_Inst_Wind_PIN_DL_Sdw.vpo",
                "FRPG_Inst_Wind_PIN_DL_Vel.vpo",
                "FRPG_Inst_Wind_PIN_DL_VelAlp.vpo",
                "FRPG_Inst_Wind_PINT_D_Dep.vpo",
                "FRPG_Inst_Wind_PINT_D_DepAlp.vpo",
                "FRPG_Inst_Wind_PINT_D_Non.vpo",
                "FRPG_Inst_Wind_PINT_D_Sdw.vpo",
                "FRPG_Inst_Wind_PINT_D_Vel.vpo",
                "FRPG_Inst_Wind_PINT_D_VelAlp.vpo",
                "FRPG_Inst_Wind_PINT_DL_Dep.vpo",
                "FRPG_Inst_Wind_PINT_DL_DepAlp.vpo",
                "FRPG_Inst_Wind_PINT_DL_Non.vpo",
                "FRPG_Inst_Wind_PINT_DL_Sdw.vpo",
                "FRPG_Inst_Wind_PINT_DL_Vel.vpo",
                "FRPG_Inst_Wind_PINT_DL_VelAlp.vpo",
                "FRPG_Inst_Wind_PINTT_DD_Dep.vpo",
                "FRPG_Inst_Wind_PINTT_DD_DepAlp.vpo",
                "FRPG_Inst_Wind_PINTT_DD_Non.vpo",
                "FRPG_Inst_Wind_PINTT_DD_Sdw.vpo",
                "FRPG_Inst_Wind_PINTT_DD_Vel.vpo",
                "FRPG_Inst_Wind_PINTT_DD_VelAlp.vpo",
                "FRPG_Inst_Wind_PINTT_DDL_Dep.vpo",
                "FRPG_Inst_Wind_PINTT_DDL_DepAlp.vpo",
                "FRPG_Inst_Wind_PINTT_DDL_Non.vpo",
                "FRPG_Inst_Wind_PINTT_DDL_Sdw.vpo",
                "FRPG_Inst_Wind_PINTT_DDL_Vel.vpo",
                "FRPG_Inst_Wind_PINTT_DDL_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWN_D_Dep.vpo",
                "FRPG_Inst_Wind_PIWN_D_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWN_D_Non.vpo",
                "FRPG_Inst_Wind_PIWN_D_Sdw.vpo",
                "FRPG_Inst_Wind_PIWN_D_Vel.vpo",
                "FRPG_Inst_Wind_PIWN_D_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWN_DD_Dep.vpo",
                "FRPG_Inst_Wind_PIWN_DD_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWN_DD_Non.vpo",
                "FRPG_Inst_Wind_PIWN_DD_Sdw.vpo",
                "FRPG_Inst_Wind_PIWN_DD_Vel.vpo",
                "FRPG_Inst_Wind_PIWN_DD_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWN_DDL_Dep.vpo",
                "FRPG_Inst_Wind_PIWN_DDL_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWN_DDL_Non.vpo",
                "FRPG_Inst_Wind_PIWN_DDL_Sdw.vpo",
                "FRPG_Inst_Wind_PIWN_DDL_Vel.vpo",
                "FRPG_Inst_Wind_PIWN_DDL_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWN_DL_Dep.vpo",
                "FRPG_Inst_Wind_PIWN_DL_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWN_DL_Non.vpo",
                "FRPG_Inst_Wind_PIWN_DL_Sdw.vpo",
                "FRPG_Inst_Wind_PIWN_DL_Vel.vpo",
                "FRPG_Inst_Wind_PIWN_DL_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWNT_D_Dep.vpo",
                "FRPG_Inst_Wind_PIWNT_D_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWNT_D_Non.vpo",
                "FRPG_Inst_Wind_PIWNT_D_Sdw.vpo",
                "FRPG_Inst_Wind_PIWNT_D_Vel.vpo",
                "FRPG_Inst_Wind_PIWNT_D_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWNT_DL_Dep.vpo",
                "FRPG_Inst_Wind_PIWNT_DL_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWNT_DL_Non.vpo",
                "FRPG_Inst_Wind_PIWNT_DL_Sdw.vpo",
                "FRPG_Inst_Wind_PIWNT_DL_Vel.vpo",
                "FRPG_Inst_Wind_PIWNT_DL_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWNTT_DD_Dep.vpo",
                "FRPG_Inst_Wind_PIWNTT_DD_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWNTT_DD_Non.vpo",
                "FRPG_Inst_Wind_PIWNTT_DD_Sdw.vpo",
                "FRPG_Inst_Wind_PIWNTT_DD_Vel.vpo",
                "FRPG_Inst_Wind_PIWNTT_DD_VelAlp.vpo",
                "FRPG_Inst_Wind_PIWNTT_DDL_Dep.vpo",
                "FRPG_Inst_Wind_PIWNTT_DDL_DepAlp.vpo",
                "FRPG_Inst_Wind_PIWNTT_DDL_Non.vpo",
                "FRPG_Inst_Wind_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Inst_Wind_PIWNTT_DDL_Vel.vpo",
                "FRPG_Inst_Wind_PIWNTT_DDL_VelAlp.vpo",
                "FRPG_Inst_WWS_PIN_D_WaterWave.vpo",
                "FRPG_Inst_WWS_PIN_DD_WaterWave.vpo",
                "FRPG_Inst_WWS_PIWN_D_WaterWave.vpo",
                "FRPG_Inst_WWS_PIWN_DD_WaterWave.vpo",
                "FRPG_Ivy_PIN_D_Dep.vpo",
                "FRPG_Ivy_PIN_D_DepAlp.vpo",
                "FRPG_Ivy_PIN_D_Non.vpo",
                "FRPG_Ivy_PIN_D_Sdw.vpo",
                "FRPG_Ivy_PIN_D_Vel.vpo",
                "FRPG_Ivy_PIN_D_VelAlp.vpo",
                "FRPG_Ivy_PIN_DD_Dep.vpo",
                "FRPG_Ivy_PIN_DD_DepAlp.vpo",
                "FRPG_Ivy_PIN_DD_Non.vpo",
                "FRPG_Ivy_PIN_DD_Sdw.vpo",
                "FRPG_Ivy_PIN_DD_Vel.vpo",
                "FRPG_Ivy_PIN_DD_VelAlp.vpo",
                "FRPG_Ivy_PIN_DDL_Dep.vpo",
                "FRPG_Ivy_PIN_DDL_DepAlp.vpo",
                "FRPG_Ivy_PIN_DDL_Non.vpo",
                "FRPG_Ivy_PIN_DDL_Sdw.vpo",
                "FRPG_Ivy_PIN_DDL_Vel.vpo",
                "FRPG_Ivy_PIN_DDL_VelAlp.vpo",
                "FRPG_Ivy_PIN_DL_Dep.vpo",
                "FRPG_Ivy_PIN_DL_DepAlp.vpo",
                "FRPG_Ivy_PIN_DL_Non.vpo",
                "FRPG_Ivy_PIN_DL_Sdw.vpo",
                "FRPG_Ivy_PIN_DL_Vel.vpo",
                "FRPG_Ivy_PIN_DL_VelAlp.vpo",
                "FRPG_Ivy_PINT_D_Dep.vpo",
                "FRPG_Ivy_PINT_D_DepAlp.vpo",
                "FRPG_Ivy_PINT_D_Non.vpo",
                "FRPG_Ivy_PINT_D_Sdw.vpo",
                "FRPG_Ivy_PINT_D_Vel.vpo",
                "FRPG_Ivy_PINT_D_VelAlp.vpo",
                "FRPG_Ivy_PINT_DL_Dep.vpo",
                "FRPG_Ivy_PINT_DL_DepAlp.vpo",
                "FRPG_Ivy_PINT_DL_Non.vpo",
                "FRPG_Ivy_PINT_DL_Sdw.vpo",
                "FRPG_Ivy_PINT_DL_Vel.vpo",
                "FRPG_Ivy_PINT_DL_VelAlp.vpo",
                "FRPG_Ivy_PINTT_DD_Dep.vpo",
                "FRPG_Ivy_PINTT_DD_DepAlp.vpo",
                "FRPG_Ivy_PINTT_DD_Non.vpo",
                "FRPG_Ivy_PINTT_DD_Sdw.vpo",
                "FRPG_Ivy_PINTT_DD_Vel.vpo",
                "FRPG_Ivy_PINTT_DD_VelAlp.vpo",
                "FRPG_Ivy_PINTT_DDL_Dep.vpo",
                "FRPG_Ivy_PINTT_DDL_DepAlp.vpo",
                "FRPG_Ivy_PINTT_DDL_Non.vpo",
                "FRPG_Ivy_PINTT_DDL_Sdw.vpo",
                "FRPG_Ivy_PINTT_DDL_Vel.vpo",
                "FRPG_Ivy_PINTT_DDL_VelAlp.vpo",
                "FRPG_Ivy_PIWN_D_Dep.vpo",
                "FRPG_Ivy_PIWN_D_DepAlp.vpo",
                "FRPG_Ivy_PIWN_D_Non.vpo",
                "FRPG_Ivy_PIWN_D_Sdw.vpo",
                "FRPG_Ivy_PIWN_D_Vel.vpo",
                "FRPG_Ivy_PIWN_D_VelAlp.vpo",
                "FRPG_Ivy_PIWN_DD_Dep.vpo",
                "FRPG_Ivy_PIWN_DD_DepAlp.vpo",
                "FRPG_Ivy_PIWN_DD_Non.vpo",
                "FRPG_Ivy_PIWN_DD_Sdw.vpo",
                "FRPG_Ivy_PIWN_DD_Vel.vpo",
                "FRPG_Ivy_PIWN_DD_VelAlp.vpo",
                "FRPG_Ivy_PIWN_DDL_Dep.vpo",
                "FRPG_Ivy_PIWN_DDL_DepAlp.vpo",
                "FRPG_Ivy_PIWN_DDL_Non.vpo",
                "FRPG_Ivy_PIWN_DDL_Sdw.vpo",
                "FRPG_Ivy_PIWN_DDL_Vel.vpo",
                "FRPG_Ivy_PIWN_DDL_VelAlp.vpo",
                "FRPG_Ivy_PIWN_DL_Dep.vpo",
                "FRPG_Ivy_PIWN_DL_DepAlp.vpo",
                "FRPG_Ivy_PIWN_DL_Non.vpo",
                "FRPG_Ivy_PIWN_DL_Sdw.vpo",
                "FRPG_Ivy_PIWN_DL_Vel.vpo",
                "FRPG_Ivy_PIWN_DL_VelAlp.vpo",
                "FRPG_Ivy_PIWNT_D_Dep.vpo",
                "FRPG_Ivy_PIWNT_D_DepAlp.vpo",
                "FRPG_Ivy_PIWNT_D_Non.vpo",
                "FRPG_Ivy_PIWNT_D_Sdw.vpo",
                "FRPG_Ivy_PIWNT_D_Vel.vpo",
                "FRPG_Ivy_PIWNT_D_VelAlp.vpo",
                "FRPG_Ivy_PIWNT_DL_Dep.vpo",
                "FRPG_Ivy_PIWNT_DL_DepAlp.vpo",
                "FRPG_Ivy_PIWNT_DL_Non.vpo",
                "FRPG_Ivy_PIWNT_DL_Sdw.vpo",
                "FRPG_Ivy_PIWNT_DL_Vel.vpo",
                "FRPG_Ivy_PIWNT_DL_VelAlp.vpo",
                "FRPG_Ivy_PIWNTT_DD_Dep.vpo",
                "FRPG_Ivy_PIWNTT_DD_DepAlp.vpo",
                "FRPG_Ivy_PIWNTT_DD_Non.vpo",
                "FRPG_Ivy_PIWNTT_DD_Sdw.vpo",
                "FRPG_Ivy_PIWNTT_DD_Vel.vpo",
                "FRPG_Ivy_PIWNTT_DD_VelAlp.vpo",
                "FRPG_Ivy_PIWNTT_DDL_Dep.vpo",
                "FRPG_Ivy_PIWNTT_DDL_DepAlp.vpo",
                "FRPG_Ivy_PIWNTT_DDL_Non.vpo",
                "FRPG_Ivy_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Ivy_PIWNTT_DDL_Vel.vpo",
                "FRPG_Ivy_PIWNTT_DDL_VelAlp.vpo",
                "FRPG_NtoA_PIN_Dep.vpo",
                "FRPG_NtoA_PIN_Non.vpo",
                "FRPG_NtoA_PIN_sdw.vpo",
                "FRPG_NtoA_PIWN_Dep.vpo",
                "FRPG_NtoA_PIWN_Non.vpo",
                "FRPG_NtoA_PIWN_sdw.vpo",
                "FRPG_Phn_PIN_D_Dep.vpo",
                "FRPG_Phn_PIN_D_DepAlp.vpo",
                "FRPG_Phn_PIN_D_Non.vpo",
                "FRPG_Phn_PIN_D_Sdw.vpo",
                "FRPG_Phn_PIN_D_Vel.vpo",
                "FRPG_Phn_PIN_D_VelAlp.vpo",
                "FRPG_Phn_PIN_DD_Dep.vpo",
                "FRPG_Phn_PIN_DD_DepAlp.vpo",
                "FRPG_Phn_PIN_DD_Non.vpo",
                "FRPG_Phn_PIN_DD_Sdw.vpo",
                "FRPG_Phn_PIN_DD_Vel.vpo",
                "FRPG_Phn_PIN_DD_VelAlp.vpo",
                "FRPG_Phn_PIN_DDL_Dep.vpo",
                "FRPG_Phn_PIN_DDL_DepAlp.vpo",
                "FRPG_Phn_PIN_DDL_Non.vpo",
                "FRPG_Phn_PIN_DDL_Sdw.vpo",
                "FRPG_Phn_PIN_DDL_Vel.vpo",
                "FRPG_Phn_PIN_DDL_VelAlp.vpo",
                "FRPG_Phn_PIN_DL_Dep.vpo",
                "FRPG_Phn_PIN_DL_DepAlp.vpo",
                "FRPG_Phn_PIN_DL_Non.vpo",
                "FRPG_Phn_PIN_DL_Sdw.vpo",
                "FRPG_Phn_PIN_DL_Vel.vpo",
                "FRPG_Phn_PIN_DL_VelAlp.vpo",
                "FRPG_Phn_PINT_D_Dep.vpo",
                "FRPG_Phn_PINT_D_DepAlp.vpo",
                "FRPG_Phn_PINT_D_Non.vpo",
                "FRPG_Phn_PINT_D_Sdw.vpo",
                "FRPG_Phn_PINT_D_Vel.vpo",
                "FRPG_Phn_PINT_D_VelAlp.vpo",
                "FRPG_Phn_PINT_DL_Dep.vpo",
                "FRPG_Phn_PINT_DL_DepAlp.vpo",
                "FRPG_Phn_PINT_DL_Non.vpo",
                "FRPG_Phn_PINT_DL_Sdw.vpo",
                "FRPG_Phn_PINT_DL_Vel.vpo",
                "FRPG_Phn_PINT_DL_VelAlp.vpo",
                "FRPG_Phn_PINTT_DD_Dep.vpo",
                "FRPG_Phn_PINTT_DD_DepAlp.vpo",
                "FRPG_Phn_PINTT_DD_Non.vpo",
                "FRPG_Phn_PINTT_DD_Sdw.vpo",
                "FRPG_Phn_PINTT_DD_Vel.vpo",
                "FRPG_Phn_PINTT_DD_VelAlp.vpo",
                "FRPG_Phn_PINTT_DDL_Dep.vpo",
                "FRPG_Phn_PINTT_DDL_DepAlp.vpo",
                "FRPG_Phn_PINTT_DDL_Non.vpo",
                "FRPG_Phn_PINTT_DDL_Sdw.vpo",
                "FRPG_Phn_PINTT_DDL_Vel.vpo",
                "FRPG_Phn_PINTT_DDL_VelAlp.vpo",
                "FRPG_Phn_PIWN_D_Dep.vpo",
                "FRPG_Phn_PIWN_D_DepAlp.vpo",
                "FRPG_Phn_PIWN_D_Non.vpo",
                "FRPG_Phn_PIWN_D_Sdw.vpo",
                "FRPG_Phn_PIWN_D_Vel.vpo",
                "FRPG_Phn_PIWN_D_VelAlp.vpo",
                "FRPG_Phn_PIWN_DD_Dep.vpo",
                "FRPG_Phn_PIWN_DD_DepAlp.vpo",
                "FRPG_Phn_PIWN_DD_Non.vpo",
                "FRPG_Phn_PIWN_DD_Sdw.vpo",
                "FRPG_Phn_PIWN_DD_Vel.vpo",
                "FRPG_Phn_PIWN_DD_VelAlp.vpo",
                "FRPG_Phn_PIWN_DDL_Dep.vpo",
                "FRPG_Phn_PIWN_DDL_DepAlp.vpo",
                "FRPG_Phn_PIWN_DDL_Non.vpo",
                "FRPG_Phn_PIWN_DDL_Sdw.vpo",
                "FRPG_Phn_PIWN_DDL_Vel.vpo",
                "FRPG_Phn_PIWN_DDL_VelAlp.vpo",
                "FRPG_Phn_PIWN_DL_Dep.vpo",
                "FRPG_Phn_PIWN_DL_DepAlp.vpo",
                "FRPG_Phn_PIWN_DL_Non.vpo",
                "FRPG_Phn_PIWN_DL_Sdw.vpo",
                "FRPG_Phn_PIWN_DL_Vel.vpo",
                "FRPG_Phn_PIWN_DL_VelAlp.vpo",
                "FRPG_Phn_PIWNT_D_Dep.vpo",
                "FRPG_Phn_PIWNT_D_DepAlp.vpo",
                "FRPG_Phn_PIWNT_D_Non.vpo",
                "FRPG_Phn_PIWNT_D_Sdw.vpo",
                "FRPG_Phn_PIWNT_D_Vel.vpo",
                "FRPG_Phn_PIWNT_D_VelAlp.vpo",
                "FRPG_Phn_PIWNT_DL_Dep.vpo",
                "FRPG_Phn_PIWNT_DL_DepAlp.vpo",
                "FRPG_Phn_PIWNT_DL_Non.vpo",
                "FRPG_Phn_PIWNT_DL_Sdw.vpo",
                "FRPG_Phn_PIWNT_DL_Vel.vpo",
                "FRPG_Phn_PIWNT_DL_VelAlp.vpo",
                "FRPG_Phn_PIWNTT_DD_Dep.vpo",
                "FRPG_Phn_PIWNTT_DD_DepAlp.vpo",
                "FRPG_Phn_PIWNTT_DD_Non.vpo",
                "FRPG_Phn_PIWNTT_DD_Sdw.vpo",
                "FRPG_Phn_PIWNTT_DD_Vel.vpo",
                "FRPG_Phn_PIWNTT_DD_VelAlp.vpo",
                "FRPG_Phn_PIWNTT_DDL_Dep.vpo",
                "FRPG_Phn_PIWNTT_DDL_DepAlp.vpo",
                "FRPG_Phn_PIWNTT_DDL_Non.vpo",
                "FRPG_Phn_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Phn_PIWNTT_DDL_Vel.vpo",
                "FRPG_Phn_PIWNTT_DDL_VelAlp.vpo",
                "FRPG_Sfx_PIN_D.vpo",
                "FRPG_Sfx_PINT_D.vpo",
                "FRPG_Snow_______.vpo",
                "FRPG_Snow_HeightMap_Lit.vpo",
                "FRPG_Snow_HeightMap_Skin_Lit.vpo",
                "FRPG_Snow_HeightMap_Skin.vpo",
                "FRPG_Snow_HeightMap.vpo",
                "FRPG_Snow_Lit___.vpo",
                "FRPG_Snow_Skin_______.vpo",
                "FRPG_Snow_Skin_Lit___.vpo",
                "FRPG_Water_HeightMap_Skin.vpo",
                "FRPG_Water_HeightMap.vpo",
                "FRPG_Water_Mask_Skin.vpo",
                "FRPG_Water_Mask.vpo",
                "FRPG_Water_Skin.vpo",
                "FRPG_Water.vpo",
                "FRPG_Wind_PIN_D_Dep.vpo",
                "FRPG_Wind_PIN_D_DepAlp.vpo",
                "FRPG_Wind_PIN_D_Non.vpo",
                "FRPG_Wind_PIN_D_Sdw.vpo",
                "FRPG_Wind_PIN_D_Vel.vpo",
                "FRPG_Wind_PIN_D_VelAlp.vpo",
                "FRPG_Wind_PIN_DD_Dep.vpo",
                "FRPG_Wind_PIN_DD_DepAlp.vpo",
                "FRPG_Wind_PIN_DD_Non.vpo",
                "FRPG_Wind_PIN_DD_Sdw.vpo",
                "FRPG_Wind_PIN_DD_Vel.vpo",
                "FRPG_Wind_PIN_DD_VelAlp.vpo",
                "FRPG_Wind_PIN_DDL_Dep.vpo",
                "FRPG_Wind_PIN_DDL_DepAlp.vpo",
                "FRPG_Wind_PIN_DDL_Non.vpo",
                "FRPG_Wind_PIN_DDL_Sdw.vpo",
                "FRPG_Wind_PIN_DDL_Vel.vpo",
                "FRPG_Wind_PIN_DDL_VelAlp.vpo",
                "FRPG_Wind_PIN_DL_Dep.vpo",
                "FRPG_Wind_PIN_DL_DepAlp.vpo",
                "FRPG_Wind_PIN_DL_Non.vpo",
                "FRPG_Wind_PIN_DL_Sdw.vpo",
                "FRPG_Wind_PIN_DL_Vel.vpo",
                "FRPG_Wind_PIN_DL_VelAlp.vpo",
                "FRPG_Wind_PINT_D_Dep.vpo",
                "FRPG_Wind_PINT_D_DepAlp.vpo",
                "FRPG_Wind_PINT_D_Non.vpo",
                "FRPG_Wind_PINT_D_Sdw.vpo",
                "FRPG_Wind_PINT_D_Vel.vpo",
                "FRPG_Wind_PINT_D_VelAlp.vpo",
                "FRPG_Wind_PINT_DL_Dep.vpo",
                "FRPG_Wind_PINT_DL_DepAlp.vpo",
                "FRPG_Wind_PINT_DL_Non.vpo",
                "FRPG_Wind_PINT_DL_Sdw.vpo",
                "FRPG_Wind_PINT_DL_Vel.vpo",
                "FRPG_Wind_PINT_DL_VelAlp.vpo",
                "FRPG_Wind_PINTT_DD_Dep.vpo",
                "FRPG_Wind_PINTT_DD_DepAlp.vpo",
                "FRPG_Wind_PINTT_DD_Non.vpo",
                "FRPG_Wind_PINTT_DD_Sdw.vpo",
                "FRPG_Wind_PINTT_DD_Vel.vpo",
                "FRPG_Wind_PINTT_DD_VelAlp.vpo",
                "FRPG_Wind_PINTT_DDL_Dep.vpo",
                "FRPG_Wind_PINTT_DDL_DepAlp.vpo",
                "FRPG_Wind_PINTT_DDL_Non.vpo",
                "FRPG_Wind_PINTT_DDL_Sdw.vpo",
                "FRPG_Wind_PINTT_DDL_Vel.vpo",
                "FRPG_Wind_PINTT_DDL_VelAlp.vpo",
                "FRPG_Wind_PIWN_D_Dep.vpo",
                "FRPG_Wind_PIWN_D_DepAlp.vpo",
                "FRPG_Wind_PIWN_D_Non.vpo",
                "FRPG_Wind_PIWN_D_Sdw.vpo",
                "FRPG_Wind_PIWN_D_Vel.vpo",
                "FRPG_Wind_PIWN_D_VelAlp.vpo",
                "FRPG_Wind_PIWN_DD_Dep.vpo",
                "FRPG_Wind_PIWN_DD_DepAlp.vpo",
                "FRPG_Wind_PIWN_DD_Non.vpo",
                "FRPG_Wind_PIWN_DD_Sdw.vpo",
                "FRPG_Wind_PIWN_DD_Vel.vpo",
                "FRPG_Wind_PIWN_DD_VelAlp.vpo",
                "FRPG_Wind_PIWN_DDL_Dep.vpo",
                "FRPG_Wind_PIWN_DDL_DepAlp.vpo",
                "FRPG_Wind_PIWN_DDL_Non.vpo",
                "FRPG_Wind_PIWN_DDL_Sdw.vpo",
                "FRPG_Wind_PIWN_DDL_Vel.vpo",
                "FRPG_Wind_PIWN_DDL_VelAlp.vpo",
                "FRPG_Wind_PIWN_DL_Dep.vpo",
                "FRPG_Wind_PIWN_DL_DepAlp.vpo",
                "FRPG_Wind_PIWN_DL_Non.vpo",
                "FRPG_Wind_PIWN_DL_Sdw.vpo",
                "FRPG_Wind_PIWN_DL_Vel.vpo",
                "FRPG_Wind_PIWN_DL_VelAlp.vpo",
                "FRPG_Wind_PIWNT_D_Dep.vpo",
                "FRPG_Wind_PIWNT_D_DepAlp.vpo",
                "FRPG_Wind_PIWNT_D_Non.vpo",
                "FRPG_Wind_PIWNT_D_Sdw.vpo",
                "FRPG_Wind_PIWNT_D_Vel.vpo",
                "FRPG_Wind_PIWNT_D_VelAlp.vpo",
                "FRPG_Wind_PIWNT_DL_Dep.vpo",
                "FRPG_Wind_PIWNT_DL_DepAlp.vpo",
                "FRPG_Wind_PIWNT_DL_Non.vpo",
                "FRPG_Wind_PIWNT_DL_Sdw.vpo",
                "FRPG_Wind_PIWNT_DL_Vel.vpo",
                "FRPG_Wind_PIWNT_DL_VelAlp.vpo",
                "FRPG_Wind_PIWNTT_DD_Dep.vpo",
                "FRPG_Wind_PIWNTT_DD_DepAlp.vpo",
                "FRPG_Wind_PIWNTT_DD_Non.vpo",
                "FRPG_Wind_PIWNTT_DD_Sdw.vpo",
                "FRPG_Wind_PIWNTT_DD_Vel.vpo",
                "FRPG_Wind_PIWNTT_DD_VelAlp.vpo",
                "FRPG_Wind_PIWNTT_DDL_Dep.vpo",
                "FRPG_Wind_PIWNTT_DDL_DepAlp.vpo",
                "FRPG_Wind_PIWNTT_DDL_Non.vpo",
                "FRPG_Wind_PIWNTT_DDL_Sdw.vpo",
                "FRPG_Wind_PIWNTT_DDL_Vel.vpo",
                "FRPG_Wind_PIWNTT_DDL_VelAlp.vpo",
                "FRPG_WWS_PIN_D_WaterWave.vpo",
                "FRPG_WWS_PIN_DD_WaterWave.vpo",
                "FRPG_WWS_PIWN_D_WaterWave.vpo",
                "FRPG_WWS_PIWN_DD_WaterWave.vpo",
            };

            // Sort family keys longest-first so longest prefix wins
            var famKeys = famVS.Keys.OrderByDescending(k => k.Length).ToList();

            var jobs = new List<(string vsSrc, string output, string[] defines)>();

            foreach (var vpoName in allVpos)
            {
                // Find matching family
                string? fam = famKeys.FirstOrDefault(k =>
                    vpoName.StartsWith(k + "_", StringComparison.Ordinal) ||
                    vpoName.StartsWith(k + ".", StringComparison.Ordinal));

                if (fam == null)
                {
                    Log($"  [WARN] No family for {vpoName}");
                    continue;
                }

                var (fxFile, famExtra) = famVS[fam];

                // PntNum always uses FlverPBL.fx (has WITH_PntNum branch)
                if (vpoName.Contains("_PntNum"))
                    fxFile = "FRPG_VS_FlverPBL.fx";

                var defines = new List<string>(vsBase);
                defines.AddRange(famExtra);

                // Decode defines from VPO name suffix
                string rest = vpoName.Substring(fam.Length + 1).Replace(".vpo", "");
                DecodeVpoDefines(defines, rest, fam, vpoName);

                // PntNum: no ClipPlane (ref SHEX has no clip outputs), but KEEP vtx
                // family defines — ref ISGN retains full family input signature
                // (TANGENT/BINORMAL/UV present even though the PntNum branch
                // never reads them; fxc keeps declared struct members in ISGN).
                if (vpoName.Contains("_PntNum"))
                {
                    defines.RemoveAll(d => d == "WITH_ClipPlane");
                    defines.Add("WITH_PntNum=1");
                }

                string vsSrc = Path.Combine(SRC, fxFile);
                string output = Path.Combine(FLVER_VPO_OUT, vpoName);

                // Deduplicate
                var defsArr = defines.Distinct().ToArray();
                jobs.Add((vsSrc, output, defsArr));
            }

            Log($"  Total VPO jobs: {jobs.Count}");

            // Group by source file for RunParallel
            // (use per-job source variant overload)
            var jobList = jobs.Select(j => (j.vsSrc, j.output, j.defines)).ToList();
            RunParallel(jobList, "VertexMain", "vs_5_0");
        }

        // Decodes defines from VPO name: vtx type + tex config + PS suffix
        private static void DecodeVpoDefines(List<string> d, string rest, string fam, string name)
        {
            bool isStandard = fam is "FRPG_Phn" or "FRPG_Gst" or "FRPG_NtoA"
                                  or "FRPG_Ghost" or "FRPG_Inst" or "FRPG_Dbg";
            bool isWindIvy  = fam is "FRPG_Wind" or "FRPG_Inst_Wind"
                                  or "FRPG_Ivy"  or "FRPG_Inst_Ivy";
            bool isWWS      = fam is "FRPG_WWS"  or "FRPG_Inst_WWS";

            if (isStandard)
            {
                // VtxType
                if      (rest.Contains("PIWNTT")) { d.Add("WITH_Skin"); d.Add("WITH_BumpMap"); d.Add("WITH_MultiTexture"); }
                else if (rest.Contains("PIWNT"))  { d.Add("WITH_Skin"); d.Add("WITH_BumpMap"); }
                else if (rest.Contains("PIWN"))     d.Add("WITH_Skin");
                else if (rest.Contains("PINTT"))  { d.Add("WITH_BumpMap"); d.Add("WITH_MultiTexture"); }
                else if (rest.Contains("PINT"))     d.Add("WITH_BumpMap");
                // Ghost_Skin: name suffix carries skin flag instead of vtx type
                if (fam == "FRPG_Ghost" && rest.Contains("Skin")) d.Add("WITH_Skin");
                // TexCfg
                if      (rest.Contains("_DDL_") || rest.EndsWith("_DDL")) { d.Add("WITH_MultiTexture"); d.Add("WITH_LightMap"); }
                else if (rest.Contains("_DD_")  || rest.EndsWith("_DD"))    d.Add("WITH_MultiTexture");
                else if (rest.Contains("_DL_")  || rest.EndsWith("_DL"))    d.Add("WITH_LightMap");
            }
            else if (isWindIvy)
            {
                if      (rest.Contains("PIWNTT")) { d.Add("WITH_Skin"); d.Add("WITH_Tangent"); d.Add("WITH_Binormal"); }
                else if (rest.Contains("PIWNT"))  { d.Add("WITH_Skin"); d.Add("WITH_Tangent"); }
                else if (rest.Contains("PIWN"))     d.Add("WITH_Skin");
                else if (rest.Contains("PINTT"))  { d.Add("WITH_Tangent"); d.Add("WITH_Binormal"); }
                else if (rest.Contains("PINT"))     d.Add("WITH_Tangent");
                if      (rest.Contains("_DDL_") || rest.EndsWith("_DDL")) d.Add("WIND_DDL");
                else if (rest.Contains("_DD_")  || rest.EndsWith("_DD"))  d.Add("WIND_DD");
                else if (rest.Contains("_DL_")  || rest.EndsWith("_DL"))  d.Add("WIND_DL");
            }
            else if (isWWS)
            {
                if (rest.Contains("_DD_") || rest.EndsWith("_DD")) d.Add("WITH_MultiTexture");
                if (rest.Contains("PIWN")) d.Add("WITH_Skin");
            }
            else if (fam == "FRPG_Sfx")
            {
                if (rest.Contains("PINT")) d.Add("WITH_Tangent");
            }
            else if (fam == "FRPG_Snow")
            {
                if (name.Contains("Lit"))       d.Add("WITH_LightMap");
                if (name.Contains("Skin"))      d.Add("WITH_Skin");
                if (name.Contains("HeightMap")) d.Add("WITH_HeightMap");
            }
            else if (fam == "FRPG_Dbg_Snow")
            {
                // note: rest may START with the tex cfg ("DL_Nrm"), so pad it
                string r = "_" + rest;
                if (r.Contains("_DL_")) d.Add("WITH_LightMap");
                if (name.Contains("Skin")) d.Add("WITH_Skin");
            }
            else if (fam == "FRPG_Water")
            {
                if (name.Contains("Skin"))      d.Add("WITH_Skin");
                if (name.Contains("HeightMap")) d.Add("WITH_HeightMap");
                if (name.Contains("Mask"))      d.Add("WITH_Mask");
            }

            // PS suffix → VS mode (NtoA uses lowercase 'sdw')
            if      (rest.EndsWith("_Sdw") || rest.EndsWith("_sdw")) d.Add("WITH_ShadowMap=1");
            else if (rest.EndsWith("_Dep"))    d.Add("WITH_DepthWrite=1");
            else if (rest.EndsWith("_DepAlp")) { d.Add("WITH_DepthWrite=1"); d.Add("WITH_AlphaBlend=1"); }
            else if (rest.EndsWith("_Vel"))    d.Add("WITH_Velocity=1");
            else if (rest.EndsWith("_VelAlp")) { d.Add("WITH_Velocity=1"); d.Add("WITH_AlphaBlend=1"); }
        }

        // Legacy fallback — old incorrect generation (kept for reference)
        private void BuildFlverPBLVS_Legacy()
        {
            Log("  [legacy] Phn/Gst only from FRPG_VS_FlverPBL.fx");
            string src = Path.Combine(SRC, "FRPG_VS_FlverPBL.fx");
            string[] b = { "_WIN32=1", "_DX11=1", "WITH_ClipPlane" };
            var jobs = new List<(string output, string[] defines)>();
            string[] vtxFmts = { "PIN", "PINT", "PINTT", "PIWN", "PIWNT", "PIWNTT" };
            string[] sdwSufs = { "Non", "Sdw", "Dep", "DepAlp", "Vel", "VelAlp" };
            foreach (var vtx in vtxFmts)
            foreach (var sdwSuf in sdwSufs)
            {
                var bd = new List<string>(b);
                if (vtx.Contains("T"))  bd.Add("WITH_BumpMap");
                if (vtx.Contains("TT")) bd.Add("WITH_MultiTexture");
                if (vtx.Contains("W"))  bd.Add("WITH_Skin");
                if (sdwSuf is "Dep" or "DepAlp")   bd.Add("WITH_DepthWrite=1");
                if (sdwSuf is "DepAlp" or "VelAlp") bd.Add("WITH_AlphaBlend=1");
                if (sdwSuf is "Vel" or "VelAlp")    bd.Add("WITH_Velocity=1");
                jobs.Add((Path.Combine(FLVER_VPO_OUT, $"FRPG_Phn_{vtx}_D_{sdwSuf}.vpo"), bd.ToArray()));
                jobs.Add((Path.Combine(FLVER_VPO_OUT, $"FRPG_Gst_{vtx}_D_{sdwSuf}.vpo"), bd.ToArray()));
            }
            RunParallel(jobs, src, "VertexMain", "vs_5_0");
        }

        // ----------------------------------------------------------------
        // Snow Vertex Shaders
        // ----------------------------------------------------------------
        public void BuildSnowVS()
        {
            Log("Building Snow VS...");
            string src = Path.Combine(SNOW, "FRPG_VS_Snow.fx");
            string[] b = { "_WIN32=1","_DX11=1" };

            var variants = new (string name, string[] extra)[]
            {
                ("FRPG_Snow_______.vpo",          Array.Empty<string>()),
                ("FRPG_Snow_Lit___.vpo",          new[]{"WITH_LightMap"}),
                ("FRPG_Snow_HeightMap.vpo",        new[]{"WITH_HeightMap"}),
                ("FRPG_Snow_HeightMap_Lit.vpo",    new[]{"WITH_HeightMap","WITH_LightMap"}),
                ("FRPG_Snow_Skin_______.vpo",      new[]{"WITH_Skin"}),
                ("FRPG_Snow_Skin_Lit___.vpo",      new[]{"WITH_Skin","WITH_LightMap"}),
                ("FRPG_Snow_HeightMap_Skin.vpo",   new[]{"WITH_HeightMap","WITH_Skin"}),
                ("FRPG_Snow_HeightMap_Skin_Lit.vpo", new[]{"WITH_HeightMap","WITH_Skin","WITH_LightMap"}),
            };

            var jobs = variants.Select(v =>
                (Path.Combine(FLVER_VPO_OUT, v.name), b.Concat(v.extra).ToArray())).ToList();
            RunParallel(jobs, src, "VertexMain", "vs_5_0", new[] { SNOW, SRC });
        }

        // ----------------------------------------------------------------
        // Menu
        // ----------------------------------------------------------------
        public void BuildMenu()
        {
            Log("Building Menu...");
            string[] d = { "_WIN32=1","_DX11=1" };
            string[] dp = { "_WIN32=1","_FRAGMENT_SHADER=1","_DX11=1" };
            Compile(Path.Combine(MENU, "FRPG_Menu_Common.fx"),     Path.Combine(MENU_OUT, "FRPG_Menu_Common.vpo"),      "VSMain",      "vs_5_0", d);
            Compile(Path.Combine(MENU, "FRPG_Menu_Font.fx"),       Path.Combine(MENU_OUT, "FRPG_Menu_Font.vpo"),        "VSMain",      "vs_5_0", d);
            Compile(Path.Combine(MENU, "FRPG_Menu_Font_AL.fx"),    Path.Combine(MENU_OUT, "FRPG_Menu_Font_AL.vpo"),     "VSMain",      "vs_5_0", d);
            Compile(Path.Combine(MENU, "FRPG_Menu_Col.fx"),        Path.Combine(MENU_OUT, "FRPG_Menu_Col.fpo"),         "FragmentMain", "ps_5_0", dp);
            Compile(Path.Combine(MENU, "FRPG_Menu_ColTex.fx"),     Path.Combine(MENU_OUT, "FRPG_Menu_ColTex.fpo"),      "FragmentMain", "ps_5_0", dp);
            Compile(Path.Combine(MENU, "FRPG_Menu_FontSharpen.fx"),Path.Combine(MENU_OUT, "FRPG_Menu_FontSharpen.fpo"), "FragmentMain", "ps_5_0", dp);
        }

        // ----------------------------------------------------------------
        // SfxPBL (SFX sprites/post-effects: 34 PS + 29 VS)
        // ----------------------------------------------------------------
        public void BuildSfxPBL()
        {
            Log("Building SfxPBL...");
            string sfxpbl = Path.Combine(_source, "FRPG_SfxPBL");

            // PS: 34 (Blur 0-3, Tracer 0-3, Line 0, PointSprite 0, Distortion 0-5,
            //      SimpleSprite 0-8, SimpleSprite_Depth 0-8)
            // Each type compiles from a single .fx with a type define.
            var psJobs = new List<(string fx, string output, string[] defines)>();
            void AddPs(string fx, string def, int count, string prefix)
            {
                for (int t = 0; t < count; ++t)
                    psJobs.Add((Path.Combine(sfxpbl, $"FRPG_FS_Sfx_{fx}"),
                                Path.Combine(SFXPBL_OUT, $"{prefix}Type{t}.fpo"),
                                new[] { $"{def}={t}" }));
            }
            AddPs("Blur.fx",              "BLUR_TYPE",          4, "FRPG_Sfx_Blur");
            AddPs("Tracer.fx",            "TRACER_TYPE",        4, "FRPG_Sfx_Tracer");
            AddPs("Line.fx",              "LINE_TYPE",          1, "FRPG_Sfx_Line");
            AddPs("PointSprite.fx",       "POINT_SPRITE_TYPE",  1, "FRPG_Sfx_PointSprite");
            AddPs("Distortion.fx",        "DISTORTION_TYPE",    6, "FRPG_Sfx_Distortion");
            AddPs("SimpleSprite.fx",      "SIMPLE_SPRITE_TYPE", 9, "FRPG_Sfx_SimpleSprite");
            AddPs("SimpleSprite_Depth.fx","DEPTH_SPRITE_TYPE",  9, "FRPG_Sfx_SimpleSprite_Depth");

            // DepthType2/3/6/8 are binary duplicates of SimpleSpriteType2/3/6/8 (ref) —
            // compile SimpleSprite normally, then copy those outputs.
            var psCopyJobs = new List<(string src, string output, string[] defines)>();
            foreach (var (fx, out_, defs) in psJobs)
            {
                if (Path.GetFileName(fx) == "FRPG_FS_Sfx_SimpleSprite_Depth.fx"
                    && defs[0] is "DEPTH_SPRITE_TYPE=2" or "DEPTH_SPRITE_TYPE=3"
                        or "DEPTH_SPRITE_TYPE=6" or "DEPTH_SPRITE_TYPE=8")
                    continue; // built by copying below
                psCopyJobs.Add((fx, out_, defs));
            }

            RunParallel(psCopyJobs, "FragmentMain", "ps_5_0");

            // Copy DepthType2/3/6/8 PS = SimpleSpriteType2/3/6/8 PS (ref: binary identical)
            foreach (int t in new[] { 2, 3, 6, 8 })
            {
                string srcFpo = Path.Combine(SFXPBL_OUT, $"FRPG_Sfx_SimpleSpriteType{t}.fpo");
                string dstFpo = Path.Combine(SFXPBL_OUT, $"FRPG_Sfx_SimpleSprite_DepthType{t}.fpo");
                if (File.Exists(srcFpo))
                {
                    File.Copy(srcFpo, dstFpo, overwrite: true);
                    Interlocked.Increment(ref Built);
                }
                else
                {
                    Interlocked.Increment(ref Errors);
                    Log($"FAILED: {Path.GetFileName(dstFpo)} (no SimpleSprite source)");
                }
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
            // Depth VS: type 2/3/6/8 identical to SimpleSprite, compile with DEPTH=1 for all 9
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
        private void RunParallel(List<(string output, string[] defines)> jobs,
                                 string src, string entry, string profile,
                                 string? includePath = null)
            => RunParallel(jobs, src, entry, profile,
                           includePath != null ? new[] { includePath } : null);

        private void RunParallel(List<(string output, string[] defines)> jobs,
                                 string src, string entry, string profile,
                                 string[]? includePaths)
        {
            int total = jobs.Count;
            int done  = 0;

            Parallel.ForEach(jobs,
                new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount, CancellationToken = _token },
                job =>
                {
                    _token.ThrowIfCancellationRequested();
                    Compile(src, job.output, entry, profile, job.defines, includePaths);
                    int n = Interlocked.Increment(ref done);
                    // Capture delegates locally to avoid null race between check and invoke
                    OnProgress?.Invoke(n, total);
                    if (n % 50 == 0 || n == total)
                        Log($"  {n}/{total}...");
                });
        }

        // Per-job source variant (each job carries its own .fx file)
        private void RunParallel(List<(string src, string output, string[] defines)> jobs,
                                 string entry, string profile)
        {
            int total = jobs.Count;
            int done  = 0;

            Parallel.ForEach(jobs,
                new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount, CancellationToken = _token },
                job =>
                {
                    _token.ThrowIfCancellationRequested();
                    Compile(job.src, job.output, entry, profile, job.defines, (string[]?)null);
                    int n = Interlocked.Increment(ref done);
                    OnProgress?.Invoke(n, total);
                    if (n % 50 == 0 || n == total)
                        Log($"  {n}/{total}...");
                });
        }

        // ----------------------------------------------------------------
        // Single compile
        // ----------------------------------------------------------------
        private void Compile(string src, string output, string entry, string profile, string[] defines)
            => Compile(src, output, entry, profile, defines, (string[]?)null);

        private void Compile(string src, string output, string entry, string profile, string[] defines, string? includePath)
            => Compile(src, output, entry, profile, defines, includePath != null ? new[] { includePath } : null);

        private void Compile(string src, string output, string entry, string profile, string[] defines, string[]? includePaths)
        {
            _token.ThrowIfCancellationRequested();

            // Incremental: skip if output is newer than all sources
            if (!_force && File.Exists(output))
            {
                var outTime = File.GetLastWriteTime(output);
                if (outTime > _srcNewest)
                {
                    Interlocked.Increment(ref Skipped);
                    return;
                }
            }

            // CreateDirectory is not atomic across threads for the same path — serialize it
            string? dir = Path.GetDirectoryName(output);
            if (dir != null && !Directory.Exists(dir))
            {
                lock (_dirLock)
                    Directory.CreateDirectory(dir);
            }

            // Preprocess HLSL to fix invalid swizzles from machine translation
            string actualSrc = src;
            if (File.Exists(src))
            {
                string hlsl = File.ReadAllText(src);
                string fixedHlsl = FixInvalidSwizzles(hlsl);
                
                if (fixedHlsl != hlsl)
                {
                    // Create temp file with fixed HLSL
                    actualSrc = Path.Combine(Path.GetTempPath(), $"shader_fixed_{Path.GetFileName(src)}");
                    File.WriteAllText(actualSrc, fixedHlsl);
                }
            }

            // When using a temp file, add original source dir to include paths
            // so #include "..." resolves correctly
            if (actualSrc != src)
            {
                string? srcDir = Path.GetDirectoryName(src);
                if (srcDir != null)
                    includePaths = includePaths?.Append(srcDir).ToArray() ?? new[] { srcDir };
            }

            var defArgs  = string.Join(" ", defines.Select(d => $"/D{d}"));
            var inclArgs = includePaths != null
                ? string.Join(" ", includePaths.Select(p => $"/I\"{p}\""))
                : "";
            var args     = $"\"{actualSrc}\" /Fo\"{output}\" /T {profile} /nologo {defArgs} {inclArgs} /E{entry}";

            var psi = new ProcessStartInfo(_fxc, args)
            {
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                UseShellExecute        = false,
                CreateNoWindow         = true
            };

            using var proc = Process.Start(psi)!;

            // Read stdout and stderr concurrently to avoid deadlock:
            // if we read one stream synchronously while the other fills its buffer,
            // the child process blocks and ReadToEnd never returns.
            var stdoutTask = proc.StandardOutput.ReadToEndAsync();
            var stderrTask = proc.StandardError.ReadToEndAsync();
            proc.WaitForExit();
            string stdout = stdoutTask.GetAwaiter().GetResult();
            string stderr = stderrTask.GetAwaiter().GetResult();

            // Clean up temp file if created
            if (actualSrc != src && File.Exists(actualSrc))
            {
                try { File.Delete(actualSrc); } catch { }
            }

            if (proc.ExitCode != 0)
            {
                Interlocked.Increment(ref Errors);
                lock (_logLock)
                {
                    Log($"FAILED: {Path.GetFileName(output)}");
                    foreach (var line in (stdout + stderr).Split('\n'))
                        if (line.Contains("error") || line.Contains("warning"))
                            Log($"  {line.Trim()}");
                }
            }
            else
            {
                Interlocked.Increment(ref Built);
                _builtFiles.Add(output);
            }
        }

        // ----------------------------------------------------------------
        // Helpers
        // ----------------------------------------------------------------
        
        /// <summary>
        /// Fix invalid swizzles in machine-translated HLSL from DXBC.
        /// Patterns like "v3.xyzx.xyz" or "cb0[73].xyzx.xyz" are invalid HLSL
        /// but appear in literal translations of DXBC assembly.
        /// </summary>
        private static string FixInvalidSwizzles(string hlsl)
        {
            // Match any expression ending with ] or word char, followed by .swizzle4.swizzle3-4
            // Examples:
            //   v3.xyzx.xyz        -> v3.xyz
            //   r4.yzwy.xyz        -> r4.yzw
            //   cb0[73].xyzx.xyz   -> cb0[73].xyz
            
            var pattern = @"([\w\])])\.(([xyzw]{4})\.(([xyzw]{3,4})))";
            
            hlsl = Regex.Replace(hlsl, pattern, match =>
            {
                string prefix   = match.Groups[1].Value;
                string swizzle1 = match.Groups[3].Value;
                string swizzle2 = match.Groups[5].Value;
                
                if (swizzle2 == "xyz")
                    return $"{prefix}.{swizzle1.Substring(0, 3)}";
                if (swizzle2 == "xyzw")
                    return $"{prefix}.{swizzle1}";
                
                try
                {
                    var result = "";
                    foreach (char c in swizzle2)
                    {
                        int idx = "xyzw".IndexOf(c);
                        if (idx >= 0 && idx < swizzle1.Length)
                            result += swizzle1[idx];
                        else
                            return match.Value;
                    }
                    return $"{prefix}.{result}";
                }
                catch
                {
                    return match.Value;
                }
            });
            
            return hlsl;
        }
        
        private void Log(string msg)
        {
            // Capture to local to avoid null race between ?. check and invoke
            OnLog?.Invoke(msg);
        }

        private static DateTime GetNewestFile(string dir)
        {
            if (!Directory.Exists(dir)) return DateTime.MinValue;
            var dt = DateTime.MinValue;
            foreach (var f in Directory.GetFiles(dir, "*", SearchOption.AllDirectories))
            {
                var t = File.GetLastWriteTime(f);
                if (t > dt) dt = t;
            }
            return dt;
        }

        // ----------------------------------------------------------------
        // Archive structure (archive_structures.json)
        // DX9-архивы (DbgFont_DX9, FRPG_Deferred_DX9, FRPG_Filter_DX9,
        // FRPG_Menu_DX9) — ref-only: DSR Windows рендерит только DX11.
        // ----------------------------------------------------------------
        public class ArchiveFile
        {
            public string Name = "";   // Базовое имя файла (например DbgFont.vpo)
            public string Path = "";   // Полный путь внутри BND3 (N:\FRPG\Source\...)
        }

        public class ArchiveInfo
        {
            public string Name = "";
            public bool   Build;
            public ArchiveFile[] Files = Array.Empty<ArchiveFile>();
        }

        public static List<ArchiveInfo> LoadArchiveStructure(string root)
        {
            var path = Path.Combine(root, "archive_structures.json");
            if (!File.Exists(path)) return new List<ArchiveInfo>();

            var list = new List<ArchiveInfo>();
            using var doc = System.Text.Json.JsonDocument.Parse(File.ReadAllText(path));
            foreach (var prop in doc.RootElement.EnumerateObject())
            {
                var files = prop.Value.GetProperty("files")
                    .EnumerateArray()
                    .Select(e => new ArchiveFile
                    {
                        Name = e.GetProperty("name").GetString() ?? "",
                        Path = e.GetProperty("path").GetString() ?? "",
                    })
                    .ToArray();
                list.Add(new ArchiveInfo
                {
                    Name  = prop.Name,
                    Build = prop.Value.GetProperty("build").GetBoolean(),
                    Files = files
                });
            }
            return list;
        }

        // ----------------------------------------------------------------
        // Deferred (DebugGBuffer, LightProbe, PointLight)
        // ----------------------------------------------------------------
        public void BuildDeferred()
        {
            Log("Building Deferred...");
            string dir = Path.Combine(_source, "FRPG_Deferred");
            string defsPs = "_WIN32=1;_FRAGMENT_SHADER=1;_DX11=1".Replace(';', ' ');
            string out_ = Path.Combine(_dsr, @"shader\FRPG_Deferred_DX11-shaderbnd-dcx");

            Compile(Path.Combine(dir, "FRPG_FS_Deferred_DebugGBuffer.fx"), Path.Combine(out_, "FRPG_Deferred_DebugGBuffer.fpo"), "FragmentMain", "ps_5_0", defsPs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_Deferred_LightProbe.fx"),      Path.Combine(out_, "FRPG_Deferred_LightProbe.fpo"),      "FragmentMain", "ps_5_0", defsPs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_Deferred_PointLight.fx"),      Path.Combine(out_, "FRPG_Deferred_PointLight.fpo"),      "FragmentMain", "ps_5_0", defsPs.Split(' '));

            string defsVs = "_WIN32=1;_DX11=1".Replace(';', ' ');
            Compile(Path.Combine(dir, "FRPG_VS_Deferred_Quad.fx"),         Path.Combine(out_, "FRPG_Deferred_DebugGBuffer.vpo"),    "VSMain", "vs_5_0", defsVs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_VS_Deferred_Quad.fx"),         Path.Combine(out_, "FRPG_Deferred_LightProbe.vpo"),      "VSMain", "vs_5_0", defsVs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_VS_Deferred_PointLight.fx"),   Path.Combine(out_, "FRPG_Deferred_PointLight.vpo"),      "VSMain", "vs_5_0", defsVs.Split(' '));
        }

        // ----------------------------------------------------------------
        // DbgFont (debug utilities: 3 VS + 5 PS)
        // ----------------------------------------------------------------
        public void BuildDbgFont()
        {
            Log("Building DbgFont...");
            string dir = Path.Combine(_source, "DbgFont");
            string defsVs = "_WIN32=1;_DX11=1".Replace(';', ' ');
            string defsPs = "_WIN32=1;_FRAGMENT_SHADER=1;_DX11=1".Replace(';', ' ');
            string out_ = Path.Combine(_dsr, @"shader\DbgFont_DX11-shaderbnd-dcx");

            Compile(Path.Combine(dir, "FRPG_VS_DbgFont.fx"),            Path.Combine(out_, "DbgFont.vpo"),            "VSMain",      "vs_5_0", defsVs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_VS_DbgPrim_Common.fx"),     Path.Combine(out_, "DbgPrim_Common.vpo"),     "VSMain",      "vs_5_0", defsVs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_VS_DbgPrim_UVW.fx"),        Path.Combine(out_, "DbgPrim_UVW.vpo"),        "VSMain",      "vs_5_0", defsVs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_FS_DbgFont.fx"),            Path.Combine(out_, "DbgFont.fpo"),            "FragmentMain", "ps_5_0", defsPs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_FS_DbgPrim_Col.fx"),        Path.Combine(out_, "DbgPrim_Col.fpo"),        "FragmentMain", "ps_5_0", defsPs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_FS_DbgPrim_ColTex.fx"),     Path.Combine(out_, "DbgPrim_ColTex.fpo"),     "FragmentMain", "ps_5_0", defsPs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_FS_DbgPrim_ColTexNrmDcd.fx"), Path.Combine(out_, "DbgPrim_ColTexNrmDcd.fpo"), "FragmentMain", "ps_5_0", defsPs.Split(' '));
            Compile(Path.Combine(dir, "FRPG_FS_DbgPrim_ColTex_Cube.fx"), Path.Combine(out_, "DbgPrim_ColTex_Cube.fpo"), "FragmentMain", "ps_5_0", defsPs.Split(' '));
        }

        // ----------------------------------------------------------------
        // Rebuild all DX11 archives from scratch (no originals needed).
        // Reads archive_structures.json, takes compiled bytes from
        // DSR\shader\<archive>-shaderbnd-dcx\, writes .shaderbnd.dcx.
        // ----------------------------------------------------------------
        public void BuildArchivesFromStructure()
        {
            string root = Path.GetFullPath(Path.Combine(_source, ".."));
            var archives = LoadArchiveStructure(root);
            if (archives.Count == 0)
            {
                Log("archive_structures.json не найден — сгенерируйте: python tools\\gen_archive_structure.py");
                return;
            }

            string shaderDir = Path.Combine(_dsr, "shader");
            Directory.CreateDirectory(shaderDir);

            int totalArchives = 0, totalFiles = 0, totalMissing = 0;
            foreach (var a in archives)
            {
                if (!a.Build) continue; // DX9 — не собираем

                string srcDir = Path.Combine(shaderDir, a.Name + "-shaderbnd-dcx");
                string bundlePath = Path.Combine(shaderDir, a.Name + ".shaderbnd.dcx");

                if (!Directory.Exists(srcDir))
                {
                    Log($"  [SKIP] {a.Name} — папка не найдена: {srcDir}");
                    continue;
                }

                // Ищем скомпилированные файлы по базовому имени
                var builtByName = Directory.GetFiles(srcDir, "*", SearchOption.AllDirectories)
                    .ToLookup(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase);                var bnd = new BND3
                {
                    Version = "07D7R6",
                    WriteFileHeadersEnd = true,
                };

                int added = 0, missing = 0;
                for (int i = 0; i < a.Files.Length; i++)
                {
                    var f = a.Files[i];
                    string? disk = builtByName[f.Name].FirstOrDefault();
                    if (disk == null)
                    {
                        missing++;
                        continue;
                    }
                    bnd.Files.Add(new BinderFile(Binder.FileFlags.Flag1, i, f.Path, File.ReadAllBytes(disk)));
                    added++;
                }

                try
                {
                    byte[] outBytes = DCX.Compress(bnd.Write(), new DCX.DcxDfltCompressionInfo(DCX.DfltCompressionPreset.DCX_DFLT_10000_24_9));
                    File.WriteAllBytes(bundlePath, outBytes);
                    totalArchives++; totalFiles += added; totalMissing += missing;
                    Log($"  [{added}/{a.Files.Length}] {a.Name}.shaderbnd.dcx{(missing > 0 ? $"  (не хватает {missing})" : "")}");
                }
                catch (Exception ex)
                {
                    Log($"  [FAIL] {a.Name}: {ex.Message}");
                }
            }
            Log($"Archives: {totalArchives} built, {totalFiles} files, {totalMissing} missing → {shaderDir}");
        }

        // Распаковывает оригинальные .shaderbnd.dcx из _origDir в shader\<name>-orig\
        // (используется как fallback для файлов, у которых нет восстановленных исходников — VS и т.п.)
        public void UnpackOriginalArchives()
        {
            string root = Path.GetFullPath(Path.Combine(_source, ".."));
            var archives = LoadArchiveStructure(root);
            if (archives.Count == 0 || string.IsNullOrEmpty(_origDir) || !Directory.Exists(_origDir))
            {
                Log("UnpackOriginalArchives: папка оригинала не задана/не найдена");
                return;
            }

            string shaderDir = Path.Combine(_dsr, "shader");
            foreach (var a in archives)
            {
                if (!a.Build) continue;

                string bundlePath = Path.Combine(_origDir, a.Name + ".shaderbnd.dcx");
                if (!File.Exists(bundlePath)) continue;

                string origDir = Path.Combine(shaderDir, a.Name + "-orig");
                Directory.CreateDirectory(origDir);

                try
                {
                    byte[] data = File.ReadAllBytes(bundlePath);
                    BND3 bnd = BND3.Read(DCX.Decompress(data));
                    int count = 0;
                    foreach (var f in bnd.Files)
                    {
                        File.WriteAllBytes(Path.Combine(origDir, Path.GetFileName(f.Name)), f.Bytes);
                        count++;
                    }
                    Log($"  [orig] {a.Name}: {count} файлов → {origDir}");
                }
                catch (Exception ex)
                {
                    Log($"  [orig FAIL] {a.Name}: {ex.Message}");
                }
            }
        }

        public void ShowArchives()
        {
            // JSON лежит в корне проекта (рядом с source\), а не внутри source
            string root = Path.GetFullPath(Path.Combine(_source, ".."));
            var archives = LoadArchiveStructure(root);
            if (archives.Count == 0)
            {
                Log("archive_structures.json не найден — сгенерируйте: python tools\\gen_archive_structure.py");
                return;
            }

            Log("Структура архивов:");
            Log("  [BUILD]    — собираем (DX11, игра грузит)");
            Log("  [ref-only] — только справочно (DX9, игра НЕ грузит)");

            int buildTotal = 0, refTotal = 0;
            foreach (var a in archives)
            {
                if (a.Build) buildTotal += a.Files.Length; else refTotal += a.Files.Length;
                Log($"  [{(a.Build ? "BUILD    " : "ref-only ")}] {a.Name,-26} {a.Files.Length,5} files");
            }
            Log($"  Итого: {buildTotal + refTotal} files ({buildTotal} build / {refTotal} ref-only)");
        }

        // ----------------------------------------------------------------
        // BuildAll — компилирует все 7 DX11 архивов с нуля и пакует.
        // Не требует оригинальных архивов: VPO собирается из source,
        // всё остальное тоже из source.
        // ----------------------------------------------------------------
        public void BuildAll()
        {
            Log("=== BuildAll: compiling all 7 DX11 archives from source ===");

            // ── FlverPBL fpo (1989) ───────────────────────────────────────
            Log("--- FlverPBL fpo ---");
            BuildFlverPBL();

            // ── FlverPBL vpo (676) ────────────────────────────────────────
            Log("--- FlverPBL vpo ---");
            BuildFlverPBLVS();

            // ── Snow fpo/vpo ──────────────────────────────────────────────
            Log("--- Snow ---");
            BuildSnow();
            BuildSnowVS();

            // ── Filter (59 fpo + 41 vpo + 16 cpo = 116) ──────────────────
            Log("--- Filter ---");
            BuildFilter();

            // ── Menu (3 fpo + 3 vpo) ──────────────────────────────────────
            Log("--- Menu ---");
            BuildMenu();

            // ── SfxPBL (34 fpo + 29 vpo) ─────────────────────────────────
            Log("--- SfxPBL ---");
            BuildSfxPBL();

            // ── Deferred (3 fpo + 3 vpo) ─────────────────────────────────
            Log("--- Deferred ---");
            BuildDeferred();

            // ── DbgFont (5 fpo + 3 vpo) ───────────────────────────────────
            Log("--- DbgFont ---");
            BuildDbgFont();

            Log($"=== Compile done: {Built} built, {Skipped} skipped, {Errors} errors ===");
        }
    }
}
