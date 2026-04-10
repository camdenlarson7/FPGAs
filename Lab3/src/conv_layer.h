#ifndef CONV_LAYER_H
#define CONV_LAYER_H

#include <stdint.h>

// Network dimensions (Part B default configuration)
#define H_IN    16          // Input feature map height
#define W_IN    16          // Input feature map width
#define C_IN    8           // Input channels
#define K       3           // Kernel (filter) size: K x K
#define O_CH    8           // Output channels
#define H_OUT   (H_IN - K + 1)   // 14  
#define W_OUT   (W_IN - K + 1)   // 14

// Data types
//   data_t : INT8  for inputs and weights
//   acc_t  : INT32 for accumulation
typedef int8_t  data_t;
typedef int32_t acc_t;

// Baseline: outer h,w,o  inner c,r,s  — no pragmas
void conv_baseline(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y[H_OUT][W_OUT][O_CH]
);

// Output-stationary loop ordering: h, w, o outermost
void conv_output_stationary(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y[H_OUT][W_OUT][O_CH]
);

// Channel-stationary loop ordering: c outermost
void conv_channel_stationary(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y[H_OUT][W_OUT][O_CH]
);

// Optimized: pipeline + unroll + array_partition pragmas
void conv_optimized(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y[H_OUT][W_OUT][O_CH]
);

#endif
