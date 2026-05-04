#ifndef SWIN_MLP_H
#define SWIN_MLP_H

#include "swin_params.h"
#include <math.h>

// mlp_block : 2 linear layer with GELU


// gelu_approx: tanh-based GELU approximation
static data_t gelu_approx(data_t x) {
    // Constants: sqrt(2/pi) = 0.7978845608, coefficient = 0.044715
    const float sqrt_2_over_pi = 0.7978845608028654f;
    const float coeff          = 0.044715f;

    float xf   = (float)x;
    float inner = sqrt_2_over_pi * (xf + coeff * xf * xf * xf);
    return (data_t)(0.5f * xf * (1.0f + tanhf(inner)));
}


void mlp_block(
    data_t   tokens[M2][C],
    weight_t W_FC1 [C][MLP_DIM],
    weight_t b_FC1 [MLP_DIM],
    weight_t W_FC2 [MLP_DIM][C],
    weight_t b_FC2 [C],
    data_t   out   [M2][C]
) {
    // FC1: tokens [M2][C]  x  W_FC1 [C][MLP_DIM]  ->  hidden [M2][MLP_DIM]
    data_t hidden[M2][MLP_DIM];

    for (int i = 0; i < M2; i++) {             // over tokens
        for (int j = 0; j < MLP_DIM; j++) {    // over hidden dimension
            acc_t acc = (acc_t)b_FC1[j];
            for (int k = 0; k < C; k++) {      // inner product
                acc += (acc_t)tokens[i][k] * (acc_t)W_FC1[k][j];
            }
            // Apply GELU in-place on the FC1 output
            hidden[i][j] = gelu_approx((data_t)acc);
        }
    }

    // FC2: hidden [M2][MLP_DIM]  x  W_FC2 [MLP_DIM][C]  ->  out [M2][C]
    for (int i = 0; i < M2; i++) {             // over tokens
        for (int j = 0; j < C; j++) {          // over output channels
            acc_t acc = (acc_t)b_FC2[j];
            for (int k = 0; k < MLP_DIM; k++) { // inner product
                acc += (acc_t)hidden[i][k] * (acc_t)W_FC2[k][j];
            }
            out[i][j] = (data_t)acc;
        }
    }
}

#endif // SWIN_MLP_H
