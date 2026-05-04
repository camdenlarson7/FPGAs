#ifndef SWIN_WINDOW_H
#define SWIN_WINDOW_H

#include "swin_params.h"


// swin_window.h
// Window extraction and insertion utilities for W-MSA and SW-MSA.


// Flat feature map type: feat_map[FEAT_H * FEAT_W * C]
// Indexed as feat_map[ (row*FEAT_W + col)*C + ch ]
#define FEAT_IDX(row, col, ch)  (((row)*FEAT_W + (col))*C + (ch))


// load_window
// Extracts one M x M window from the feature map into tokens[M2][C].
// Applies the cyclic shift address mapping when shifted=true.

void load_window(
    data_t  feat_map[FEAT_H * FEAT_W * C],  // full feature map (flat)
    data_t  tokens  [M2][C],                // output: extracted window tokens
    int     wy,                              // window row index [0, FEAT_H/M)
    int     wx,                              // window col index [0, FEAT_W/M)
    bool    shifted                          // true for SW-MSA cyclic shift
) {
    for (int r = 0; r < M; r++) {           // local row within window
        for (int c = 0; c < M; c++) {       // local col within window

            // Compute source coordinates in the feature map
            int src_row, src_col;
            if (shifted) {
                // Cyclic shift: roll feature map by +SHIFT before windowing
                // Equivalent to shifting windows by -SHIFT (SW-MSA)
                src_row = (wy * M + r + SHIFT) % FEAT_H;
                src_col = (wx * M + c + SHIFT) % FEAT_W;
            } else {
                src_row = wy * M + r;
                src_col = wx * M + c;
            }

            int token_idx = r * M + c;  // position in [0, M2)
            int src_base  = FEAT_IDX(src_row, src_col, 0);

            for (int ch = 0; ch < C; ch++) {
                tokens[token_idx][ch] = feat_map[src_base + ch];
            }
        }
    }
}


// store_window
//
// Writes output tokens [M2][C] back to the feature map.
// Applies inverse cyclic shift (same address formula) when shifted=true.
void store_window(
    data_t  tokens  [M2][C],
    data_t  feat_map[FEAT_H * FEAT_W * C],
    int     wy,
    int     wx,
    bool    shifted
) {
    for (int r = 0; r < M; r++) {
        for (int c = 0; c < M; c++) {
            int dst_row, dst_col;
            if (shifted) {
                dst_row = (wy * M + r + SHIFT) % FEAT_H;
                dst_col = (wx * M + c + SHIFT) % FEAT_W;
            } else {
                dst_row = wy * M + r;
                dst_col = wx * M + c;
            }

            int token_idx = r * M + c;
            int dst_base  = FEAT_IDX(dst_row, dst_col, 0);

            for (int ch = 0; ch < C; ch++) {
                feat_map[dst_base + ch] = tokens[token_idx][ch];
            }
        }
    }
}


// compute_sw_mask
//
// Builds the [M2][M2] attention mask for SW-MSA window (wy, wx).
//
// After the cyclic shift by SHIFT, a window may contain tokens from
// two or more originally non-adjacent image regions along each axis.
// The mask prevents cross-region attention.
//
// For each token i at local position (ri, ci), the region ID along
// each axis is:
//
//   region_row(r) = (r + wy*M) / (FEAT_H - SHIFT)   [0 or 1]
//   region_col(c) = (c + wx*M) / (FEAT_W - SHIFT)   [0 or 1]
//
// Two tokens i, j may attend to each other only if they share both
// region_row and region_col.  Otherwise mask[i][j] = -1e9.
//
// mask[i][j] = 0.0     if same region
//            = -1e9    if different region
void compute_sw_mask(
    int     wy,
    int     wx,
    score_t mask[M2][M2]
) {
    // For each local token position compute its global region ID
    int region_row[M2];
    int region_col[M2];

    for (int r = 0; r < M; r++) {
        for (int c = 0; c < M; c++) {
            int tok = r * M + c;
            // Global row/col after the cyclic shift
            int grow = (wy * M + r + SHIFT) % FEAT_H;
            int gcol = (wx * M + c + SHIFT) % FEAT_W;
            // Region: 0 = top/left block, 1 = bottom/right edge block
            region_row[tok] = (grow >= (FEAT_H - SHIFT)) ? 1 : 0;
            region_col[tok] = (gcol >= (FEAT_W - SHIFT)) ? 1 : 0;
        }
    }

    // Build mask
    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < M2; j++) {
            if (region_row[i] == region_row[j] &&
                region_col[i] == region_col[j]) {
                mask[i][j] = 0.0f;
            } else {
                mask[i][j] = -1.0e9f;  // close to -infinity
            }
        }
    }
}

#endif // SWIN_WINDOW_H
