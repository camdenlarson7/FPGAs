// =============================================================================
// tb_conv.cpp
// Testbench for Part B: 2D Convolution Implementations
//
// Verifies all four implementations against a software golden model:
//   - conv_baseline
//   - conv_output_stationary
//   - conv_channel_stationary
//   - conv_optimized
//
// Runs NUM_TESTS random test cases and reports:
//   - Maximum absolute error (should always be 0 for integer arithmetic)
//   - Mean absolute error
//   - Pass / Fail per implementation
// =============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <time.h>

#include "conv_layer.h"

// Number of independent random test vectors to validate against
#define NUM_TESTS 25

// -----------------------------------------------------------------------
// Golden (software reference) convolution
// Bit-identical to the hardware implementations; used as ground truth.
// -----------------------------------------------------------------------
static void golden_conv(
    data_t X[H_IN][W_IN][C_IN],
    data_t W_k[K][K][C_IN][O_CH],
    acc_t  Y_ref[H_OUT][W_OUT][O_CH])
{
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
                Y_ref[h][w][o] = sum;
            }
        }
    }
}

// -----------------------------------------------------------------------
// Compare DUT output against golden reference.
// Returns 1 if all elements match exactly, 0 otherwise.
// Updates running max_err and sum_err.
// -----------------------------------------------------------------------
static int compare_outputs(
    acc_t Y_dut[H_OUT][W_OUT][O_CH],
    acc_t Y_ref[H_OUT][W_OUT][O_CH],
    long long *max_err,
    double    *sum_err,
    long long *total_elements)
{
    int pass = 1;
    for (int h = 0; h < H_OUT; h++) {
        for (int w = 0; w < W_OUT; w++) {
            for (int o = 0; o < O_CH; o++) {
                long long diff = (long long)Y_dut[h][w][o] -
                                 (long long)Y_ref[h][w][o];
                if (diff < 0) diff = -diff;
                if (diff > *max_err) *max_err = diff;
                *sum_err += (double)diff;
                (*total_elements)++;
                if (diff != 0) pass = 0;
            }
        }
    }
    return pass;
}

// -----------------------------------------------------------------------
// Fill array with random INT8 values in [-64, 63] (avoids extreme products)
// -----------------------------------------------------------------------
static void rand_fill_X(data_t X[H_IN][W_IN][C_IN]) {
    for (int h = 0; h < H_IN; h++)
        for (int w = 0; w < W_IN; w++)
            for (int c = 0; c < C_IN; c++)
                X[h][w][c] = (data_t)((rand() % 128) - 64);
}

static void rand_fill_W(data_t W_k[K][K][C_IN][O_CH]) {
    for (int r = 0; r < K; r++)
        for (int s = 0; s < K; s++)
            for (int c = 0; c < C_IN; c++)
                for (int o = 0; o < O_CH; o++)
                    W_k[r][s][c][o] = (data_t)((rand() % 128) - 64);
}

// -----------------------------------------------------------------------
// Run a suite of tests for one implementation.
// Returns total pass count.
// -----------------------------------------------------------------------
typedef void (*conv_fn_t)(data_t[H_IN][W_IN][C_IN],
                          data_t[K][K][C_IN][O_CH],
                          acc_t[H_OUT][W_OUT][O_CH]);

static int run_suite(const char *name, conv_fn_t fn, unsigned int base_seed)
{
    long long max_err       = 0;
    double    sum_err       = 0.0;
    long long total_elem    = 0;
    int       pass_count    = 0;

    static data_t X[H_IN][W_IN][C_IN];
    static data_t W_k[K][K][C_IN][O_CH];
    static acc_t  Y_dut[H_OUT][W_OUT][O_CH];
    static acc_t  Y_ref[H_OUT][W_OUT][O_CH];

    printf("\n--- %s (%d tests) ---\n", name, NUM_TESTS);

    for (int t = 0; t < NUM_TESTS; t++) {
        srand(base_seed + (unsigned int)t);
        rand_fill_X(X);
        rand_fill_W(W_k);

        // Compute golden reference
        golden_conv(X, W_k, Y_ref);

        // Run the DUT
        fn(X, W_k, Y_dut);

        int pass = compare_outputs(Y_dut, Y_ref, &max_err, &sum_err, &total_elem);
        if (pass) {
            pass_count++;
        } else {
            printf("  Test %2d: FAIL\n", t);
        }
    }

    double mae = (total_elem > 0) ? (sum_err / (double)total_elem) : 0.0;
    printf("  Passed        : %d / %d\n", pass_count, NUM_TESTS);
    printf("  Max abs error : %lld\n",   max_err);
    printf("  Mean abs error: %.6f\n",   mae);

    return pass_count;
}

// -----------------------------------------------------------------------
// main
// -----------------------------------------------------------------------
int main(void)
{
    printf("=============================================================\n");
    printf("Lab 3 Part B - 2D Convolution Testbench\n");
    printf("Config: H=%d W=%d C=%d K=%d O=%d  -> H_out=%d W_out=%d\n",
           H_IN, W_IN, C_IN, K, O_CH, H_OUT, W_OUT);
    printf("Data types: INT8 inputs/weights, INT32 accumulation\n");
    printf("Number of test vectors: %d\n", NUM_TESTS);
    printf("=============================================================\n");

    // Use a fixed base seed for reproducibility; each test increments it.
    unsigned int BASE_SEED = 42;

    int p1 = run_suite("conv_baseline",           conv_baseline,          BASE_SEED);
    int p2 = run_suite("conv_output_stationary",  conv_output_stationary, BASE_SEED);
    int p3 = run_suite("conv_channel_stationary", conv_channel_stationary,BASE_SEED);
    int p4 = run_suite("conv_optimized",          conv_optimized,         BASE_SEED);

    printf("\n=============================================================\n");
    printf("Summary\n");
    printf("  conv_baseline           : %d/%d\n", p1, NUM_TESTS);
    printf("  conv_output_stationary  : %d/%d\n", p2, NUM_TESTS);
    printf("  conv_channel_stationary : %d/%d\n", p3, NUM_TESTS);
    printf("  conv_optimized          : %d/%d\n", p4, NUM_TESTS);

    int all_pass = (p1 == NUM_TESTS) && (p2 == NUM_TESTS) &&
                   (p3 == NUM_TESTS) && (p4 == NUM_TESTS);
    printf("\nOverall result: %s\n", all_pass ? "PASS" : "FAIL");
    printf("=============================================================\n");

    return all_pass ? 0 : 1;
}
