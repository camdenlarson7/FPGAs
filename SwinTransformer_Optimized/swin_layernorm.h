#ifndef SWIN_LAYERNORM_H
#define SWIN_LAYERNORM_H

#include "swin_params.h"
#include <hls_math.h>


// layer_norm, optimized version

void layer_norm(
    data_t   in   [M2][C],
    data_t   out  [M2][C],
    weight_t gamma[C],
    weight_t beta [C]
) {
    const acc_t LN_EPS = acc_t(1e-4f);
    const acc_t INV_C  = acc_t(1.0f / (float)C);

    for (int i = 0; i < M2; i++) {

        // Pass 1: mean
        acc_t sum = acc_t(0);
        for (int c = 0; c < C; c++) {
            sum += acc_t(in[i][c]);
        }
        acc_t mean = sum * INV_C;

        // Pass 2: variance
        acc_t var_sum = acc_t(0);
        for (int c = 0; c < C; c++) {
            acc_t diff = acc_t(in[i][c]) - mean;
            var_sum += diff * diff;
        }
        acc_t var = var_sum * INV_C;

        // Pass 3: normalise + affine
        // Cast to float to resolve hls::sqrt overload, then cast back.
        float var_f   = (float)(var + LN_EPS);
        acc_t inv_std = acc_t(1.0f) / acc_t(hls::sqrt(var_f));

        for (int c = 0; c < C; c++) {
            acc_t normed = (acc_t(in[i][c]) - mean) * inv_std;
            out[i][c] = data_t(acc_t(gamma[c]) * normed + acc_t(beta[c]));
        }
    }
}

#endif // SWIN_LAYERNORM_H
