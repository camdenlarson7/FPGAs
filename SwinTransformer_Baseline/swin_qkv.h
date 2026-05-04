#ifndef SWIN_QKV_H
#define SWIN_QKV_H

#include "swin_params.h"


// qkv_projection
//
// Projects M2 token vectors of dimension C into Q, K, V matrices.
// The three projections share a single weight matrix W_QKV [C][3*C]
// organised as:
//
//   columns  0 .. C-1      -> Q projection
//   columns  C .. 2C-1     -> K projection
//   columns 2C .. 3C-1     -> V projection
void qkv_projection(
    data_t   tokens [M2][C],
    weight_t W_QKV  [C][3*C],
    weight_t b_QKV  [3*C],
    data_t   Q_heads[HEADS][M2][D_HEAD],
    data_t   K_heads[HEADS][M2][D_HEAD],
    data_t   V_heads[HEADS][M2][D_HEAD]
) {
    // Compute combined QKV = tokens x W_QKV + b_QKV 
    // Temporary flat output: qkv[token][output_channel]
    data_t qkv[M2][3*C];

    for (int i = 0; i < M2; i++) {             // over tokens
        for (int j = 0; j < 3*C; j++) {        // over output channels
            acc_t acc = (acc_t)b_QKV[j];       // bias initialisation
            for (int k = 0; k < C; k++) {      // inner product
                acc += (acc_t)tokens[i][k] * (acc_t)W_QKV[k][j];
            }
            qkv[i][j] = (data_t)acc;
        }
    }

    // Split into Q, K, V and reshape into per-head tensors
    // Q occupies columns [0,      C)
    // K occupies columns [C,     2C)
    // V occupies columns [2C,    3C)
    for (int h = 0; h < HEADS; h++) {
        for (int i = 0; i < M2; i++) {
            for (int d = 0; d < D_HEAD; d++) {
                int base_d = h * D_HEAD + d;
                Q_heads[h][i][d] = qkv[i][base_d];
                K_heads[h][i][d] = qkv[i][C      + base_d];
                V_heads[h][i][d] = qkv[i][2*C    + base_d];
            }
        }
    }
}

#endif // SWIN_QKV_H
