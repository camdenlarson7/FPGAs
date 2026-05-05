#ifndef SWIN_MLP_H
#define SWIN_MLP_H

#include "swin_params.h"
#include <hls_math.h>


// mlp_block, optimized version, PIPELINE on inner MAC loops: the k-loop in MLP FC1 and FC2, the k-loop in QKV projection



// gelu_approx
static data_t gelu_approx(acc_t x) {
    const float SQRT_2_OVER_PI = 0.7978845608028654f;
    const float COEFF          = 0.044715f;
    float xf       = (float)x;
    float x3       = xf * xf * xf;
    float inner    = SQRT_2_OVER_PI * (xf + COEFF * x3);
    float tanh_val = hls::tanh(inner);
    float result   = 0.5f * xf * (1.0f + tanh_val);
    return data_t(result);
}

// mlp_block
void mlp_block(
    data_t   tokens[M2][C],
    weight_t W_FC1 [C][MLP_DIM],
    weight_t b_FC1 [MLP_DIM],
    weight_t W_FC2 [MLP_DIM][C],
    weight_t b_FC2 [C],
    data_t   out   [M2][C]
) {
    data_t hidden[M2][MLP_DIM];

    // FC1: tokens [M2][C] x W_FC1 [C][MLP_DIM] -> hidden [M2][MLP_DIM]
    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < MLP_DIM; j++) {
            acc_t acc = acc_t(b_FC1[j]);
            // PIPELINE II=1 on the innermost k-loop.
            // HLS schedules one new multiply-accumulate per clock cycle.
            for (int k = 0; k < C; k++) {
                #pragma HLS PIPELINE II=1
                acc += acc_t(tokens[i][k]) * acc_t(W_FC1[k][j]);
            }
            hidden[i][j] = gelu_approx(acc);
        }
    }

    // FC2: hidden [M2][MLP_DIM] x W_FC2 [MLP_DIM][C] -> out [M2][C] 
    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < C; j++) {
            acc_t acc = acc_t(b_FC2[j]);
            // Same pattern: PIPELINE II=1 on the innermost k-loop.
            // k < MLP_DIM=384 -> 384 pipelined cycles per (i,j) output.
            for (int k = 0; k < MLP_DIM; k++) {
                #pragma HLS PIPELINE II=1
                acc += acc_t(hidden[i][k]) * acc_t(W_FC2[k][j]);
            }
            out[i][j] = data_t(acc);
        }
    }
}

#endif // SWIN_MLP_H
