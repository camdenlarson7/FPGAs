#include "conv_layer.h"

void conv_baseline(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y[H_OUT][W_OUT][O_CH]
)
{
    // Initialise output to zero
    for (int h = 0; h < H_OUT; h++) {
        for (int w = 0; w < W_OUT; w++) {
            for (int o = 0; o < O_CH; o++) {
                Y[h][w][o] = 0;
            }
        }
    }

    // 2D convolution – 6 nested loops, no pragmas
    for (int h = 0; h < H_OUT; h++) {       
        for (int w = 0; w < W_OUT; w++) {   
            for (int o = 0; o < O_CH; o++) { 
                acc_t sum = 0;
                for (int c = 0; c < C_IN; c++) {   
                    for (int r = 0; r < K; r++) {  
                        for (int s = 0; s < K; s++) { 
                            sum += (acc_t)X[h + r][w + s][c] *
                                   (acc_t)W_k[r][s][c][o];
                        }
                    }
                }
                Y[h][w][o] = sum;
            }
        }
    }
}
