#include "conv_layer.h"

void conv_output_stationary(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y[H_OUT][W_OUT][O_CH]
)
{
    LOOP_H: for (int h = 0; h < H_OUT; h++) {
        LOOP_W: for (int w = 0; w < W_OUT; w++) {
            LOOP_O: for (int o = 0; o < O_CH; o++) {
                acc_t sum = 0;
                LOOP_C: for (int c = 0; c < C_IN; c++) {
                    LOOP_R: for (int r = 0; r < K; r++) {
                        LOOP_S: for (int s = 0; s < K; s++) {
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
