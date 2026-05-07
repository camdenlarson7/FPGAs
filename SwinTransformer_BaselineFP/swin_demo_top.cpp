// swin_demo_top.cpp — Full Swin Transformer block board demo (PYNQ-Z2)
//
// Exercises the COMPLETE pipeline:
//   load_window → LayerNorm1 → QKV projection → window attention
//   → residual add → LayerNorm2 → MLP → residual add → store_window
//
// Parameter reductions for BRAM budget (140 BRAM36 on xc7z020):
//   swin_params.h must set FEAT_H=14, FEAT_W=14, MLP_DIM=96, N_WINDOWS=4.
//   WIN_SIZE=7, C=96, HEADS=3, D_HEAD=32 are unchanged — same block structure.
//
// Test: zero weights, identity LayerNorm (gamma=1, beta=0).
//   Both residual connections propagate the input unchanged regardless of what
//   the internal LN/attention/MLP stages do, so output == input.
//
//   Proof:
//     QKV = LN1(tokens) * 0 = 0  →  attn_out = 0
//     residual1: tokens' = 0 + tokens = tokens  ✓
//     FC1 = LN2(tokens) * 0 = 0  →  GELU(0) = 0  →  mlp_out = 0
//     residual2: output = 0 + tokens = tokens  ✓
//
//   Fixed-point tolerance: ±4 LSB (LSB = 2^-10 ≈ 0.001 for ap_fixed<16,6>).
//
// LED0 lights if all FEAT_H*FEAT_W*C output values equal the input within
// tolerance.  LED3 lights when ap_done fires.

#include "swin_params.h"
#include "ap_int.h"

// Forward-declare the top HLS kernel (defined in swin_block.cpp, added as
// a second source file in the Vitis HLS component alongside this file).
void swin_block(
    data_t   feat_map[FEAT_H * FEAT_W * C],
    weight_t W_QKV   [C][3*C],
    weight_t b_QKV   [3*C],
    weight_t W_O     [C][C],
    weight_t b_O     [C],
    weight_t gamma1  [C],
    weight_t beta1   [C],
    weight_t gamma2  [C],
    weight_t beta2   [C],
    weight_t W_FC1   [C][MLP_DIM],
    weight_t b_FC1   [MLP_DIM],
    weight_t W_FC2   [MLP_DIM][C],
    weight_t b_FC2   [C],
    weight_t rel_bias[HEADS][M2][M2],
    int      shifted
);

void swin_demo_top(ap_uint<1> *swin_pass)
{
#pragma HLS INTERFACE ap_ctrl_hs port=return
#pragma HLS INTERFACE ap_none    port=swin_pass

    // Feature map — two copies: one modified by swin_block, one kept as reference
    static data_t feat_map [FEAT_H * FEAT_W * C];
    static data_t feat_orig[FEAT_H * FEAT_W * C];

    // Weight / bias arrays — all zero so the block acts as identity
    static weight_t W_QKV  [C][3*C];
    static weight_t b_QKV  [3*C];
    static weight_t W_O    [C][C];
    static weight_t b_O    [C];
    static weight_t gamma1 [C];
    static weight_t beta1  [C];
    static weight_t gamma2 [C];
    static weight_t beta2  [C];
    static weight_t W_FC1  [C][MLP_DIM];
    static weight_t b_FC1  [MLP_DIM];
    static weight_t W_FC2  [MLP_DIM][C];
    static weight_t b_FC2  [C];
    static weight_t rel_bias[HEADS][M2][M2];

    // Fill feat_map with a deterministic pattern covering the full dynamic range.
    // Pattern cycles through 7 values in [-0.375, 0.375] with step 0.125.
    const int N = FEAT_H * FEAT_W * C;
    INIT_FEAT: for (int k = 0; k < N; k++) {
        data_t v = data_t((float)(k % 7) * 0.125f - 0.375f);
        feat_map[k]  = v;
        feat_orig[k] = v;
    }

    // Zero all weight matrices (attention and MLP outputs become 0;
    // both residuals then reproduce the original input).
    ZERO_WQKV: for (int i = 0; i < C; i++)
        for (int j = 0; j < 3*C; j++)
            W_QKV[i][j] = weight_t(0);
    ZERO_BQKV: for (int j = 0; j < 3*C; j++)  b_QKV[j]  = weight_t(0);

    ZERO_WO:  for (int i = 0; i < C; i++)
        for (int j = 0; j < C; j++)
            W_O[i][j] = weight_t(0);
    ZERO_BO:  for (int j = 0; j < C; j++)  b_O[j]   = weight_t(0);

    // Identity LayerNorm affine parameters (gamma=1, beta=0)
    INIT_LN: for (int c = 0; c < C; c++) {
        gamma1[c] = weight_t(1.0f);  beta1[c] = weight_t(0);
        gamma2[c] = weight_t(1.0f);  beta2[c] = weight_t(0);
    }

    ZERO_FC1: for (int i = 0; i < C; i++)
        for (int j = 0; j < MLP_DIM; j++)
            W_FC1[i][j] = weight_t(0);
    ZERO_BFC1: for (int j = 0; j < MLP_DIM; j++) b_FC1[j] = weight_t(0);

    ZERO_FC2: for (int i = 0; i < MLP_DIM; i++)
        for (int j = 0; j < C; j++)
            W_FC2[i][j] = weight_t(0);
    ZERO_BFC2: for (int j = 0; j < C; j++) b_FC2[j] = weight_t(0);

    ZERO_RB: for (int h = 0; h < HEADS; h++)
        for (int i = 0; i < M2; i++)
            for (int j = 0; j < M2; j++)
                rel_bias[h][i][j] = weight_t(0);

    // ----------------------------------------------------------------
    // Run the FULL Swin Transformer block (W-MSA, no cyclic shift).
    // This exercises all 12 pipeline steps sequentially for each of
    // the N_WINDOWS windows.
    // ----------------------------------------------------------------
    swin_block(
        feat_map,
        W_QKV, b_QKV, W_O, b_O,
        gamma1, beta1, gamma2, beta2,
        W_FC1, b_FC1, W_FC2, b_FC2,
        rel_bias,
        0  // shifted=0: W-MSA (no cyclic shift)
    );

    // ----------------------------------------------------------------
    // Verify: output must equal input within ±4 LSB
    // data_t = ap_fixed<16,6>: LSB = 2^-10 ≈ 0.001
    // Tolerance allows for rounding through residual_add casts.
    // ----------------------------------------------------------------
    const float TOL = 4.0f / 1024.0f;

    ap_uint<1> ok = 1;
    CHECK: for (int k = 0; k < N; k++) {
        float diff = (float)feat_map[k] - (float)feat_orig[k];
        if (diff < 0.0f) diff = -diff;
        if (diff > TOL)  ok = 0;
    }

    *swin_pass = ok;
}

