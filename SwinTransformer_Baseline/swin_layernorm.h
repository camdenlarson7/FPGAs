#ifndef SWIN_LAYERNORM_H
#define SWIN_LAYERNORM_H

#include "swin_params.h"
#include <math.h>

// ============================================================================
// layer_norm
// in       : input tokens  [M2][C]
// out      : normalised tokens [M2][C]  (
// gamma    : learnable scale  [C]
// beta     : learnable bias   [C]

void layer_norm(
    data_t  in   [M2][C],
    data_t  out  [M2][C],
    weight_t gamma[C],
    weight_t beta [C]
) {
    // iterate over tokens 
    for (int i = 0; i < M2; i++) {

        // Pass 1: compute mean
        acc_t mean = 0.0f;
        for (int c = 0; c < C; c++) {
            mean += in[i][c];
        }
        mean /= (acc_t)C;

        // Pass 2: compute variance
        acc_t var = 0.0f;
        for (int c = 0; c < C; c++) {
            acc_t diff = in[i][c] - mean;
            var += diff * diff;
        }
        var /= (acc_t)C;

        // Pass 3: normalise and transform
        acc_t inv_std = 1.0f / sqrtf(var + SOFTMAX_EPS);
        for (int c = 0; c < C; c++) {
            out[i][c] = (data_t)(gamma[c] * ((data_t)inv_std *
                        (in[i][c] - (data_t)mean)) + beta[c]);
        }
    }
}

#endif // SWIN_LAYERNORM_H
