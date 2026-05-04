
// swin_block.cpp
//
// Top-level HLS kernel: one complete Swin Transformer block.


#include "swin_params.h"
#include "swin_layernorm.h"
#include "swin_qkv.h"
#include "swin_attention.h"   // defines window_attention_masked
#include "swin_mlp.h"         // defines mlp_block
#include "swin_window.h"      // defines load_window, store_window, compute_sw_mask


// residual_add
// Element-wise addition: out[i][c] = a[i][c] + b[i][c]
// Used for both attention and MLP residual connections.

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
// Deep copy tokens_src -> tokens_dst (used to save residual before LN).

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


void swin_block(
    // Feature map: read before processing, written back after all windows
    data_t   feat_map[FEAT_H * FEAT_W * C],

    // Attention weights (shared across all windows)
    weight_t W_QKV   [C][3*C],
    weight_t b_QKV   [3*C],
    weight_t W_O     [C][C],
    weight_t b_O     [C],

    // Layer norm parameters
    weight_t gamma1  [C],
    weight_t beta1   [C],
    weight_t gamma2  [C],
    weight_t beta2   [C],

    // MLP weights
    weight_t W_FC1   [C][MLP_DIM],
    weight_t b_FC1   [MLP_DIM],
    weight_t W_FC2   [MLP_DIM][C],
    weight_t b_FC2   [C],

    // Relative position bias (pre-expanded to [HEADS][M2][M2])
    weight_t rel_bias[HEADS][M2][M2],

    // Control: 0 = W-MSA (regular), 1 = SW-MSA (shifted)
    int      shifted
) {
    
    // Main window loop — processes all N_WINDOWS windows serially
    for (int wy = 0; wy < FEAT_H / M; wy++) {      // window row
        for (int wx = 0; wx < FEAT_W / M; wx++) {  // window col

            
            // Local on-chip buffers for this window's computation
            
            data_t tokens   [M2][C];   // working token buffer
            data_t residual1[M2][C];   // residual for attention sub-block
            data_t residual2[M2][C];   // residual for MLP sub-block
            data_t ln_out   [M2][C];   // LayerNorm output
            data_t attn_out [M2][C];   // attention sub-block output
            data_t mlp_out  [M2][C];   // MLP sub-block output

            data_t Q_heads[HEADS][M2][D_HEAD];
            data_t K_heads[HEADS][M2][D_HEAD];
            data_t V_heads[HEADS][M2][D_HEAD];

            // SW-MSA attention mask (zero for W-MSA, computed for SW-MSA)
            score_t sw_mask[M2][M2];

          
            // Step 1: Load window tokens from feature map
            //         Cyclic shift applied here for SW-MSA
            load_window(feat_map, tokens, wy, wx, (bool)shifted);

          
            // Step 2: Save residual before attention sub-block
          
            copy_tokens(tokens, residual1);

          
            // Step 3: LayerNorm 1
          
            layer_norm(tokens, ln_out, gamma1, beta1);

          
            // Step 4: QKV projection
          
            qkv_projection(ln_out, W_QKV, b_QKV, Q_heads, K_heads, V_heads);

          
            // Step 5: Build SW-MSA mask (only for shifted windows)
            //         For W-MSA all entries are 0 — no masking needed.
            //
            //         The mask is added to scores inside window_attention_masked.
            //         At baseline, we pass the mask as an extra argument and
            //         add it to the score matrix before softmax.
          
            if (shifted) {
                compute_sw_mask(wy, wx, sw_mask);
            } else {
                // Zero mask for W-MSA
                for (int i = 0; i < M2; i++) {
                    for (int j = 0; j < M2; j++) {
                        sw_mask[i][j] = 0.0f;
                    }
                }
            }

          
            // Step 6: Window attention (scores + softmax + context + out_proj)
            //
            // We call a mask-aware variant that adds sw_mask to scores
            // before softmax.  This is the same function for W-MSA and
            // SW-MSA — when sw_mask is all zeros it has no effect.
          
            window_attention_masked(
                Q_heads, K_heads, V_heads,
                rel_bias, sw_mask,
                W_O, b_O,
                attn_out
            );

          
            // Step 7: Residual add — attention sub-block
            
          
            residual_add(attn_out, residual1, tokens);

          
            // Step 8: Save residual before MLP sub-block
          
            copy_tokens(tokens, residual2);

          
            // Step 9: LayerNorm 2
          
            layer_norm(tokens, ln_out, gamma2, beta2);

          
            // Step 10: MLP block (FC1 + GELU + FC2)
          
            mlp_block(ln_out, W_FC1, b_FC1, W_FC2, b_FC2, mlp_out);

          
            // Step 11: Residual add — MLP sub-block
            residual_add(mlp_out, residual2, tokens);

          
            // Step 12: Write output tokens back to feature map
            //          Inverse cyclic shift applied by store_window for SW-MSA
          
            store_window(tokens, feat_map, wy, wx, (bool)shifted);

        } // wx
    } // wy
}

// window_attention_masked is defined in swin_attention.h (included above).
