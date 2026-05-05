#ifndef SWIN_WINDOW_H
#define SWIN_WINDOW_H

#include "swin_params.h"

// swin_window.h, optimized version

#define FEAT_IDX(row, col, ch)  (((row)*FEAT_W + (col))*C + (ch))


// load_window
void load_window(
    data_t  feat_map[FEAT_H * FEAT_W * C],
    data_t  tokens  [M2][C],
    int     wy,
    int     wx,
    bool    shifted
) {
    for (int r = 0; r < WIN_SIZE; r++) {
        for (int c = 0; c < WIN_SIZE; c++) {
            int src_row, src_col;
            if (shifted) {
                src_row = (wy * WIN_SIZE + r + SHIFT) % FEAT_H;
                src_col = (wx * WIN_SIZE + c + SHIFT) % FEAT_W;
            } else {
                src_row = wy * WIN_SIZE + r;
                src_col = wx * WIN_SIZE + c;
            }
            int token_idx = r * WIN_SIZE + c;
            int src_base  = FEAT_IDX(src_row, src_col, 0);
            for (int ch = 0; ch < C; ch++) {
                tokens[token_idx][ch] = feat_map[src_base + ch];
            }
        }
    }
}


// store_window
void store_window(
    data_t  tokens  [M2][C],
    data_t  feat_map[FEAT_H * FEAT_W * C],
    int     wy,
    int     wx,
    bool    shifted
) {
    for (int r = 0; r < WIN_SIZE; r++) {
        for (int c = 0; c < WIN_SIZE; c++) {
            int dst_row, dst_col;
            if (shifted) {
                dst_row = (wy * WIN_SIZE + r + SHIFT) % FEAT_H;
                dst_col = (wx * WIN_SIZE + c + SHIFT) % FEAT_W;
            } else {
                dst_row = wy * WIN_SIZE + r;
                dst_col = wx * WIN_SIZE + c;
            }
            int token_idx = r * WIN_SIZE + c;
            int dst_base  = FEAT_IDX(dst_row, dst_col, 0);
            for (int ch = 0; ch < C; ch++) {
                feat_map[dst_base + ch] = tokens[token_idx][ch];
            }
        }
    }
}


// compute_sw_mask
void compute_sw_mask(
    int     wy,
    int     wx,
    score_t mask[M2][M2]
) {
    int region_row[M2];
    int region_col[M2];

    for (int r = 0; r < WIN_SIZE; r++) {
        for (int c = 0; c < WIN_SIZE; c++) {
            int tok  = r * WIN_SIZE + c;
            int grow = (wy * WIN_SIZE + r + SHIFT) % FEAT_H;
            int gcol = (wx * WIN_SIZE + c + SHIFT) % FEAT_W;
            region_row[tok] = (grow >= (FEAT_H - SHIFT)) ? 1 : 0;
            region_col[tok] = (gcol >= (FEAT_W - SHIFT)) ? 1 : 0;
        }
    }

    for (int i = 0; i < M2; i++) {
        for (int j = 0; j < M2; j++) {
            if (region_row[i] == region_row[j] &&
                region_col[i] == region_col[j]) {
                mask[i][j] = score_t(0);
            } else {
                mask[i][j] = MASK_NEG_INF;  
            }
        }
    }
}

#endif // SWIN_WINDOW_H
