// swin_block.cpp, fixed-point implementation
// Top-level HLS kernel: one complete Swin Transformer block.


#include "swin_params.h"
#include "swin_layernorm.h"
#include "swin_qkv.h"
#include "swin_attention.h"
#include "swin_mlp.h"
#include "swin_window.h"


// residual_add
static void residual_add(
    data_t a  [M2][C],
    data_t b  [M2][C],
    data_t out[M2][C]
) {
    for (int i = 0; i < M2; i++) {
        for (int c = 0; c < C; c++) {
            out[i][c] = a[i][c] + b[i][c];
        }
    }
}


// copy_tokens
static void copy_tokens(
    data_t src[M2][C],
    data_t dst[M2][C]
) {
    for (int i = 0; i < M2; i++) {
        for (int c = 0; c < C; c++) {
            dst[i][c] = src[i][c];
        }
    }
}

// swin_block 
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
) {
    
    for (int wy = 0; wy < FEAT_H / WIN_SIZE; wy++) {
        for (int wx = 0; wx < FEAT_W / WIN_SIZE; wx++) {

            data_t tokens   [M2][C];
            data_t residual1[M2][C];
            data_t residual2[M2][C];
            data_t ln_out   [M2][C];
            data_t attn_out [M2][C];
            data_t mlp_out  [M2][C];

            data_t  Q_heads[HEADS][M2][D_HEAD];
            data_t  K_heads[HEADS][M2][D_HEAD];
            data_t  V_heads[HEADS][M2][D_HEAD];
            score_t sw_mask[M2][M2];

            // Step 1: Load window
            load_window(feat_map, tokens, wy, wx, (bool)shifted);

            // Step 2: Save attention residual
            copy_tokens(tokens, residual1);

            // Step 3: LayerNorm 1
            layer_norm(tokens, ln_out, gamma1, beta1);

            // Step 4: QKV projection
            qkv_projection(ln_out, W_QKV, b_QKV, Q_heads, K_heads, V_heads);

            // Step 5: Build SW-MSA mask
            if (shifted) {
                compute_sw_mask(wy, wx, sw_mask);
            } else {
                for (int i = 0; i < M2; i++)
                    for (int j = 0; j < M2; j++)
                        sw_mask[i][j] = score_t(0);
            }

            // Step 6: Window attention
            window_attention_masked(
                Q_heads, K_heads, V_heads,
                rel_bias, sw_mask,
                W_O, b_O,
                attn_out
            );

            // Step 7: Residual add (attention)
            residual_add(attn_out, residual1, tokens);

            // Step 8: Save MLP residual
            copy_tokens(tokens, residual2);

            // Step 9: LayerNorm 2
            layer_norm(tokens, ln_out, gamma2, beta2);

            // Step 10: MLP block
            mlp_block(ln_out, W_FC1, b_FC1, W_FC2, b_FC2, mlp_out);

            // Step 11: Residual add (MLP)
            residual_add(mlp_out, residual2, tokens);

            // Step 12: Write window back
            store_window(tokens, feat_map, wy, wx, (bool)shifted);

        } // wx
    } // wy
}
