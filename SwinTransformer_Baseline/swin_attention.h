#ifndef SWIN_ATTENTION_H
#define SWIN_ATTENTION_H

#include "swin_params.h"
#include <math.h>

// ============================================================================
// swin_attention.h
//
// Multi-head window attention for a single window, with an additive mask.
//
// window_attention_masked handles both W-MSA and SW-MSA through a single
// unified function. The only difference between the two modes is the mask
// argument supplied by the caller:
//
//   W-MSA  : mask[i][j] = 0.0   for all i, j   (no masking)
//   SW-MSA : mask[i][j] = 0.0   if tokens i,j share the same region
//            mask[i][j] = -1e9  if tokens i,j come from different regions

void window_attention_masked(
    data_t   Q_heads [HEADS][M2][D_HEAD],  // [HEADS][M2][D_HEAD]
    data_t   K_heads [HEADS][M2][D_HEAD],
    data_t   V_heads [HEADS][M2][D_HEAD],
    weight_t rel_bias[HEADS][M2][M2],      // relative position bias
    score_t  mask    [M2][M2],             // additive SW-MSA mask (0 or -1e9)
    weight_t W_O     [C][C],               // output projection weight
    weight_t b_O     [C],                  // output projection bias
    data_t   out     [M2][C]               // output tokens
) {
    // Scaled dot-product scores + bias + mask 
    // Materialise the full [HEADS][M2][M2] score tensor before softmax.
    score_t scores[HEADS][M2][M2];

    for (int h = 0; h < HEADS; h++) {
        for (int i = 0; i < M2; i++) {         // query token
            for (int j = 0; j < M2; j++) {     // key token
                acc_t acc = 0.0f;
                for (int d = 0; d < D_HEAD; d++) {
                    acc += (acc_t)Q_heads[h][i][d] * (acc_t)K_heads[h][j][d];
                }
                scores[h][i][j] = (score_t)(acc * (acc_t)ATTN_SCALE)
                                + rel_bias[h][i][j]
                                + mask[i][j];   // 0.0 for W-MSA, -1e9 for masked pairs
            }
        }
    }

    // Row-wise softmax (numerically stable) 
    for (int h = 0; h < HEADS; h++) {
        for (int i = 0; i < M2; i++) {
            // Pass 1: find row maximum
            score_t max_val = scores[h][i][0];
            for (int j = 1; j < M2; j++) {
                if (scores[h][i][j] > max_val) max_val = scores[h][i][j];
            }
            // Pass 2: exp(x - max) and accumulate sum
            score_t sum = 0.0f;
            for (int j = 0; j < M2; j++) {
                scores[h][i][j] = expf(scores[h][i][j] - max_val);
                sum += scores[h][i][j];
            }
            // Pass 3: normalise
            score_t inv_sum = 1.0f / (sum + SOFTMAX_EPS);
            for (int j = 0; j < M2; j++) {
                scores[h][i][j] *= inv_sum;
            }
        }
    }

    // Context vectors 
    // ctx[i][c] = sum over heads and j of: A[h][i][j] * V[h][j][d]
    // heads are concatenated in the channel dimension.
    data_t ctx[M2][C];

    for (int i = 0; i < M2; i++) {
        for (int c = 0; c < C; c++) {
            ctx[i][c] = 0.0f;
        }
    }

    for (int h = 0; h < HEADS; h++) {
        int head_offset = h * D_HEAD;
        for (int i = 0; i < M2; i++) {         // output token
            for (int j = 0; j < M2; j++) {     // key/value token
                score_t attn_w = scores[h][i][j];
                for (int d = 0; d < D_HEAD; d++) {
                    ctx[i][head_offset + d] +=
                        (data_t)((acc_t)attn_w * (acc_t)V_heads[h][j][d]);
                }
            }
        }
    }

    // Output projection  out = ctx @ W_O + b_O 
    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < C; j++) {
            acc_t acc = (acc_t)b_O[j];
            for (int k = 0; k < C; k++) {
                acc += (acc_t)ctx[i][k] * (acc_t)W_O[k][j];
            }
            out[i][j] = (data_t)acc;
        }
    }
}

#endif // SWIN_ATTENTION_H
