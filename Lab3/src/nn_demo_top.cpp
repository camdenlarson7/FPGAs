#include "ap_int.h"
#include <stdint.h>

// Dimensions and explicit types

// Part A — Linear layer
typedef ap_int<8>  lin_t;
typedef ap_int<32> lin_acc_t;
static const int LD = 64;
static const int LO = 32;
void optimized_layer_pl(lin_t x[LD], lin_t w[LD][LO], lin_acc_t y[LO]);

// Part B — Conv layer
typedef int8_t   conv_t;
typedef int32_t  conv_acc_t;
static const int H_IN  = 16, W_IN  = 16, C_IN = 8;
static const int K     = 3;
static const int O_CH  = 8;
static const int H_OUT = H_IN - K + 1;   // 14
static const int W_OUT = W_IN - K + 1;   // 14
void conv_optimized(conv_t X[H_IN][W_IN][C_IN],
                    conv_t W_k[K][K][C_IN][O_CH],
                    conv_acc_t Y[H_OUT][W_OUT][O_CH]);

// Demo top function
void nn_demo_top(ap_uint<1> *linear_pass, ap_uint<1> *conv_pass)
{
#pragma HLS INTERFACE ap_ctrl_hs port=return
#pragma HLS INTERFACE ap_none    port=linear_pass
#pragma HLS INTERFACE ap_none    port=conv_pass

    // Part A: Linear layer test
    lin_t     x[LD];
    lin_t     w[LD][LO];
    lin_acc_t y_opt[LO];
    lin_acc_t y_golden[LO];

    // Initialise test vector
    INIT_X: for (int i = 0; i < LD; i++)
        x[i] = (lin_t)((i % 5) - 2);

    INIT_W: for (int i = 0; i < LD; i++)
        for (int j = 0; j < LO; j++)
            w[i][j] = (lin_t)(((i + j) % 5) - 2);

    // Run optimised HLS kernel
    optimized_layer_pl(x, w, y_opt);

    // Inline golden reference
    GOLDEN_J: for (int j = 0; j < LO; j++) {
        lin_acc_t sum = 0;
        GOLDEN_I: for (int i = 0; i < LD; i++)
            sum += (lin_acc_t)(x[i] * w[i][j]);
        y_golden[j] = sum;
    }

    // Compare — any mismatch clears pass
    ap_uint<1> lin_ok = 1;
    CMP_LIN: for (int j = 0; j < LO; j++)
        if (y_opt[j] != y_golden[j]) { lin_ok = 0; break; }
    *linear_pass = lin_ok;

    // Part B: Convolution layer test
    conv_t    X[H_IN][W_IN][C_IN];
    conv_t    Wk[K][K][C_IN][O_CH];
    conv_acc_t Y_opt[H_OUT][W_OUT][O_CH];
    conv_acc_t Y_golden[H_OUT][W_OUT][O_CH];

    // Initialise test data
    INIT_XF: for (int h = 0; h < H_IN; h++)
        for (int ww = 0; ww < W_IN; ww++)
            for (int c = 0; c < C_IN; c++)
                X[h][ww][c] = (conv_t)(((h + ww + c) % 5) - 2);

    INIT_WK: for (int r = 0; r < K; r++)
        for (int s = 0; s < K; s++)
            for (int c = 0; c < C_IN; c++)
                for (int o = 0; o < O_CH; o++)
                    Wk[r][s][c][o] = (conv_t)(((r + s + c + o) % 3) - 1);

    // Run optimised HLS kernel
    conv_optimized(X, Wk, Y_opt);

    // Inline golden reference
    GOLDEN_H: for (int h = 0; h < H_OUT; h++)
        GOLDEN_W: for (int ww = 0; ww < W_OUT; ww++)
            GOLDEN_O: for (int o = 0; o < O_CH; o++) {
                conv_acc_t sum = 0;
                for (int c = 0; c < C_IN; c++)
                    for (int r = 0; r < K; r++)
                        for (int s = 0; s < K; s++)
                            sum += (conv_acc_t)X[h+r][ww+s][c] *
                                   (conv_acc_t)Wk[r][s][c][o];
                Y_golden[h][ww][o] = sum;
            }

    // Compare
    ap_uint<1> conv_ok = 1;
    CMP_H: for (int h = 0; h < H_OUT; h++)
        CMP_W: for (int ww = 0; ww < W_OUT; ww++)
            CMP_O: for (int o = 0; o < O_CH; o++)
                if (Y_opt[h][ww][o] != Y_golden[h][ww][o]) { conv_ok = 0; }
    *conv_pass = conv_ok;
}
