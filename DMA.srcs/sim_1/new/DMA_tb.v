`timescale 1ns/1ps

// ------------------------------------------------------------
// Testbench for DMA System (Final Fix: Robust RAM & Sync)
// ------------------------------------------------------------
module tb_DMA;

  localparam int ADDR_W = 32;
  localparam int DATA_W = 32;
  localparam int BYTES  = DATA_W/8;

  // ------------------------------------------------------------
  // Clock & Reset Generation
  // ------------------------------------------------------------
  logic clk; 
  logic rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz
  end

  initial begin
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  // ------------------------------------------------------------
  // Signals
  // ------------------------------------------------------------
  logic LDPC_irq, UART_irq;

  // AXI-Lite (Master -> DUT Slave)
  logic [5:0]  S_AXI_AWADDR;
  logic        S_AXI_AWVALID;
  logic        S_AXI_AWREADY;
  logic [31:0] S_AXI_WDATA;
  logic [3:0]  S_AXI_WSTRB;
  logic        S_AXI_WVALID;
  logic        S_AXI_WREADY;
  logic [1:0]  S_AXI_BRESP;
  logic        S_AXI_BVALID;
  logic        S_AXI_BREADY;

  // AXI4-Full (DUT Master -> RAM Slave)
  logic [ADDR_W-1:0] M_AXI_AWADDR;
  logic [7:0]        M_AXI_AWLEN;
  logic [2:0]        M_AXI_AWSIZE;
  logic [1:0]        M_AXI_AWBURST;
  logic              M_AXI_AWVALID;
  logic              M_AXI_AWREADY;
  logic [DATA_W-1:0] M_AXI_WDATA;
  logic [(DATA_W/8)-1:0] M_AXI_WSTRB;
  logic              M_AXI_WLAST;
  logic              M_AXI_WVALID;
  logic              M_AXI_WREADY;
  logic [1:0]        M_AXI_BRESP;
  logic              M_AXI_BVALID;
  logic              M_AXI_BREADY;
  logic [ADDR_W-1:0] M_AXI_ARADDR;
  logic [7:0]        M_AXI_ARLEN;
  logic [2:0]        M_AXI_ARSIZE;
  logic [1:0]        M_AXI_ARBURST;
  logic              M_AXI_ARVALID;
  logic              M_AXI_ARREADY;
  logic [DATA_W-1:0] M_AXI_RDATA;
  logic [1:0]        M_AXI_RRESP;
  logic              M_AXI_RLAST;
  logic              M_AXI_RVALID;
  logic              M_AXI_RREADY;

  logic              cpu_irq_pulse;

  // ------------------------------------------------------------
  // DUT Instantiation
  // ------------------------------------------------------------
  DMA_top #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk(clk), .rst_n(rst_n),
    .LDPC_irq(LDPC_irq), .UART_irq(UART_irq),
    // AXI-Lite
    .S_AXI_AWADDR(S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID), .S_AXI_AWREADY(S_AXI_AWREADY),
    .S_AXI_WDATA(S_AXI_WDATA),   .S_AXI_WSTRB(S_AXI_WSTRB),     .S_AXI_WVALID(S_AXI_WVALID),
    .S_AXI_WREADY(S_AXI_WREADY), .S_AXI_BRESP(S_AXI_BRESP),     .S_AXI_BVALID(S_AXI_BVALID),
    .S_AXI_BREADY(S_AXI_BREADY),
    // AXI4-Full
    .M_AXI_AWADDR(M_AXI_AWADDR), .M_AXI_AWLEN(M_AXI_AWLEN),     .M_AXI_AWSIZE(M_AXI_AWSIZE),
    .M_AXI_AWBURST(M_AXI_AWBURST), .M_AXI_AWVALID(M_AXI_AWVALID), .M_AXI_AWREADY(M_AXI_AWREADY),
    .M_AXI_WDATA(M_AXI_WDATA),   .M_AXI_WSTRB(M_AXI_WSTRB),     .M_AXI_WLAST(M_AXI_WLAST),
    .M_AXI_WVALID(M_AXI_WVALID), .M_AXI_WREADY(M_AXI_WREADY),   .M_AXI_BRESP(M_AXI_BRESP),
    .M_AXI_BVALID(M_AXI_BVALID), .M_AXI_BREADY(M_AXI_BREADY),
    .M_AXI_ARADDR(M_AXI_ARADDR), .M_AXI_ARLEN(M_AXI_ARLEN),     .M_AXI_ARSIZE(M_AXI_ARSIZE),
    .M_AXI_ARBURST(M_AXI_ARBURST), .M_AXI_ARVALID(M_AXI_ARVALID), .M_AXI_ARREADY(M_AXI_ARREADY),
    .M_AXI_RDATA(M_AXI_RDATA),   .M_AXI_RRESP(M_AXI_RRESP),     .M_AXI_RLAST(M_AXI_RLAST),
    .M_AXI_RVALID(M_AXI_RVALID), .M_AXI_RREADY(M_AXI_RREADY),
    .cpu_irq_pulse(cpu_irq_pulse)
  );

  // ------------------------------------------------------------
  // RAM Model (DÜZELTİLDİ: READY Sinyalleri "Busy" durumunu yönetiyor)
  // ------------------------------------------------------------
  module axi_ram_model_fixed #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
  )(
    input  logic                   clk,
    input  logic                   rst_n,
    // Write Addr
    input  logic [ADDR_W-1:0]      S_AWADDR,
    input  logic [7:0]             S_AWLEN,
    input  logic                   S_AWVALID,
    output logic                   S_AWREADY,
    // Write Data
    input  logic [DATA_W-1:0]      S_WDATA,
    input  logic                   S_WLAST,
    input  logic                   S_WVALID,
    output logic                   S_WREADY,
    // Write Resp
    output logic [1:0]             S_BRESP,
    output logic                   S_BVALID,
    input  logic                   S_BREADY,
    // Read Addr
    input  logic [ADDR_W-1:0]      S_ARADDR,
    input  logic [7:0]             S_ARLEN,
    input  logic                   S_ARVALID,
    output logic                   S_ARREADY,
    // Read Data
    output logic [DATA_W-1:0]      S_RDATA,
    output logic                   S_RLAST,
    output logic                   S_RVALID,
    input  logic                   S_RREADY
  );

    localparam int BYTES = DATA_W/8;
    localparam int BANK_WORDS = 64*1024; 
    localparam int BANKS      = 6;
    localparam int MEM_WORDS  = BANK_WORDS*BANKS;
    logic [DATA_W-1:0] mem [0:MEM_WORDS-1];

    function automatic int unsigned bank_base(input logic [31:0] a);
        if (a[31:16] == 16'h4000) return 0*BANK_WORDS; 
        if (a[31:16] == 16'h4200) return 1*BANK_WORDS;
        if (a[31:16] == 16'h4208) return 2*BANK_WORDS;
        if (a[31:16] == 16'h2000) return 3*BANK_WORDS;
        if (a[31:16] == 16'h0000) return 4*BANK_WORDS;
        if (a[31:16] == 16'h3000) return 5*BANK_WORDS;
        return 0;
    endfunction

    function automatic int unsigned windex(input logic [31:0] a);
        return bank_base(a) + {16'd0, a[15:2]}; 
    endfunction

    // State signals
    logic [ADDR_W-1:0] raddr, waddr;
    logic [7:0]        rleft, wleft;
    logic              ractive, wactive;
    
    // KİLİT NOKTA: Meşgulse READY = 0. Bu, CPU'yu bekletir ve senkronizasyonu sağlar.
    assign S_AWREADY = !wactive;
    assign S_ARREADY = !ractive;
    // WREADY sadece adres alındıysa ve yazma aktifse 1 olmalı
    assign S_WREADY  = wactive; 

    // READ FSM
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        ractive <= 1'b0;
        S_RVALID <= 1'b0;
        S_RLAST  <= 1'b0;
      end else begin
        if (!ractive && S_ARVALID && S_ARREADY) begin
          ractive <= 1'b1;
          raddr   <= S_ARADDR;
          rleft   <= S_ARLEN;
          S_RVALID <= 1'b1;
          S_RLAST  <= (S_ARLEN == 8'd0);
          S_RDATA  <= mem[windex(S_ARADDR)];
        end else if (ractive && S_RVALID && S_RREADY) begin
          if (S_RLAST) begin
            ractive <= 1'b0;
            S_RVALID <= 1'b0;
          end else begin
            raddr    <= raddr + BYTES;
            rleft    <= rleft - 8'd1;
            S_RDATA  <= mem[windex(raddr + BYTES)];
            S_RLAST  <= (rleft == 8'd1);
          end
        end
      end
    end

    // WRITE FSM
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        wactive <= 1'b0;
        S_BVALID <= 1'b0;
        S_BRESP  <= 2'b00;
      end else begin
        // Adres Yakalama
        if (!wactive && S_AWVALID && S_AWREADY) begin
          wactive     <= 1'b1;
          waddr       <= S_AWADDR;
          wleft       <= S_AWLEN;
        end
        
        // Veri Yazma
        if (wactive && S_WVALID && S_WREADY) begin
          mem[windex(waddr)] <= S_WDATA;
          if (S_WLAST) begin
            wactive  <= 1'b0;
            S_BVALID <= 1'b1;
          end else begin
            waddr <= waddr + BYTES;
            wleft <= wleft - 8'd1;
          end
        end
        
        // Response Handshake
        if (S_BVALID && S_BREADY) begin
          S_BVALID <= 1'b0;
        end
      end
    end
    
    // Testbench için bellek okuma fonksiyonu
    function logic [31:0] read_mem(input logic [31:0] addr);
        return mem[windex(addr)];
    endfunction
    
  endmodule

  // DUT Modelini yeni fixed RAM ile bağlıyoruz
  axi_ram_model_fixed #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) ram (
    .clk(clk), .rst_n(rst_n),
    .S_AWADDR (M_AXI_AWADDR), .S_AWLEN  (M_AXI_AWLEN),  .S_AWVALID(M_AXI_AWVALID), .S_AWREADY(M_AXI_AWREADY),
    .S_WDATA  (M_AXI_WDATA),  .S_WLAST  (M_AXI_WLAST),  .S_WVALID (M_AXI_WVALID),  .S_WREADY (M_AXI_WREADY),
    .S_BRESP  (M_AXI_BRESP),  .S_BVALID (M_AXI_BVALID), .S_BREADY (M_AXI_BREADY),
    .S_ARADDR (M_AXI_ARADDR), .S_ARLEN  (M_AXI_ARLEN),  .S_ARVALID(M_AXI_ARVALID), .S_ARREADY(M_AXI_ARREADY),
    .S_RDATA  (M_AXI_RDATA),  .S_RLAST  (M_AXI_RLAST),  .S_RVALID (M_AXI_RVALID),  .S_RREADY (M_AXI_RREADY)
  );

  // ------------------------
  // Address Constants
  // ------------------------
  localparam [31:0] IMEM_ADDR = 32'h0000_1000;

  // ------------------------
  // Helper Logic
  // ------------------------
  logic [31:0] last_araddr, last_awaddr;
  logic [7:0]  last_len;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      last_araddr <= '0; last_awaddr <= '0; last_len <= '0;
    end else if (M_AXI_ARVALID && M_AXI_ARREADY && M_AXI_AWVALID && M_AXI_AWREADY) begin
      last_araddr <= M_AXI_ARADDR;
      last_awaddr <= M_AXI_AWADDR;
      last_len    <= (M_AXI_ARLEN + 8'd1);
    end
  end

  function automatic [7:0] mk_op(input bit mode, input [2:0] dst, input [3:0] src);
    mk_op = {mode, dst, src};
  endfunction

  // -------------------------------------------------------
  // TASKS
  // -------------------------------------------------------
  
  task automatic axi_lite_push_op(input [7:0] burst, input [7:0] op);
    begin
      S_AXI_AWADDR  <= 6'h00;
      S_AXI_WDATA   <= {burst, 16'd0, op}; 
      S_AXI_WSTRB   <= 4'hF;
      S_AXI_AWVALID <= 1'b1;
      S_AXI_WVALID  <= 1'b1;
      S_AXI_BREADY  <= 1'b1;
      @(posedge clk);
      wait (S_AXI_AWREADY && S_AXI_WREADY);
      @(posedge clk);
      S_AXI_AWVALID <= 1'b0;
      S_AXI_WVALID  <= 1'b0;
      wait (S_AXI_BVALID);
      @(posedge clk);
      S_AXI_BREADY  <= 1'b0;
    end
  endtask

  // GÜVENLİK GÜNCELLEMESİ: Config işlemlerinin peş peşe binmesini önlemek için
  // BVALID'den sonra 1 cycle fazladan boşluk bırakıyoruz.
  task automatic axi_lite_write_raw(input [31:0] data);
    begin
      S_AXI_AWADDR  <= 6'h00;
      S_AXI_WDATA   <= data;
      S_AXI_WSTRB   <= 4'hF;
      S_AXI_AWVALID <= 1'b1;
      S_AXI_WVALID  <= 1'b1;
      S_AXI_BREADY  <= 1'b1;
      @(posedge clk);
      wait (S_AXI_AWREADY && S_AXI_WREADY);
      @(posedge clk);
      S_AXI_AWVALID <= 1'b0;
      S_AXI_WVALID  <= 1'b0;
      wait (S_AXI_BVALID);
      @(posedge clk);
      S_AXI_BREADY  <= 1'b0;
      @(posedge clk); // Safety delay for FSM transition
    end
  endtask

  task automatic seed_uart_fifo(input [31:0] seed_base, input [7:0] beats);
    begin
      // DÜZELTME: IMEM Source kodu DMA_reg_file'da 6 olarak tanımlı (koduna göre).
      axi_lite_push_op(beats, mk_op(1'b0, 3'b000, 4'b0110)); 
      wait (cpu_irq_pulse); @(posedge clk);
      $display("[%0t] UART FIFO seeded with %0d beats.", $time, beats);
    end
  endtask
  
  // DEBUG İÇİN BELLEK DÖKÜMÜ
  task automatic dump_memory(input string name, input [31:0] start_addr, input int count);
    int i;
    logic [31:0] val;
    $display("--- DUMP MEMORY: %s (Base: 0x%08h) ---", name, start_addr);
    for (i=0; i<count; i++) begin
        val = ram.read_mem(start_addr + i*4);
        if (i % 4 == 0) $write("\n0x%04h: ", i*4);
        $write("%08h ", val);
    end
    $display("\n-------------------------------------------");
  endtask

  function automatic string step_name(input [31:0] srcA, input [31:0] dstA);
    if ((srcA[31:16]==16'h4000) && (dstA[31:16]==16'h2000)) return "UART -> RAM";
    if ((srcA[31:16]==16'h2000) && (dstA[31:16]==16'h4200)) return "RAM -> LDPC_IN";
    if ((srcA[31:16]==16'h4208) && (dstA[31:16]==16'h3000)) return "LDPC_OUT -> RAM(buf)";
    return $sformatf("0x%04h -> 0x%04h", srcA[31:16], dstA[31:16]);
  endfunction

  int irq_count = 0;
  always_ff @(posedge clk) begin
    if (cpu_irq_pulse) begin
      irq_count++;
      $display("[%0t] CPU IRQ PULSE (done)  #%0d  | %s | src=0x%08h  dst=0x%08h  beats=%0d",
               $time, irq_count, step_name(last_araddr,last_awaddr),
               last_araddr, last_awaddr, last_len);
    end
  end

  // ------------------------------------------------------------
  // SCENARIO 1, 2, 3
  // ------------------------------------------------------------
  task automatic scenario1();
    logic [7:0] beats = 8'd8;
    $display("\n===== SCENARIO 1: MANUAL single-cycle chain =====");
    seed_uart_fifo(IMEM_ADDR, beats);
    axi_lite_push_op(beats, mk_op(1'b0, 3'b001, 4'b0000));
    wait (cpu_irq_pulse); @(posedge clk);
    axi_lite_push_op(beats, mk_op(1'b0, 3'b011, 4'b0001));
    wait (cpu_irq_pulse); @(posedge clk);
    axi_lite_push_op(beats, mk_op(1'b0, 3'b100, 4'b0010));
    wait (cpu_irq_pulse); @(posedge clk);
    $display("===== SCENARIO 1 DONE =====\n");
  endtask

  task automatic scenario2();
    logic [7:0] beats = 8'd8;
    $display("\n===== SCENARIO 2: AUTO mode, repeat x3 =====");
    for (int loop = 1; loop <= 3; loop++) begin
      $display("-- Loop %0d --", loop);
      seed_uart_fifo(IMEM_ADDR + loop*32, beats);
      axi_lite_push_op(beats, mk_op(1'b1, 3'b001, 4'b0000));
      wait (cpu_irq_pulse); @(posedge clk);
      axi_lite_push_op(beats, mk_op(1'b1, 3'b011, 4'b0001));
      wait (cpu_irq_pulse); @(posedge clk);
      axi_lite_push_op(beats, mk_op(1'b1, 3'b100, 4'b0010));
      wait (cpu_irq_pulse); @(posedge clk);
    end
    $display("===== SCENARIO 2 DONE =====\n");
  endtask

  task automatic scenario3();
    logic [7:0] beats = 8'd4;
    $display("\n===== SCENARIO 3: AUTO running + MANUAL injection =====");
    fork
      begin : auto_runner
        for (int loop = 1; loop <= 3; loop++) begin
          $display("-- AUTO Loop %0d --", loop);
          seed_uart_fifo(IMEM_ADDR + 32'h100*loop, beats);
          axi_lite_push_op(beats, mk_op(1'b1, 3'b001, 4'b0000));
          wait (cpu_irq_pulse); @(posedge clk);
          
          if (loop == 3) begin
            $display("[%0t] Injecting MANUAL job while AUTO loop-3 is in progress...", $time);
            axi_lite_push_op(8'd2, mk_op(1'b0, 3'b001, 4'b0000));
          end

          axi_lite_push_op(beats, mk_op(1'b1, 3'b011, 4'b0001));
          wait (cpu_irq_pulse); @(posedge clk);
          axi_lite_push_op(beats, mk_op(1'b1, 3'b100, 4'b0010));
          wait (cpu_irq_pulse); @(posedge clk);
        end
      end
    join
    $display("===== SCENARIO 3 DONE =====\n");
  endtask

  // ------------------------------------------------------------
  // SCENARIO 4
  // ------------------------------------------------------------
  task automatic scenario4();
    $display("\n===== SCENARIO 4: Variable Burst Pointer Check (x5) =====");
    for (int i = 1; i <= 5; i++) begin
      logic [7:0] len;
      len = 8'(i * 4); 
      $display("-- Scen4 Iteration %0d (Burst=%0d) --", i, len);
      seed_uart_fifo(IMEM_ADDR + (i*16), len);
      axi_lite_push_op(len, mk_op(1'b0, 3'b001, 4'b0000));
      wait (cpu_irq_pulse); @(posedge clk);
      axi_lite_push_op(len, mk_op(1'b0, 3'b011, 4'b0001));
      wait (cpu_irq_pulse); @(posedge clk);
      axi_lite_push_op(len, mk_op(1'b0, 3'b100, 4'b0010));
      wait (cpu_irq_pulse); @(posedge clk);
    end
    $display("===== SCENARIO 4 DONE =====\n");
  endtask

  // ------------------------------------------------------------
  // SCENARIO 5
  // ------------------------------------------------------------
  task automatic scenario5();
    $display("\n===== SCENARIO 5: Configuration Test =====");
    // Config Command: Burst=0, OP[23:20]=F, OP[19:16]=Target, OP[15:0]=Size
    
    // Rx_Buffer -> Size=64 (0x40), Base=0x20002000
    axi_lite_write_raw({8'h00, 4'hF, 4'h1, 16'h0040});
    axi_lite_write_raw(32'h2000_2000); 
    $display("[%0t] Configured Rx_Buffer: Base=0x20002000, Size=64B", $time);

    // LDPC_Buffer -> Size=128 (0x80), Base=0x30002000
    axi_lite_write_raw({8'h00, 4'hF, 4'h4, 16'h0080});
    axi_lite_write_raw(32'h3000_2000); 
    $display("[%0t] Configured LDPC_Buffer: Base=0x30002000, Size=128B", $time);

    @(posedge clk);
    
    // Re-Config Base Addr Only
    // Rx_Buffer Base -> 0x2000_4000
    axi_lite_write_raw({8'h00, 4'hF, 4'h1, 16'h0000});
    axi_lite_write_raw(32'h2000_4000);
    $display("[%0t] Re-Configured Rx_Buffer Base -> 0x20004000", $time);

    // LDPC_Buffer Base -> 0x3000_4000
    axi_lite_write_raw({8'h00, 4'hF, 4'h4, 16'h0000});
    axi_lite_write_raw(32'h3000_4000);
    $display("[%0t] Re-Configured LDPC_Buffer Base -> 0x30004000", $time);

    $display("===== SCENARIO 5 DONE =====\n");
  endtask

  // ------------------------------------------------------------
  // SCENARIO 6
  // ------------------------------------------------------------
  task automatic scenario6();
    // Rx_Buffer Base: 0x2000_4000, Size: 64B
    // Pointer reset to 0.
    
    $display("\n===== SCENARIO 6: Overflow / Circular Wrap Test =====");
    
    // 1. Fill 48 bytes (12 beats)
    $display("[%0t] Filling 48 bytes (12 beats)...", $time);
    seed_uart_fifo(IMEM_ADDR, 8'd12); // Should NOT hang now
    axi_lite_push_op(8'd12, mk_op(1'b0, 3'b001, 4'b0000));
    wait (cpu_irq_pulse); @(posedge clk);
    
    // Check Memory content (Rx Buffer)
    // 48 Byte = 12 Word. Hex olarak dump ediyoruz.
    dump_memory("Rx Buffer (After Fill)", 32'h2000_4000, 16); 

    // 2. Attempt Overflow: Write 32 bytes (8 beats)
    // Space left: 16 bytes (4 beats)
    $display("[%0t] Attempting Overflow: Writing 32 bytes (8 beats) into 16 bytes space...", $time);
    seed_uart_fifo(IMEM_ADDR, 8'd8);
    
    axi_lite_push_op(8'd8, mk_op(1'b0, 3'b001, 4'b0000));
    
    // Part 1 (Fill to end)
    wait (cpu_irq_pulse); 
    $display("[%0t] >> Overflow Part 1 Complete (Hit End of Buffer)", $time);
    @(posedge clk);
    
    // Part 2 (Wrap around)
    wait (cpu_irq_pulse); 
    $display("[%0t] >> Overflow Part 2 Complete (Wrapped to Base)", $time);
    @(posedge clk);
    
    // Check Wrapped Data
    dump_memory("Rx Buffer (After Wrap)", 32'h2000_4000, 16);

    // LDPC Buffer Wrap Test (Base 0x3000_4000, Size 128B)
    $display("[%0t] Testing LDPC Buffer Wrap...", $time);
    
    // Fill 25 beats
    axi_lite_push_op(8'd25, mk_op(1'b0, 3'b100, 4'b0010)); 
    wait (cpu_irq_pulse); @(posedge clk);
    
    // Overflow write 10 beats
    axi_lite_push_op(8'd10, mk_op(1'b0, 3'b100, 4'b0010));
    
    wait (cpu_irq_pulse);
    $display("[%0t] >> LDPC Overflow Part 1 Done", $time);
    @(posedge clk);
    
    wait (cpu_irq_pulse);
    $display("[%0t] >> LDPC Overflow Part 2 Done", $time);
    
    dump_memory("LDPC Buffer (Wrapped)", 32'h3000_4000, 10);
    
    $display("===== SCENARIO 6 DONE =====\n");
  endtask

  // ------------------------------------------------------------
  // Main Process
  // ------------------------------------------------------------
  initial begin
    LDPC_irq = 0; UART_irq = 0;
    S_AXI_AWADDR = 0; S_AXI_AWVALID = 0;
    S_AXI_WDATA = 0;  S_AXI_WSTRB = 0; S_AXI_WVALID = 0;
    S_AXI_BREADY = 0;

    @(posedge rst_n);
    repeat (10) @(posedge clk);

    scenario1();
    scenario2();
    scenario3();
    scenario4();
    scenario5();
    scenario6();

    $display("All scenarios completed successfully. Total IRQ count = %0d", irq_count);
    #100 $finish;
  end

endmodule