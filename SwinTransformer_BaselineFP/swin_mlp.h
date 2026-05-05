#ifndef SWIN_MLP_H
#define SWIN_MLP_H

#include "swin_params.h"
#include <hls_math.h>


// mlp_block, fixed-point implementation

static data_t gelu_approx(acc_t x) {
    const float SQRT_2_OVER_PI = 0.7978845608028654f;
    const float COEFF          = 0.044715f;

    // Compute in float to get a single hls::tanh call.
    float xf    = (float)x;
    float x3    = xf * xf * xf;
    float inner = SQRT_2_OVER_PI * (xf + COEFF * x3);
    float tanh_val = hls::tanh(inner);   // float overload
    float result   = 0.5f * xf * (1.0f + tanh_val);
    return data_t(result);
}

void mlp_block(
    data_t   tokens[M2][C],
    weight_t W_FC1 [C][MLP_DIM],
    weight_t b_FC1 [MLP_DIM],
    weight_t W_FC2 [MLP_DIM][C],
    weight_t b_FC2 [C],
    data_t   out   [M2][C]
) {
    // FC1: [M2][C] x [C][MLP_DIM] -> hidden [M2][MLP_DIM] + GELU
    data_t hidden[M2][MLP_DIM];

    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < MLP_DIM; j++) {
            acc_t acc = acc_t(b_FC1[j]);
            for (int k = 0; k < C; k++) {
                acc += acc_t(tokens[i][k]) * acc_t(W_FC1[k][j]);
            }
            hidden[i][j] = gelu_approx(acc);
        }
    }

    // FC2: [M2][MLP_DIM] x [MLP_DIM][C] -> out [M2][C]
    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < C; j++) {
            acc_t acc = acc_t(b_FC2[j]);
            for (int k = 0; k < MLP_DIM; k++) {
                acc += acc_t(hidden[i][k]) * acc_t(W_FC2[k][j]);
            }
            out[i][j] = data_t(acc);
        }
    }
}

#endif // SWIN_MLP_H
