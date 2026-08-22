// Quick translator test — run with: dotnet run --project ShaderBuild -- --test
// Add to Main or call from a button

using ShaderCompiler.Decompiler;

namespace ShaderCompiler
{
    internal static class TestTranslator
    {
        // Minimal real DSR pixel shader asm (FRPG_Menu_Col.fpo equivalent)
        private const string SampleAsm = @"
ps_5_0
dcl_globalFlags refactoringAllowed
dcl_constantbuffer CB0[1], immediateIndexed
dcl_input_ps linear v0.xyzw
dcl_output o0.xyzw
dcl_temps 1
mov r0.xyzw, v0.xyzw
mul r0.xyzw, r0.xyzw, cb0[0].xyzw
mov o0.xyzw, r0.xyzw
ret
";

        private const string SampleVsAsm = @"
vs_5_0
dcl_globalFlags refactoringAllowed
dcl_constantbuffer CB0[4], immediateIndexed
dcl_input v0.xyzw
dcl_input v1.xyzw
dcl_output_siv o0.xyzw, position
dcl_output o1.xyzw
dcl_temps 2
dp4 r0.x, v0.xyzw, cb0[0].xyzw
dp4 r0.y, v0.xyzw, cb0[1].xyzw
dp4 r0.z, v0.xyzw, cb0[2].xyzw
dp4 r0.w, v0.xyzw, cb0[3].xyzw
mov o0.xyzw, r0.xyzw
mov o1.xyzw, v1.xyzw
ret
";

        private const string SampleSampleAsm = @"
ps_5_0
dcl_globalFlags refactoringAllowed
dcl_constantbuffer CB0[8], immediateIndexed
dcl_sampler s0, mode_default
dcl_resource_texture2d (float,float,float,float) t0
dcl_input_ps linear v0.xyzw
dcl_input_ps linear v1.xy
dcl_output o0.xyzw
dcl_temps 2
sample r0.xyzw, v1.xyxx, t0.xyzw, s0
mul r0.xyzw, r0.xyzw, v0.xyzw
mul o0.xyzw, r0.xyzw, cb0[0].xyzw
ret
";

        public static void Run()
        {
            Console.WriteLine("=== AsmToHlsl Translator Test ===\n");

            Test("Simple PS (mul + mov)", SampleAsm);
            Test("Simple VS (dp4 transform)", SampleVsAsm);
            Test("PS with texture sample", SampleSampleAsm);
        }

        private static void Test(string name, string asm)
        {
            Console.WriteLine($"--- {name} ---");
            try
            {
                var t = new AsmToHlsl();
                string hlsl = t.Translate(asm);
                Console.WriteLine(hlsl);

                // Basic validation
                bool hasMain    = hlsl.Contains("main(");
                bool hasReturn  = hlsl.Contains("return output");
                bool noUnhandled = !hlsl.Contains("// UNHANDLED:");
                Console.WriteLine($"  main(): {hasMain}  return: {hasReturn}  no unhandled: {noUnhandled}");
                Console.WriteLine(hasMain && hasReturn && noUnhandled ? "  PASS" : "  FAIL");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  EXCEPTION: {ex.Message}");
            }
            Console.WriteLine();
        }
    }
}
