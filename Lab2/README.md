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

## Simulation Testbench

**9 directed tests across 3 modes**, all inputs constant (x=1,w=1 or signed/ramp variants).

| Test | Mode | Pattern | Expected |
|------|------|---------|----------|
| 0-A | seq_mac | all-ones, N=64 | 64 |
| 0-B | seq_mac | ramp × 2 | 4160 |
| 0-C | seq_mac | x=−1, w=3 | −192 |
| 1-A | parallel_mac | all-ones, U=8 batch | 8 |
| 1-B | parallel_mac | ramp × 2, first U | 72 |
| 1-C | parallel_mac | alternating bytes | 1024 |
| 2-A | early_exit_mac | x=16,w=16, T=32 | 512 |
| 2-B | early_exit_mac | x=1,w=1, T=32 | 32 |
| 2-C | early_exit_mac | x=−5, w=5, T=32 | −50 |

**Randomisation** — three independent LFSRs randomise `stall_inject` (~25%), `x/w_valid` de-assertion (~19%), and `y_ready` back-pressure (~31%) every clock cycle, covering FSM stall/resume paths without extra test cases.

**Self-checking** — each test has a SW golden model that computes the expected result before comparing to RTL output. A tagged PASS/FAIL line is printed with both values. A 100k-cycle watchdog catches hangs.

**Mode 2** — early-exit timing is FSM-state-dependent. If the threshold is hit on the *first* accepted sample (FSM in WAIT_IN), one extra sample is consumed before the FSM can exit COMPUTE, giving 2 samples total. If hit on any later sample (FSM already in COMPUTE), exit is immediate. The golden model encodes this distinction explicitly.

---

## Board Implementation (dpa_led_test.v)

Program via JTAG, observe LEDs. BTN0 resets and reruns.

| LED | Mode | N | T | Expected | Pass means |
|-----|------|---|---|----------|-----------|
| LD0 | seq_mac | 64 | — | 64 | Sequential accumulation correct |
| LD1 | parallel_mac | 8 (=U) | — | 8 | One full batch correct |
| LD2 | early_exit_mac | 64 | 0 (off) | 64 | Full run, no early exit |
| LD3 | all three | — | — | — | System-level AND |

**Three DUT instances** — N differs per mode (8 for Mode 1, 64 for Modes 0/2) and parameters are elaboration-time constants, so three instances of `dot_product_accelerator` run in parallel with a mux on `done`/`y_data` selecting the active one.

**Streaming** — `x_valid=w_valid=1` is held continuously for all modes. Each datapath gates itself internally (`fill_count` in parallel_mac, `k` counter in seq/early_exit), so no slot-by-slot toggling is needed in the wrapper.

**Reset** — BTN0 is double-flop synchronised into active-high `rst`, matching the DUT's reset polarity. Press to hold in reset; release to run.

**Sequencer** — 7-state FSM: `IDLE -> START -> RUNNING -> ACK -> CHECK -> NEXT -> DONE`. A 16-bit watchdog in `RUNNING` forces a FAIL if `done` never arrives (~524 µs at 125 MHz).


## Vivado Notes

For synthesis/performance comparisons:
- Synthesize datapaths individually (`seq_mac`, `parallel_mac`, `early_exit_mac`) for raw block metrics.
- Synthesize `dot_product_accelerator` for integrated system timing/area.
- Use the same clock constraint across runs for fair WNS/Fmax comparison.


---
