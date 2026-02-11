# Lab 1: Pipelined vs Unpipelined Arithmetic Algorithm

This lab implements a simple arithmetic algorithm in both pipelined and unpipelined versions using Verilog HDL.

## Algorithm

Both implementations compute the following operation:
```
y = (a × b) + (c × d) + e
```

Where:
- `a, b, c, d, e` are 16-bit signed inputs
- `y` is a 32-bit signed output

## Implementations

### RTL_Unpipelined
A single-stage implementation that computes the entire operation in one clock cycle. The module uses a valid/ready handshake protocol for flow control.

**Latency**: 1 clock cycle  
**Throughput**: 1 operation per cycle

### RTL_Pipelined
A three-stage pipelined implementation that divides the computation across multiple stages:
1. **Stage 1**: Compute products `a×b` and `c×d`
2. **Stage 2**: Sum the products
3. **Stage 3**: Add `e` to produce final result

**Latency**: 3 clock cycles  
**Throughput**: 1 operation per cycle (when pipeline is full)

## Files

- `RTL_unpipelined.v` - Unpipelined module implementation
- `RTL_pipelined.v` - Pipelined module implementation
- `tb_RTL_unpipelined.v` - Testbench for unpipelined module
- `tb_RTL_pipelined.v` - Testbench for pipelined module
- `../constraints.xdc` - Vivado synthesis constraints (needed to determine WNS)

## Testing

Both testbenches generate 200 random test vectors using a seeded random number generator to validate the correctness of each implementation.

### Running the Unpipelined Testbench
```bash
iverilog -o tb_RTL_unpipelined.vvp tb_RTL_unpipelined.v RTL_unpipelined.v
vvp tb_RTL_unpipelined.vvp
```

### Running the Pipelined Testbench
```bash
iverilog -o tb_RTL_pipelined.vvp tb_RTL_pipelined.v RTL_pipelined.v
vvp tb_RTL_pipelined.vvp
```

## Handshake Protocol

Both modules implement a standard valid/ready handshake protocol:
- **Input side**: `in_valid` (from testbench), `in_ready` (from module)
- **Output side**: `out_valid` (from module), `out_ready` (from testbench)

A transaction occurs when both valid and ready signals are asserted on the same clock cycle.

## Results

Both implementations pass all 200 random test vectors, demonstrating functional correctness. The pipelined version achieves higher throughput at the cost of increased latency and resource usage.
