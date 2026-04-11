#include "LinearLayer.h"


// Baseline 1: Output-stationary (outer loop over j)
void baseline_outer_loop(data_t x[D], data_t w[D][O], out_t y[O]) {
    OUTER: for (int j = 0; j < O; ++j) {
        out_t sum = 0;
        INNER: for (int i = 0; i < D; ++i) {
            sum += (out_t)(x[i] * w[i][j]);
        }
        y[j] = sum;
    }
}



// Baseline 2: Input-stationary (outer loop over i)
void baseline_inner_loop(data_t x[D], data_t w[D][O], out_t y[O]) {
    out_t temp_y[O];

    INIT: for (int k = 0; k < O; ++k) {
        temp_y[k] = 0;
    }

    OUTER: for (int i = 0; i < D; ++i) {
        INNER: for (int j = 0; j < O; ++j) {
            temp_y[j] += (out_t)(x[i] * w[i][j]);
        }
    }

    WRITE: for (int j = 0; j < O; ++j) {
        y[j] = temp_y[j];
    }
}


// Optimized: PIPELINE + UNROLL + ARRAY_PARTITION
// pipeline the outer (i) loop with II=1, fully unroll the inner (j)
// loop to instantiate O=32 parallel MAC units.

void optimized_layer_pl(data_t x[D], data_t w[D][O], out_t y[O]) {

    out_t temp_y[O];
    // Partition w along the j (column) axis: 32 independent banks of D entries
    #pragma HLS ARRAY_PARTITION variable=w    dim=2 complete
    // Partition temp_y fully: 32 individual registers
    #pragma HLS ARRAY_PARTITION variable=temp_y dim=1 complete


    INIT: for (int k = 0; k < O; ++k) {
        #pragma HLS UNROLL
        temp_y[k] = 0;
    }

    OUTER: for (int i = 0; i < D; ++i) {
        #pragma HLS PIPELINE II=1
        INNER: for (int j = 0; j < O; ++j) {
            #pragma HLS UNROLL
            temp_y[j] += (out_t)(x[i] * w[i][j]);
        }
    }

    // Unroll the writeback: all 32 outputs written in one cycle
    WRITE: for (int j = 0; j < O; ++j) {
        #pragma HLS UNROLL
        y[j] = temp_y[j];
    }
}
