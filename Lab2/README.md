# Lab 2: Dot Product Accelerator (Multi-Mode)

This lab implements a configurable dot-product accelerator in Verilog with a shared controller (`FSM`) and three datapath modes.

## Objective

Compute a dot product over signed 8-bit input pairs (`x`, `w`) and produce a 32-bit accumulated output (`y`) using different performance/behavior trade-offs.

## Modes

- **Mode 0 (`seq_mac`)**: Sequential MAC over `N` samples.
- **Mode 1 (`parallel_mac`)**: Batched/parallel-style MAC datapath (timing-optimized with pipelined internal stages).
- **Mode 2 (`early_exit_mac`)**: Sequential MAC with threshold-based early exit.

All mode selection and state transitions are handled by `FSM` + `dot_product_accelerator`.

## Files

- `src/dot_product_accelerator.v` - Top-level integration of controller + mode datapaths
- `src/FSM.v` - Shared controller for start/config/wait/compute/hold flow
- `src/seq_mac.v` - Mode 0 datapath
- `src/parallel_mac.v` - Mode 1 datapath
- `src/early_exit_mac.v` - Mode 2 datapath (controller-driven, no internal FSM)
- `src/tb_dot_product.v` - Integrated testbench for Mode 0/1/2

## Mode 2 Early-Exit Threshold

`dot_product_accelerator` exposes a compile-time parameter:

- `MODE2_T` (default `0`)

Behavior:
- `MODE2_T = 0`: early exit disabled (full `N` iterations)
- `MODE2_T > 0`: exit when accumulated magnitude reaches/exceeds threshold

## Build and Run (Icarus Verilog)

From the repository root:

```bash
Push-Location "Lab2/src"
iverilog -o tb_dot_product.vvp tb_dot_product.v dot_product_accelerator.v FSM.v parallel_mac.v seq_mac.v early_exit_mac.v
vvp tb_dot_product.vvp
Pop-Location
```

Expected console output includes pass-style checks for:
- Mode 1 expected value
- Mode 0 expected value
- Mode 2 expected value

## Vivado Notes

For synthesis/performance comparisons:
- Synthesize datapaths individually (`seq_mac`, `parallel_mac`, `early_exit_mac`) for raw block metrics.
- Synthesize `dot_product_accelerator` for integrated system timing/area.
- Use the same clock constraint across runs for fair WNS/Fmax comparison.
