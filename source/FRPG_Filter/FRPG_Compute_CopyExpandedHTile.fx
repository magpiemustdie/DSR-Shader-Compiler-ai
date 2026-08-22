// FRPG_Compute_CopyExpandedHTile.fx
// Reconstructed from DSR DXBC cs_5_0.
// Copies HTile data from t0 to u0, ORing in 0xF (marks all 4 sub-tiles as valid).
// Used for HTILE expansion after depth resolve.
// t0=source HTile (Buffer<uint>), u0=dest HTile (RWBuffer<uint>)

Buffer<uint>    t0 : register(t0);
RWBuffer<uint>  u0 : register(u0);

[numthreads(64, 1, 1)]
void ComputeMain(uint3 threadID : SV_DispatchThreadID)
{
    uint val = t0.Load(threadID.x);
    val |= 0xFu;
    u0[threadID.x] = val;
}
