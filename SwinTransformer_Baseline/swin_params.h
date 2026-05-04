#ifndef SWIN_PARAMS_H
#define SWIN_PARAMS_H

//   Model config: Swin-T, Stage 1
//   Window size M=7 so M2=49 tokens per window
//   Embedding dim C=96
//   Attention heads=3, head_dim=32
//   MLP expansion alpha=4 so MLP_DIM=384
//   Feature map: 56x56 (224/4), giving N_WINDOWS=64


// Parameters
#define M           7           // Window side length
#define M2          49          // Tokens per window (M*M)
#define C           96          // Embedding / channel dimension
#define HEADS       3           // Number of attention heads
#define D_HEAD      32          // Per-head dimension (C / HEADS)
#define MLP_DIM     384         // MLP hidden dimension (alpha * C, alpha=4)

// Feature map dimensions after patch embedding (224x224 image, patch=4)
#define FEAT_H      56          // Feature map height
#define FEAT_W      56          // Feature map width
#define N_WINDOWS   64          // Total windows (FEAT_H/M * FEAT_W/M = 8*8)

// Shift amount for SW-MSA (floor(M/2) = 3)
#define SHIFT       3


// Data types
// ap_fixed<16,6> substitution for optimization
typedef float data_t;       // token activations
typedef float weight_t;     // weight matrices
typedef float acc_t;        // accumulator 
typedef float score_t;      // attention scores (pre/post softmax)


#define SOFTMAX_EPS 1e-6f

// Scale factor for attention scores: 1 / sqrt(D_HEAD)
// 1/sqrt(32) = 0.17678...
#define ATTN_SCALE  0.17677669529663689f


// Relative position bias table dimensions
#define RPB_DIM     (M2 * M2)   // 2401 entries per head


// AXI interface bundle names (used in INTERFACE pragmas) if needed
#define BUNDLE_WEIGHTS  "weights"
#define BUNDLE_BIAS     "bias"

#endif // SWIN_PARAMS_H
