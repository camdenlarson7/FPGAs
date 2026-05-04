
// tb_swin_block.cpp
//
// C-simulation testbench for swin_block.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "swin_params.h"

// Forward declaration of the HLS kernel
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



// helpers 
static float ref_gelu(float x) {
    const float sqrt_2_over_pi = 0.7978845608028654f;
    const float coeff          = 0.044715f;
    float inner = sqrt_2_over_pi * (x + coeff * x * x * x);
    return 0.5f * x * (1.0f + tanhf(inner));
}

static void ref_layer_norm(
    float in[M2][C], float out[M2][C],
    float gamma[C],  float beta[C]
) {
    for (int i = 0; i < M2; i++) {
        float mean = 0.0f;
        for (int c = 0; c < C; c++) mean += in[i][c];
        mean /= C;
        float var = 0.0f;
        for (int c = 0; c < C; c++) {
            float d = in[i][c] - mean; var += d*d;
        }
        var /= C;
        float inv_std = 1.0f / sqrtf(var + 1e-6f);
        for (int c = 0; c < C; c++) {
            out[i][c] = gamma[c] * inv_std * (in[i][c] - mean) + beta[c];
        }
    }
}

// Reference: one window forward pass (W-MSA or SW-MSA via mask)
static void ref_window_block(
    float tokens[M2][C],
    float W_QKV [C][3*C], float b_QKV[3*C],
    float W_O   [C][C],   float b_O  [C],
    float gamma1[C],      float beta1[C],
    float gamma2[C],      float beta2[C],
    float W_FC1 [C][MLP_DIM], float b_FC1[MLP_DIM],
    float W_FC2 [MLP_DIM][C], float b_FC2[C],
    float rel_bias[HEADS][M2][M2],
    float mask [M2][M2]   // additive attention mask (0 or -1e9)
) {
    // Save residual 1
    float res1[M2][C];
    memcpy(res1, tokens, sizeof(res1));

    // LN1
    float ln1[M2][C];
    ref_layer_norm(tokens, ln1, gamma1, beta1);

    // QKV projection
    float qkv[M2][3*C];
    for (int i = 0; i < M2; i++)
        for (int j = 0; j < 3*C; j++) {
            float acc = b_QKV[j];
            for (int k = 0; k < C; k++) acc += ln1[i][k] * W_QKV[k][j];
            qkv[i][j] = acc;
        }

    // Split Q, K, V into per-head
    float Q[HEADS][M2][D_HEAD], K[HEADS][M2][D_HEAD], V[HEADS][M2][D_HEAD];
    for (int h = 0; h < HEADS; h++)
        for (int i = 0; i < M2; i++)
            for (int d = 0; d < D_HEAD; d++) {
                Q[h][i][d] = qkv[i][h*D_HEAD + d];
                K[h][i][d] = qkv[i][C + h*D_HEAD + d];
                V[h][i][d] = qkv[i][2*C + h*D_HEAD + d];
            }

    // Attention scores + softmax + context
    float ctx[M2][C];
    memset(ctx, 0, sizeof(ctx));

    float scores[M2][M2];
    for (int h = 0; h < HEADS; h++) {
        // Scores
        for (int i = 0; i < M2; i++)
            for (int j = 0; j < M2; j++) {
                float acc = 0.0f;
                for (int d = 0; d < D_HEAD; d++)
                    acc += Q[h][i][d] * K[h][j][d];
                scores[i][j] = acc * ATTN_SCALE + rel_bias[h][i][j] + mask[i][j];
            }
        // Softmax
        for (int i = 0; i < M2; i++) {
            float mx = scores[i][0];
            for (int j = 1; j < M2; j++) if (scores[i][j] > mx) mx = scores[i][j];
            float sum = 0.0f;
            for (int j = 0; j < M2; j++) { scores[i][j] = expf(scores[i][j]-mx); sum += scores[i][j]; }
            float inv = 1.0f / (sum + 1e-6f);
            for (int j = 0; j < M2; j++) scores[i][j] *= inv;
        }
        // Context
        int off = h * D_HEAD;
        for (int i = 0; i < M2; i++)
            for (int j = 0; j < M2; j++)
                for (int d = 0; d < D_HEAD; d++)
                    ctx[i][off+d] += scores[i][j] * V[h][j][d];
    }

    // Output projection
    float attn_out[M2][C];
    for (int i = 0; i < M2; i++)
        for (int j = 0; j < C; j++) {
            float acc = b_O[j];
            for (int k = 0; k < C; k++) acc += ctx[i][k] * W_O[k][j];
            attn_out[i][j] = acc;
        }

    // Residual add 1
    for (int i = 0; i < M2; i++)
        for (int c = 0; c < C; c++)
            tokens[i][c] = attn_out[i][c] + res1[i][c];

    // Save residual 2
    float res2[M2][C];
    memcpy(res2, tokens, sizeof(res2));

    // LN2
    float ln2[M2][C];
    ref_layer_norm(tokens, ln2, gamma2, beta2);

    // FC1 + GELU
    float hidden[M2][MLP_DIM];
    for (int i = 0; i < M2; i++)
        for (int j = 0; j < MLP_DIM; j++) {
            float acc = b_FC1[j];
            for (int k = 0; k < C; k++) acc += ln2[i][k] * W_FC1[k][j];
            hidden[i][j] = ref_gelu(acc);
        }

    // FC2
    float mlp_out[M2][C];
    for (int i = 0; i < M2; i++)
        for (int j = 0; j < C; j++) {
            float acc = b_FC2[j];
            for (int k = 0; k < MLP_DIM; k++) acc += hidden[i][k] * W_FC2[k][j];
            mlp_out[i][j] = acc;
        }

    // Residual add 2
    for (int i = 0; i < M2; i++)
        for (int c = 0; c < C; c++)
            tokens[i][c] = mlp_out[i][c] + res2[i][c];
}

// rand_float: uniform random float in [lo, hi]
static float rand_float(float lo, float hi) {
    return lo + (hi - lo) * ((float)rand() / (float)RAND_MAX);
}


int main(void) {
    printf("=================================================================\n");
    printf("  Swin Block Baseline — C-Simulation Testbench\n");
    printf("  Config: M=%d, C=%d, HEADS=%d, D_HEAD=%d, MLP_DIM=%d\n",
           M, C, HEADS, D_HEAD, MLP_DIM);
    printf("  Windows: %d x %d = %d\n", FEAT_H/M, FEAT_W/M, N_WINDOWS);
    printf("=================================================================\n\n");

    srand(42);  // fixed seed for reproducibility

    // Allocate weight tensors
    static weight_t W_QKV [C][3*C];
    static weight_t b_QKV [3*C];
    static weight_t W_O   [C][C];
    static weight_t b_O   [C];
    static weight_t gamma1[C], beta1[C];
    static weight_t gamma2[C], beta2[C];
    static weight_t W_FC1 [C][MLP_DIM];
    static weight_t b_FC1 [MLP_DIM];
    static weight_t W_FC2 [MLP_DIM][C];
    static weight_t b_FC2 [C];
    static weight_t rel_bias[HEADS][M2][M2];

    // Randomise weights (small range to avoid large activations)
    for (int i=0; i<C; i++)
        for (int j=0; j<3*C; j++)  W_QKV[i][j]  = rand_float(-0.1f, 0.1f);
    for (int j=0; j<3*C; j++)      b_QKV[j]      = rand_float(-0.01f, 0.01f);
    for (int i=0; i<C; i++)
        for (int j=0; j<C; j++)    W_O[i][j]     = rand_float(-0.1f, 0.1f);
    for (int j=0; j<C; j++)        b_O[j]         = rand_float(-0.01f, 0.01f);
    for (int c=0; c<C; c++) { gamma1[c]=1.0f; beta1[c]=0.0f; }  // identity LN1
    for (int c=0; c<C; c++) { gamma2[c]=1.0f; beta2[c]=0.0f; }  // identity LN2
    for (int i=0; i<C; i++)
        for (int j=0; j<MLP_DIM; j++) W_FC1[i][j] = rand_float(-0.1f, 0.1f);
    for (int j=0; j<MLP_DIM; j++)     b_FC1[j]     = rand_float(-0.01f, 0.01f);
    for (int i=0; i<MLP_DIM; i++)
        for (int j=0; j<C; j++)    W_FC2[i][j]   = rand_float(-0.1f, 0.1f);
    for (int j=0; j<C; j++)        b_FC2[j]       = rand_float(-0.01f, 0.01f);
    for (int h=0; h<HEADS; h++)
        for (int i=0; i<M2; i++)
            for (int j=0; j<M2; j++)
                rel_bias[h][i][j] = rand_float(-0.05f, 0.05f);

    // Run two test cases: W-MSA (shifted=0) and SW-MSA (shifted=1)
    int total_pass = 1;

    for (int test = 0; test < 2; test++) {
        int shifted = test;  // 0 = W-MSA, 1 = SW-MSA
        printf("--- Test %d: %s ---\n", test, shifted ? "SW-MSA" : "W-MSA");

        // Allocate feature map 
        static data_t feat_hls[FEAT_H * FEAT_W * C];
        static float  feat_ref[FEAT_H * FEAT_W * C];

        // Fill feature map with random activations
        for (int k = 0; k < FEAT_H * FEAT_W * C; k++) {
            float v = rand_float(-1.0f, 1.0f);
            feat_hls[k] = (data_t)v;
            feat_ref[k] = v;
        }

        swin_block(
            feat_hls,
            W_QKV, b_QKV, W_O, b_O,
            gamma1, beta1, gamma2, beta2,
            W_FC1, b_FC1, W_FC2, b_FC2,
            rel_bias, shifted
        );

        // Process all windows in the same order as the kernel
        for (int wy = 0; wy < FEAT_H / M; wy++) {
            for (int wx = 0; wx < FEAT_W / M; wx++) {

                // Extract window from ref feature map
                float tokens[M2][C];
                for (int r = 0; r < M; r++) {
                    for (int c = 0; c < M; c++) {
                        int sr, sc;
                        if (shifted) {
                            sr = (wy*M + r + SHIFT) % FEAT_H;
                            sc = (wx*M + c + SHIFT) % FEAT_W;
                        } else {
                            sr = wy*M + r;
                            sc = wx*M + c;
                        }
                        int tok = r*M + c;
                        for (int ch = 0; ch < C; ch++) {
                            tokens[tok][ch] = feat_ref[(sr*FEAT_W + sc)*C + ch];
                        }
                    }
                }

                // Build SW-MSA mask
                float mask[M2][M2];
                if (shifted) {
                    int rrow[M2], rcol[M2];
                    for (int r=0; r<M; r++)
                        for (int c=0; c<M; c++) {
                            int tok = r*M+c;
                            int gr  = (wy*M+r+SHIFT) % FEAT_H;
                            int gc  = (wx*M+c+SHIFT) % FEAT_W;
                            rrow[tok] = (gr >= FEAT_H-SHIFT) ? 1 : 0;
                            rcol[tok] = (gc >= FEAT_W-SHIFT) ? 1 : 0;
                        }
                    for (int i=0; i<M2; i++)
                        for (int j=0; j<M2; j++)
                            mask[i][j] = (rrow[i]==rrow[j] && rcol[i]==rcol[j])
                                        ? 0.0f : -1e9f;
                } else {
                    memset(mask, 0, sizeof(mask));
                }

                // Run reference window block
                ref_window_block(
                    tokens,
                    W_QKV, b_QKV, W_O, b_O,
                    gamma1, beta1, gamma2, beta2,
                    W_FC1, b_FC1, W_FC2, b_FC2,
                    rel_bias, mask
                );

                // Write back to ref feature map
                for (int r = 0; r < M; r++) {
                    for (int c = 0; c < M; c++) {
                        int dr, dc;
                        if (shifted) {
                            dr = (wy*M + r + SHIFT) % FEAT_H;
                            dc = (wx*M + c + SHIFT) % FEAT_W;
                        } else {
                            dr = wy*M + r;
                            dc = wx*M + c;
                        }
                        int tok = r*M + c;
                        for (int ch = 0; ch < C; ch++) {
                            feat_ref[(dr*FEAT_W + dc)*C + ch] = tokens[tok][ch];
                        }
                    }
                }
            }
        }

        // Compare outputs 
        float max_err = 0.0f, sum_err = 0.0f;
        float max_ref = 0.0f;
        int   num_elem = FEAT_H * FEAT_W * C;

        for (int k = 0; k < num_elem; k++) {
            float err = fabsf((float)feat_hls[k] - feat_ref[k]);
            float ref = fabsf(feat_ref[k]);
            if (err     > max_err) max_err = err;
            if (ref     > max_ref) max_ref = ref;
            sum_err += err;
        }

        float mean_err  = sum_err / num_elem;
        float rel_err   = (max_ref > 1e-6f) ? (max_err / max_ref) * 100.0f : 0.0f;

        printf("  Elements checked : %d\n", num_elem);
        printf("  Max abs error    : %.6e\n", max_err);
        printf("  Mean abs error   : %.6e\n", mean_err);
        printf("  Max ref value    : %.6e\n", max_ref);
        printf("  Max rel error    : %.4f%%\n", rel_err);

        // Acceptance: max relative error < 0.01% for float32 baseline
        // (Phase 4 fixed-point relaxes this to 0.5%)
        int pass = (rel_err < 0.01f);
        printf("  Result           : %s\n\n", pass ? "PASS" : "FAIL");
        total_pass &= pass;
    }

    printf("=================================================================\n");
    printf("  Overall: %s\n", total_pass ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    printf("=================================================================\n");

    return total_pass ? 0 : 1;
}
