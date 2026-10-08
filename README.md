# AXI DMA Controller

A **Direct Memory Access (DMA) controller** in SystemVerilog with an AXI4-Lite configuration slave and an AXI4-Full burst master. It moves data between peripherals (UART, LDPC accelerator) and memory without CPU intervention.

## Architecture (`DMA.srcs/sources_1/new/DMA_Main.v`)

| Module | Description |
|---|---|
| `DMA_top` | Top level: AXI4-Lite slave port, AXI4-Full master port, interrupt inputs, completion IRQ |
| `DMA_arbiter` | Arbitrates between AXI-Lite register writes and peripheral interrupt requests (FIFO-buffered) |
| `DMA_reg_file` | Descriptor / control FSM (`IDLE → WAIT_ADDR → SEND_CMD → WAIT_IRQ → SETUP_PART2 → UPDATE_PTR`) with ring-buffer pointer management |
| `DMA_cpu` | AXI4-Full burst engine generating read/write transactions (`AxLEN`, `WLAST`, response handling) |
| `UART_stream` | FIFO-based streaming interface for UART RX/TX data |

- Interrupt-driven transfers triggered by `UART_irq` and `LDPC_irq`
- Memory-mapped targets: UART RX/TX FIFOs, LDPC in/out buffers, IMEM, DMEM
- `cpu_irq_pulse` signals transfer completion to the processor

## Verification

`DMA.srcs/sim_1/new/DMA_tb.v` – testbench with AXI slave memory models; waveform configuration in `tb_DMA_behav.wcfg`.

**Tools:** SystemVerilog, AXI4 / AXI4-Lite, AMD Vivado
