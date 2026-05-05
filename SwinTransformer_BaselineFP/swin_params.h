#ifndef SWIN_PARAMS_H
#define SWIN_PARAMS_H


// swin_params.h
// Central parameter definitions for Swin-T Stage 1, Fixed-Point implementation.


#include <ap_fixed.h>


// Window / token dimensions
// WIN_SIZE replaces the legacy 'M' macro to avoid collisions with Vitis
// HLS library template parameters of the same name.

#define WIN_SIZE    7
#define M2          49          // WIN_SIZE * WIN_SIZE tokens per window
#define C           96          // Embedding / channel dimension
#define HEADS       3
#define D_HEAD      32          // C / HEADS
#define MLP_DIM     384         // 4 * C

#define FEAT_H      56
#define FEAT_W      56
#define N_WINDOWS   64          // (FEAT_H/WIN_SIZE) * (FEAT_W/WIN_SIZE)

#define SHIFT       3           // floor(WIN_SIZE/2) for SW-MSA cyclic shift


// Data types
typedef ap_fixed<16, 6>                   data_t;
typedef ap_fixed<16, 6>                   weight_t;
typedef ap_fixed<32, 16>                  acc_t;
typedef ap_fixed<16, 6, AP_TRN, AP_SAT>  score_t;

// Numerical constants
// Softmax/LN epsilon: 1e-6 underflows ap_fixed<16,6> LSB 
// 1e-4 fits comfortably and is numerically benign.
#define SOFTMAX_EPS  score_t(1e-4f)

// Attention score scale: 1/sqrt(D_HEAD=32)
#define ATTN_SCALE   weight_t(0.17677669529663689f)

// SW-MSA mask sentinel.  score_t uses AP_SAT so -1e9f clamps to ~-32.
#define MASK_NEG_INF score_t(-1e9f)

#define RPB_DIM  (M2 * M2)


// AXI interface bundle names if needed
#define BUNDLE_WEIGHTS  "weights"
#define BUNDLE_BIAS     "bias"

#endif // SWIN_PARAMS_H
