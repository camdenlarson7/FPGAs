#ifndef LINEAR_LAYER_H
#define LINEAR_LAYER_H

#include "ap_int.h"

// Dimensions
static const int D = 64;   // input dimension
static const int O = 32;   // output dimension

// Data types 
// INT8 for inputs and weights
typedef ap_int<8>  data_t;
typedef ap_int<32> out_t;



// Baseline 1: outer loop over j (output-stationary)
void baseline_outer_loop(data_t x[D], data_t w[D][O], out_t y[O]);

// Baseline 2: outer loop over i (input-stationary)
void baseline_inner_loop(data_t x[D], data_t w[D][O], out_t y[O]);

// Optimized: PIPELINE on outer (i) loop + UNROLL on inner (j) loop
// Requires ARRAY_PARTITION on w and temp_y for II=1
void optimized_layer_pl(data_t x[D], data_t w[D][O], out_t y[O]);

#endif // LINEAR_LAYER_H
