//==============================================================================
//  FRPG_FS_DeferredDisney.fx  —  Disney-style GBuffer deferred fragment shader
//
//  16 variants controlled by four defines:
//    WITH_SpecularMap     t1 specular (PBL) texture
//    WITH_BumpMap         t2 normal/bump map (+ tangent frame input)
//    WITH_LightMap        t6 detail/lightmap texture → GBuffer3
//    WITH_MultiTexture    t3/t4/t5 second set, vertex-alpha lerp, SkinAddColor
//
//  GBuffer layout (4 RTs):
//    SV_Target0  — normal.xyz * 0.5 + 0.5,     alpha
//    SV_Target1  — albedo.rgb  (base * color * mul * override), alpha
//    SV_Target2  — specular.r, specular.g, roughness*5,           alpha
//    SV_Target3  — detail.rgb / lightmap.rgb / default,          alpha
//==============================================================================

//-----------------------------------------------------------------------------
// Resources
//-----------------------------------------------------------------------------
Texture2D    g_tBaseTex      : register(t0);
Texture2D    g_tSpcTex       : register(t1);  // WITH_SpecularMap
Texture2D    g_tBmpTex       : register(t2);  // WITH_BumpMap
Texture2D    g_tBaseTex2     : register(t3);  // WITH_MultiTexture
Texture2D    g_tSpcTex2      : register(t4);  // WITH_SpecularMap + WITH_MultiTexture
Texture2D    g_tBmpTex2      : register(t5);  // WITH_BumpMap + WITH_MultiTexture
Texture2D    g_tLitTex       : register(t6);  // WITH_LightMap
Texture2D    g_tDetailBmpTex : register(t15);

SamplerState g_sSmp0  : register(s0);
SamplerState g_sSmp1  : register(s1);
SamplerState g_sSmp2  : register(s2);
SamplerState g_sSmp3  : register(s3);
SamplerState g_sSmp4  : register(s4);
SamplerState g_sSmp5  : register(s5);
SamplerState g_sSmp6  : register(s6);
SamplerState g_sSmp15 : register(s15);

//-----------------------------------------------------------------------------
// Constant buffer — OLD_VERSION deferred layout (DL_FREG_084 … DL_FREG_195)
//-----------------------------------------------------------------------------
cbuffer Globals : register(b0)
{
    // Unused range DL_FREG_084..099 (offsets 1344–1584)
    float4 unused_084_099[16] : packoffset(c84);

    float4 gFC_MaterialOverride  : packoffset(c100);  // offset 1600
    float4 gFC_MaterialOverride2 : packoffset(c101);  // offset 1616

    // Unused range DL_FREG_102..138
    float4 unused_102_138[37] : packoffset(c102);

    float4 gFC_ModelMulCol       : packoffset(c139);  // offset 2224

    // Unused range DL_FREG_140..155 (matrices etc.)
    float4 unused_140_155[16] : packoffset(c140);

    float4 gFC_SkinAddColor      : packoffset(c156);  // offset 2496

    // Unused range DL_FREG_157..181
    float4 unused_157_181[25] : packoffset(c157);

    float4 gFC_DetailBumpParam   : packoffset(c182);  // offset 2912 (.x=UV scale, .w=strength)
}

#ifndef WITH_MultiTexture
cbuffer AlphaTestBuffer : register(b1)
{
    int   g_iAlphaTest;
    float3 g_fAlphaTestRef;
}
#endif

//-----------------------------------------------------------------------------
// Output struct (4 GBuffer render targets)
//-----------------------------------------------------------------------------
struct PS_OUT
{
    float4 RT0 : SV_Target0;
    float4 RT1 : SV_Target1;
    float4 RT2 : SV_Target2;
    float4 RT3 : SV_Target3;
};

//-----------------------------------------------------------------------------
// Input struct — conditional on feature defines to match reference declarations
//-----------------------------------------------------------------------------
struct PS_INPUT
{
    float4 Pos    : SV_Position;
    float4 Wld    : TEXCOORD0;     // world position (unused)
    float4 Nrm    : TEXCOORD2;     // vertex normal
    float4 T3     : TEXCOORD3;     // unused

#if defined(WITH_BumpMap)
    float4 Tangent  : TEXCOORD4;   // tangent frame
    #if defined(WITH_MultiTexture)
        float4 Tangent2 : TEXCOORD5;
    #endif
#endif

    float4 Color    : COLOR0;
    float4 TexUV    : TEXCOORD6;   // .xy = base, .zw = second/lit UV

#if defined(WITH_LightMap) && defined(WITH_MultiTexture)
    float2 LitUV    : TEXCOORD7;
#endif
};

//-----------------------------------------------------------------------------
// Helper functions
//-----------------------------------------------------------------------------
float3 BuildBinormal(float3 normal, float4 tangent)
{
    return cross(normal, tangent.xyz) * tangent.w;
}

float3 SampleNormalMap(Texture2D tex, SamplerState smp, float2 uv)
{
    float2 n = tex.Sample(smp, uv).rg * 2.0 - 1.0;
    float lenSq = dot(n, n);
    float z = sqrt(1.0 - saturate(lenSq));
    return float3(n, z);
}

float3 PerturbNormal(float3 normal, float4 tangent, float3 bumpN)
{
    float3 t = normalize(tangent.xyz);
    float3 b = normalize(BuildBinormal(normal, tangent));
    float3 n = normalize(normal);
    return normalize(b * bumpN.x + t * bumpN.y + n * bumpN.z);
}

float3 PerturbNormalSimple(float3 normal, float3 bumpN)
{
    float3 n = normalize(normal);
    float3 t = float3(n.z, n.y, n.z);
    float3 b = float3(n.x, n.z, n.y);
    return normalize(b * bumpN.x + t * bumpN.y + n * bumpN.z);
}

float3 DetailBump(float2 baseUV)
{
    // ref: TWO dots — raw (pre-scale) drives the z-reconstruction, the SCALED
    // vector drives the degenerate test; validity is ADDED to z (not a movc).
    float2 detailUV = baseUV * gFC_DetailBumpParam.x;
    float2 bump = g_tDetailBmpTex.Sample(g_sSmp15, detailUV).rg * 2.0 - 1.0;
    float rawSq = dot(bump, bump);
    bump *= gFC_DetailBumpParam.w;

    float z = sqrt(1.0f - saturate(rawSq));
    float valid = (dot(bump, bump) < 0.00001f) ? 1.0f : 0.0f;
    return normalize(float3(bump, z + valid));
}

//-----------------------------------------------------------------------------
// Fragment entry point
//-----------------------------------------------------------------------------
PS_OUT FragmentMain(PS_INPUT In)
{
    PS_OUT Out;

    //----------
    // 1. Alpha test (non-Mul variants only)
    //----------
#ifndef WITH_MultiTexture
    float4 baseColor = g_tBaseTex.Sample(g_sSmp0, In.TexUV.xy);
    baseColor *= In.Color;
    if (g_iAlphaTest == 1 && baseColor.a <= g_fAlphaTestRef.x)
        discard;
#endif

    //----------
    // 2. Detail bump + normal computation
    //----------
    float2 baseUV = In.TexUV.xy;
    float3 detailBump = DetailBump(baseUV);

    float3 worldNormal;
#if defined(WITH_BumpMap)
    // Primary normal map
    float3 primaryBump = SampleNormalMap(g_tBmpTex, g_sSmp2, baseUV);
    worldNormal = PerturbNormal(In.Nrm.xyz, In.Tangent, primaryBump);

    #if defined(WITH_MultiTexture)
        // Second normal map (multi-texture)
        float3 secondaryBump = SampleNormalMap(g_tBmpTex2, g_sSmp5, In.TexUV.zw);
        float3 worldNormal2 = PerturbNormal(In.Nrm.xyz, In.Tangent2, secondaryBump);
        worldNormal = lerp(worldNormal, worldNormal2, In.Color.w);
    #endif

    // Rebuild TBN from blended normal, apply detail bump
    {
        float3 t = normalize(In.Tangent.xyz);
        float3 n = normalize(worldNormal);
        float3 b = normalize(BuildBinormal(n, In.Tangent));
        float3 tt = cross(n, b);
        worldNormal = normalize(tt * detailBump.x + b * detailBump.y + n * detailBump.z);
    }
#else
    // No tangent: apply detail bump directly to vertex normal
    float3 vn = normalize(In.Nrm.xyz);
    worldNormal = PerturbNormalSimple(vn, detailBump);
#endif

    // alpha is computed during albedo — placeholder for now
    Out.RT0.xyz = worldNormal * 0.5 + 0.5;

    //----------
    // 3. Albedo
    //----------
    float4 albedo;
    {
#ifndef WITH_MultiTexture
        albedo = g_tBaseTex.Sample(g_sSmp0, baseUV);
        albedo *= In.Color;
        albedo *= gFC_ModelMulCol;
#else
        float3 base1 = g_tBaseTex.Sample(g_sSmp0, baseUV).xyz;
        float3 base2 = g_tBaseTex2.Sample(g_sSmp3, In.TexUV.zw).xyz;
        base2 += gFC_SkinAddColor.xyz;
        float3 blended = lerp(base1, base2, In.Color.w);
        blended *= In.Color.xyz;
        albedo = float4(blended, 1.0) * gFC_ModelMulCol;
#endif
    }

    //----------
    // 4. Specular + material override
    //----------
    float3 specular;
#if defined(WITH_SpecularMap)
    #if defined(WITH_MultiTexture)
        float3 spc1 = g_tSpcTex.Sample(g_sSmp1, baseUV).xyz;
        float3 spc2 = g_tSpcTex2.Sample(g_sSmp4, In.TexUV.zw).xyz;
        specular = lerp(spc1, spc2, In.Color.w);
    #else
        specular = g_tSpcTex.Sample(g_sSmp1, baseUV).xyz;
    #endif

    float4 overrideColor = lerp(gFC_MaterialOverride, gFC_MaterialOverride2, specular.g);
    albedo *= overrideColor;
    Out.RT2 = float4(specular * float3(1.0, 1.0, 5.0), albedo.a);
#else
        specular = float3(1.0, 0.0, 0.199999988);
        albedo *= gFC_MaterialOverride;
        Out.RT2 = float4(specular, albedo.a);
#endif

    Out.RT0.a = albedo.a;
    Out.RT1 = albedo;

    //----------
    // 5. Detail / lightmap (GBuffer3)
    //----------
    {
#if defined(WITH_LightMap)
        #if defined(WITH_MultiTexture)
            float2 litUV = In.LitUV;
        #else
            float2 litUV = In.TexUV.zw;
        #endif
        float3 lit = g_tLitTex.Sample(g_sSmp6, litUV).xyz;
        Out.RT3 = float4(lit, albedo.a);
#else
        #if defined(WITH_SpecularMap) || defined(WITH_BumpMap) || defined(WITH_MultiTexture)
            Out.RT3 = float4(1.0, 1.0, 1.0, albedo.a);
        #else
            Out.RT3 = float4(0.0, 0.0, 0.0, albedo.a);
        #endif
#endif
    }

    return Out;
}
