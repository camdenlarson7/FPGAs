# =============================================================================
# Makefile – Lab 3 Part B: HLS 2D Convolution (local C++ build)
#
# Usage (in Lab3/ directory):
#   make          – compile the testbench
#   make run      – compile and run
#   make clean    – remove build artefacts
#
# The HLS pragmas (#pragma HLS ...) are silently ignored by g++, so the
# same source files can be functional-tested here before loading into Vitis HLS.
# =============================================================================

CXX      = g++
CXXFLAGS = -O0 -std=c++11 -Wall -Wextra -Wno-unknown-pragmas -Wno-unused-label -I./src

TARGET = tb_conv

SRCS = src/conv_baseline.cpp \
       src/conv_output_stationary.cpp \
       src/conv_channel_stationary.cpp \
       src/conv_optimized.cpp \
       src/tb_conv.cpp

# Windows: output .exe; Linux/macOS: no extension needed
ifeq ($(OS),Windows_NT)
    BIN = $(TARGET).exe
    RM  = del /Q
else
    BIN = $(TARGET)
    RM  = rm -f
endif

.PHONY: all run clean

all: $(BIN)

$(BIN): $(SRCS)
	$(CXX) $(CXXFLAGS) -o $@ $^

run: $(BIN)
	./$(BIN)

clean:
	$(RM) $(TARGET).exe $(TARGET)
