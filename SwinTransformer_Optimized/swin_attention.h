#ifndef SWIN_ATTENTION_H
#define SWIN_ATTENTION_H

#include "swin_params.h"
#include <hls_math.h>


// swin_attention.h, Optimized Version: PIPELINE on inner MAC loops(d-loop, j-loop and the k-loop on Attention)


void window_attention_masked(
    data_t   Q_heads [HEADS][M2][D_HEAD],
    data_t   K_heads [HEADS][M2][D_HEAD],
    data_t   V_heads [HEADS][M2][D_HEAD],
    weight_t rel_bias[HEADS][M2][M2],
    score_t  mask    [M2][M2],
    weight_t W_O     [C][C],
    weight_t b_O     [C],
    data_t   out     [M2][C]
) {
    score_t scores[HEADS][M2][M2];

    // Scaled dot-product + bias + mask 
    for (int h = 0; h < HEADS; h++) {
        for (int i = 0; i < M2; i++) {
            for (int j = 0; j < M2; j++) {
                acc_t acc = acc_t(0);
                // d < D_HEAD=32: inner MAC loop.
                // Loop-carried dep: scalar `acc` only (1-cycle add latency).
                for (int d = 0; d < D_HEAD; d++) {
                    #pragma HLS PIPELINE II=1
                    acc += acc_t(Q_heads[h][i][d]) * acc_t(K_heads[h][j][d]);
                }
                score_t scaled = score_t(acc * acc_t(ATTN_SCALE));
                scores[h][i][j] = scaled + score_t(rel_bias[h][i][j]) + mask[i][j];
            }
        }
    }

    // Row-wise softmax
    for (int h = 0; h < HEADS; h++) {
        for (int i = 0; i < M2; i++) {

            // Pass 1: find row maximum
            score_t max_val = scores[h][i][0];
            for (int j = 1; j < M2; j++) {
                if (scores[h][i][j] > max_val) max_val = scores[h][i][j];
            }

            // Pass 2: exp(x-max) + accumulate denominator
            acc_t denom = acc_t(0);
            for (int j = 0; j < M2; j++) {
                score_t shifted = scores[h][i][j] - max_val;
                float e_f = hls::exp((float)shifted);
                score_t e = score_t(e_f);
                scores[h][i][j] = e;
                denom += acc_t(e);
            }

            // Pass 3: normalise
            acc_t inv_denom = acc_t(1.0f) / (denom + acc_t(SOFTMAX_EPS));
            for (int j = 0; j < M2; j++) {
                scores[h][i][j] = score_t(acc_t(scores[h][i][j]) * inv_denom);
            }
        }
    }

    // Context vectors (concatenated over heads)
    data_t ctx[M2][C];
    for (int i = 0; i < M2; i++)
        for (int c = 0; c < C; c++)
            ctx[i][c] = data_t(0);

    for (int h = 0; h < HEADS; h++) {
        int head_offset = h * D_HEAD;
        for (int i = 0; i < M2; i++) {
            for (int d = 0; d < D_HEAD; d++) {
            
                acc_t partial = acc_t(ctx[i][head_offset + d]);
                for (int j = 0; j < M2; j++) {
                    #pragma HLS PIPELINE II=1
                    partial += acc_t(scores[h][i][j]) * acc_t(V_heads[h][j][d]);
                }
                ctx[i][head_offset + d] = data_t(partial);
            }
        }
    }

    // Output projection  out = ctx @ W_O + b_O 
    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < C; j++) {
            acc_t acc = acc_t(b_O[j]);
            // k < C=96: same pattern as QKV and MLP k-loops.
            for (int k = 0; k < C; k++) {
                #pragma HLS PIPELINE II=1
                acc += acc_t(ctx[i][k]) * acc_t(W_O[k][j]);
            }
            out[i][j] = data_t(acc);
        }
    }
}

#endif // SWIN_ATTENTION_H
