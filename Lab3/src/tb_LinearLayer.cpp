#include <iostream>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include "LinearLayer.h"


// Golden reference model 
void golden_linear(int8_t x[D], int8_t w[D][O], int32_t y_ref[O]) {
    for (int j = 0; j < O; ++j) {
        int32_t sum = 0;
        for (int i = 0; i < D; ++i) {
            sum += (int32_t)x[i] * (int32_t)w[i][j];
        }
        y_ref[j] = sum;
    }
}


// Comparison helper 
int check_outputs(const char* test_name, out_t y_dut[O], int32_t y_ref[O]) {
    int errors = 0;
    for (int j = 0; j < O; ++j) {
        int32_t got = (int32_t)y_dut[j];
        if (got != y_ref[j]) {
            std::cerr << "  [FAIL] " << test_name
                      << "  y[" << j << "] = " << got
                      << "  expected " << y_ref[j] << "\n";
            ++errors;
        }
    }
    if (errors == 0) {
        std::cout << "  [PASS] " << test_name << "\n";
    }
    return errors;
}


// Adapters: convert plain int8/int32 arrays to/from ap_int for DUT calls
void pack_inputs(int8_t x_raw[D], int8_t w_raw[D][O],
                 data_t x_ap[D], data_t w_ap[D][O]) {
    for (int i = 0; i < D; ++i)   x_ap[i] = x_raw[i];
    for (int i = 0; i < D; ++i)
        for (int j = 0; j < O; ++j)
            w_ap[i][j] = w_raw[i][j];
}


// Test cases


// Test 1: all-zeros input 
int test_zeros() {
    int8_t  x_raw[D]    = {};
    int8_t  w_raw[D][O] = {};
    int32_t y_ref[O]    = {};

    data_t x_ap[D]; data_t w_ap[D][O]; out_t y_outer[O], y_inner[O], y_opt[O];
    pack_inputs(x_raw, w_raw, x_ap, w_ap);

    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );

    int e = 0;
    e += check_outputs("zeros / outer ",  y_outer, y_ref);
    e += check_outputs("zeros / inner ",  y_inner, y_ref);
    e += check_outputs("zeros / optim ",  y_opt,   y_ref);
    return e;
}

// Test 2: all-ones input
int test_all_ones() {
    int8_t  x_raw[D];
    int8_t  w_raw[D][O];
    int32_t y_ref[O];

    for (int i = 0; i < D; ++i)        x_raw[i] = 1;
    for (int i = 0; i < D; ++i)
        for (int j = 0; j < O; ++j)    w_raw[i][j] = 1;

    golden_linear(x_raw, w_raw, y_ref);

    data_t x_ap[D]; data_t w_ap[D][O]; out_t y_outer[O], y_inner[O], y_opt[O];
    pack_inputs(x_raw, w_raw, x_ap, w_ap);

    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );

    int e = 0;
    e += check_outputs("all-ones / outer", y_outer, y_ref);
    e += check_outputs("all-ones / inner", y_inner, y_ref);
    e += check_outputs("all-ones / optim", y_opt,   y_ref);
    return e;
}

// Test 3: identity-like, x[i]=1 only for i==0, w[0][j]=j+1, y[j] = j+1
int test_single_hot() {
    int8_t  x_raw[D]    = {};
    int8_t  w_raw[D][O] = {};
    int32_t y_ref[O]    = {};

    x_raw[0] = 1;
    for (int j = 0; j < O; ++j)   w_raw[0][j] = (int8_t)(j + 1);

    golden_linear(x_raw, w_raw, y_ref);

    data_t x_ap[D]; data_t w_ap[D][O]; out_t y_outer[O], y_inner[O], y_opt[O];
    pack_inputs(x_raw, w_raw, x_ap, w_ap);

    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );

    int e = 0;
    e += check_outputs("single-hot / outer", y_outer, y_ref);
    e += check_outputs("single-hot / inner", y_inner, y_ref);
    e += check_outputs("single-hot / optim", y_opt,   y_ref);
    return e;
}

// Test 4: negative values, x[i] = -1, w[i][j] = 1, y[j] = -D
int test_negative() {
    int8_t  x_raw[D];
    int8_t  w_raw[D][O];
    int32_t y_ref[O];

    for (int i = 0; i < D; ++i)        x_raw[i] = -1;
    for (int i = 0; i < D; ++i)
        for (int j = 0; j < O; ++j)    w_raw[i][j] = 1;

    golden_linear(x_raw, w_raw, y_ref);

    data_t x_ap[D]; data_t w_ap[D][O]; out_t y_outer[O], y_inner[O], y_opt[O];
    pack_inputs(x_raw, w_raw, x_ap, w_ap);

    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );

    int e = 0;
    e += check_outputs("negative / outer", y_outer, y_ref);
    e += check_outputs("negative / inner", y_inner, y_ref);
    e += check_outputs("negative / optim", y_opt,   y_ref);
    return e;
}

// Test 5: INT8 extremes, max positive and max negative values
int test_extremes() {
    int8_t  x_raw[D]; int8_t  w_raw[D][O]; int32_t y_ref[O];
    data_t  x_ap[D];  data_t  w_ap[D][O];
    out_t   y_outer[O], y_inner[O], y_opt[O];
    int e = 0;

    // max positive
    for (int i = 0; i < D; ++i)        x_raw[i] = 127;
    for (int i = 0; i < D; ++i)
        for (int j = 0; j < O; ++j)    w_raw[i][j] = 127;
    golden_linear(x_raw, w_raw, y_ref);
    pack_inputs(x_raw, w_raw, x_ap, w_ap);
    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );
    e += check_outputs("extremes +127 / outer", y_outer, y_ref);
    e += check_outputs("extremes +127 / inner", y_inner, y_ref);
    e += check_outputs("extremes +127 / optim", y_opt,   y_ref);

    // max negative * max negative (should be large positive, still fits INT32)
    for (int i = 0; i < D; ++i)        x_raw[i] = -128;
    for (int i = 0; i < D; ++i)
        for (int j = 0; j < O; ++j)    w_raw[i][j] = -128;
    golden_linear(x_raw, w_raw, y_ref);
    pack_inputs(x_raw, w_raw, x_ap, w_ap);
    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );
    e += check_outputs("extremes -128 / outer", y_outer, y_ref);
    e += check_outputs("extremes -128 / inner", y_inner, y_ref);
    e += check_outputs("extremes -128 / optim", y_opt,   y_ref);
    return e;
}

// Test 6: pseudo-random data, catches systematic address or accumulation bugs
//   Uses a simple LCG so results are deterministic.
int test_random() {
    int8_t  x_raw[D]; int8_t  w_raw[D][O]; int32_t y_ref[O];
    data_t  x_ap[D];  data_t  w_ap[D][O];
    out_t   y_outer[O], y_inner[O], y_opt[O];

    // LCG seed
    uint32_t state = 0xDEADBEEF;
    for (int i = 0; i < D; ++i) {
        state = state * 1664525u + 1013904223u;
        x_raw[i] = (int8_t)(state >> 24);
    }
    for (int i = 0; i < D; ++i)
        for (int j = 0; j < O; ++j) {
            state = state * 1664525u + 1013904223u;
            w_raw[i][j] = (int8_t)(state >> 24);
        }

    golden_linear(x_raw, w_raw, y_ref);
    pack_inputs(x_raw, w_raw, x_ap, w_ap);

    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );

    int e = 0;
    e += check_outputs("random / outer", y_outer, y_ref);
    e += check_outputs("random / inner", y_inner, y_ref);
    e += check_outputs("random / optim", y_opt,   y_ref);
    return e;
}

// Test 7: diagonal weight matrix, y[j] = x[j] * w[j][j], zeros elsewhere
//   Tests that column addressing is correct: outer loop reads w[i][j=fixed], not w[j][i].
int test_diagonal() {
    int8_t  x_raw[D]    = {};
    int8_t  w_raw[D][O] = {};
    int32_t y_ref[O]    = {};
    data_t  x_ap[D]; data_t w_ap[D][O];
    out_t   y_outer[O], y_inner[O], y_opt[O];

    // Fill diagonal: w[j][j] = j+1 for j in [0, O)
    // x[i] = i+1 for i in [0, D) to give non-trivial values
    for (int i = 0; i < D; ++i)   x_raw[i] = (int8_t)(i + 1);
    for (int j = 0; j < O; ++j)   w_raw[j][j] = (int8_t)(j + 1);

    golden_linear(x_raw, w_raw, y_ref);
    pack_inputs(x_raw, w_raw, x_ap, w_ap);

    baseline_outer_loop(x_ap, w_ap, y_outer);
    baseline_inner_loop(x_ap, w_ap, y_inner);
    optimized_layer_pl (x_ap, w_ap, y_opt  );

    int e = 0;
    e += check_outputs("diagonal / outer", y_outer, y_ref);
    e += check_outputs("diagonal / inner", y_inner, y_ref);
    e += check_outputs("diagonal / optim", y_opt,   y_ref);
    return e;
}


// Main : run all tests

int main() {
    int total_errors = 0;

    std::cout << "\n=== Test 1: all-zeros ===\n";
    total_errors += test_zeros();

    std::cout << "\n=== Test 2: all-ones ===\n";
    total_errors += test_all_ones();

    std::cout << "\n=== Test 3: single-hot input ===\n";
    total_errors += test_single_hot();

    std::cout << "\n=== Test 4: negative values ===\n";
    total_errors += test_negative();

    std::cout << "\n=== Test 5: INT8 extremes ===\n";
    total_errors += test_extremes();

    std::cout << "\n=== Test 6: pseudo-random data ===\n";
    total_errors += test_random();

    std::cout << "\n=== Test 7: diagonal weight matrix ===\n";
    total_errors += test_diagonal();

    std::cout << "\n==============================\n";
    if (total_errors == 0) {
        std::cout << "ALL TESTS PASSED\n";
    } else {
        std::cout << "FAILED: " << total_errors << " mismatches\n";
    }
    std::cout << "==============================\n\n";

    // Return non-zero on failure so HLS co-sim marks the run as failed
    return (total_errors > 0) ? 1 : 0;
}
