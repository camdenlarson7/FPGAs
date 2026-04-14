#include <stdio.h>
#include "ap_int.h"

// Top function under test
void nn_demo_top(ap_uint<1> *linear_pass, ap_uint<1> *conv_pass);

int main() {
    ap_uint<1> linear_pass = 0;
    ap_uint<1> conv_pass   = 0;

    // Run once
    nn_demo_top(&linear_pass, &conv_pass);

    if ((linear_pass != 1) || (conv_pass != 1)) {
        printf("FAIL: linear_pass=%d conv_pass=%d\n",
               (int)linear_pass, (int)conv_pass);
        return 1;
    }

    // Run a second time to ensure deterministic behavior
    linear_pass = 0;
    conv_pass   = 0;
    nn_demo_top(&linear_pass, &conv_pass);

    if ((linear_pass != 1) || (conv_pass != 1)) {
        printf("FAIL (2nd run): linear_pass=%d conv_pass=%d\n",
               (int)linear_pass, (int)conv_pass);
        return 1;
    }

    printf("PASS: linear_pass=%d conv_pass=%d\n",
           (int)linear_pass, (int)conv_pass);
    return 0;
}
