module DMA_top #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
)(
  input  logic clk,
  input  logic rst_n,

  // ----- Interrupt sources -----
  input  logic LDPC_irq,
  input  logic UART_irq,

  // ===== AXI-Lite (Write-Only) Slave -> Arbiter =====
  input  logic [5:0]   S_AXI_AWADDR,
  input  logic         S_AXI_AWVALID,
  output logic         S_AXI_AWREADY,

  input  logic [31:0]  S_AXI_WDATA,
  input  logic [3:0]   S_AXI_WSTRB,
  input  logic         S_AXI_WVALID,
  output logic         S_AXI_WREADY,

  output logic [1:0]   S_AXI_BRESP,
  output logic         S_AXI_BVALID,
  input  logic         S_AXI_BREADY,

  // ===== AXI4-Full Master -> CPU =====
  // Write Address
  output logic [ADDR_W-1:0]      M_AXI_AWADDR,
  output logic [7:0]             M_AXI_AWLEN,
  output logic [2:0]             M_AXI_AWSIZE,
  output logic [1:0]             M_AXI_AWBURST,
  output logic                   M_AXI_AWVALID,
  input  logic                   M_AXI_AWREADY,

  // Write Data
  output logic [DATA_W-1:0]      M_AXI_WDATA,
  output logic [(DATA_W/8)-1:0]  M_AXI_WSTRB,
  output logic                   M_AXI_WLAST,
  output logic                   M_AXI_WVALID,
  input  logic                   M_AXI_WREADY,

  // Write Response
  input  logic [1:0]             M_AXI_BRESP,
  input  logic                   M_AXI_BVALID,
  output logic                   M_AXI_BREADY,

  // Read Address
  output logic [ADDR_W-1:0]      M_AXI_ARADDR,
  output logic [7:0]             M_AXI_ARLEN,
  output logic [2:0]             M_AXI_ARSIZE,
  output logic [1:0]             M_AXI_ARBURST,
  output logic                   M_AXI_ARVALID,
  input  logic                   M_AXI_ARREADY,

  // Read Data
  input  logic [DATA_W-1:0]      M_AXI_RDATA,
  input  logic [1:0]             M_AXI_RRESP,
  input  logic                   M_AXI_RLAST,
  input  logic                   M_AXI_RVALID,
  output logic                   M_AXI_RREADY,

  // Completion Pulse
  output logic                   cpu_irq_pulse
);

  // -----------------------
  // Internal Wires
  // -----------------------
  logic        reg_to_arb_op_ready;
  logic        arb_to_reg_op_valid;
  logic [31:0] arb_to_reg_op_data;

  logic        reg_to_cpu_code_valid;
  logic        reg_to_cpu_code_ready;
  logic [71:0] reg_to_cpu_code;

  // -----------------------
  // 1. Arbiter
  // -----------------------
  DMA_arbiter #(
    .DEPTH(8)
  ) u_arbiter (
    .clk                 (clk),
    .rst_n               (rst_n),
    
    // Handshake -> Reg File
    .reg_to_arb_op_ready (reg_to_arb_op_ready),
    .arb_to_reg_op_valid (arb_to_reg_op_valid),
    .arb_to_reg_op_data  (arb_to_reg_op_data),

    // IRQs (Şimdilik pass-through veya arbiter içi logic için)
    .LDPC_irq            (LDPC_irq),
    .UART_irq            (UART_irq),

    // AXI-Lite Slave
    .S_AXI_AWADDR        (S_AXI_AWADDR),
    .S_AXI_AWVALID       (S_AXI_AWVALID),
    .S_AXI_AWREADY       (S_AXI_AWREADY),
    .S_AXI_WDATA         (S_AXI_WDATA),
    .S_AXI_WSTRB         (S_AXI_WSTRB),
    .S_AXI_WVALID        (S_AXI_WVALID),
    .S_AXI_WREADY        (S_AXI_WREADY),
    .S_AXI_BRESP         (S_AXI_BRESP),
    .S_AXI_BVALID        (S_AXI_BVALID),
    .S_AXI_BREADY        (S_AXI_BREADY)
  );

  // -----------------------
  // 2. Register File & Logic (GÜNCELLENDİ)
  // -----------------------
  DMA_reg_file u_reg_file (
    .clk                   (clk),
    .rst_n                 (rst_n),

    // Handshake <- Arbiter
    .reg_to_arb_op_ready   (reg_to_arb_op_ready),
    .arb_to_reg_op_valid   (arb_to_reg_op_valid),
    .arb_to_reg_op_data    (arb_to_reg_op_data),

    // Handshake -> CPU
    .reg_to_cpu_code_ready (reg_to_cpu_code_ready),
    .reg_to_cpu_code_valid (reg_to_cpu_code_valid),
    .reg_to_cpu_code       (reg_to_cpu_code),

    // Feedback
    .cpu_irq_pulse         (cpu_irq_pulse)
  );

  // -----------------------
  // 3. CPU (Master)
  // -----------------------
  DMA_cpu #(
    .ADDR_W (ADDR_W),
    .DATA_W (DATA_W)
  ) u_cpu (
    .clk                   (clk),
    .rst_n                 (rst_n),

    .reg_to_cpu_code_valid (reg_to_cpu_code_valid),
    .reg_to_cpu_code_ready (reg_to_cpu_code_ready),
    .reg_to_cpu_code       (reg_to_cpu_code),
    .cpu_irq_pulse         (cpu_irq_pulse),

    // AXI4-Full Master Interface
    .M_AXI_AWADDR (M_AXI_AWADDR), .M_AXI_AWLEN (M_AXI_AWLEN), .M_AXI_AWSIZE (M_AXI_AWSIZE),
    .M_AXI_AWBURST(M_AXI_AWBURST), .M_AXI_AWVALID(M_AXI_AWVALID), .M_AXI_AWREADY(M_AXI_AWREADY),
    .M_AXI_WDATA  (M_AXI_WDATA), .M_AXI_WSTRB  (M_AXI_WSTRB), .M_AXI_WLAST  (M_AXI_WLAST),
    .M_AXI_WVALID (M_AXI_WVALID), .M_AXI_WREADY (M_AXI_WREADY),
    .M_AXI_BRESP  (M_AXI_BRESP), .M_AXI_BVALID (M_AXI_BVALID), .M_AXI_BREADY (M_AXI_BREADY),
    .M_AXI_ARADDR (M_AXI_ARADDR), .M_AXI_ARLEN (M_AXI_ARLEN), .M_AXI_ARSIZE (M_AXI_ARSIZE),
    .M_AXI_ARBURST(M_AXI_ARBURST), .M_AXI_ARVALID(M_AXI_ARVALID), .M_AXI_ARREADY(M_AXI_ARREADY),
    .M_AXI_RDATA  (M_AXI_RDATA), .M_AXI_RRESP  (M_AXI_RRESP), .M_AXI_RLAST  (M_AXI_RLAST),
    .M_AXI_RVALID (M_AXI_RVALID), .M_AXI_RREADY (M_AXI_RREADY)
  );

endmodule


module DMA_arbiter #(
  parameter int DEPTH = 8
)(
  input  logic clk,
  input  logic rst_n,

  // Handshake Arb -> Reg
  input  logic        reg_to_arb_op_ready,
  output logic        arb_to_reg_op_valid,
  output logic [31:0] arb_to_reg_op_data,   // 32-bit veri

  // Interrupts (Opsiyonel kullanım için)
  input  logic LDPC_irq,
  input  logic UART_irq,

  // AXI-Lite Write-Only Slave
  input  logic [5:0]  S_AXI_AWADDR,
  input  logic        S_AXI_AWVALID,
  output logic        S_AXI_AWREADY,

  input  logic [31:0] S_AXI_WDATA,
  input  logic [3:0]  S_AXI_WSTRB,
  input  logic        S_AXI_WVALID,
  output logic        S_AXI_WREADY,

  output logic [1:0]  S_AXI_BRESP,
  output logic        S_AXI_BVALID,
  input  logic        S_AXI_BREADY
);

  logic        aw_captured, w_captured;
  logic [31:0] cap_WDATA;
  logic [3:0]  cap_WSTRB;

  // FIFO: 32-bit genişlik
  logic [31:0]             fifo  [0:DEPTH-1];
  logic [$clog2(DEPTH):0]  count;
  logic [$clog2(DEPTH)-1:0] wptr, rptr;

  // 1. AXI READY Logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      S_AXI_AWREADY <= 1'b0;
      S_AXI_WREADY  <= 1'b0;
    end else begin
      S_AXI_AWREADY <= (~aw_captured) & (~S_AXI_BVALID);
      S_AXI_WREADY  <= (~w_captured)  & (~S_AXI_BVALID);
    end
  end

  // 2. FIFO Output Logic
  assign arb_to_reg_op_valid = (count != 0);
  assign arb_to_reg_op_data  = fifo[rptr];

  // 3. Main Process
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_captured  <= 1'b0;
      w_captured   <= 1'b0;
      cap_WDATA    <= '0;
      cap_WSTRB    <= '0;
      S_AXI_BVALID <= 1'b0;
      S_AXI_BRESP  <= 2'b00;
      wptr         <= '0;
      rptr         <= '0;
      count        <= '0;
    end else begin
      // AXI Capture
      if (S_AXI_AWVALID && S_AXI_AWREADY) aw_captured <= 1'b1;
      
      if (S_AXI_WVALID && S_AXI_WREADY) begin
        cap_WDATA  <= S_AXI_WDATA;
        cap_WSTRB  <= S_AXI_WSTRB;
        w_captured <= 1'b1;
      end

      // Write to FIFO
      if (aw_captured && w_captured && !S_AXI_BVALID) begin
        if (cap_WSTRB == 4'hF) begin
          if (count < DEPTH) begin
            fifo[wptr] <= cap_WDATA; // 32-bit tam veri
            wptr       <= wptr + 1'b1;
            count      <= count + 1'b1;
            S_AXI_BRESP <= 2'b00; // OKAY
          end else begin
            S_AXI_BRESP <= 2'b10; // SLVERR (Full)
          end
        end else begin
          S_AXI_BRESP <= 2'b10;   // SLVERR (Partial write)
        end
        S_AXI_BVALID <= 1'b1;
      end

      // AXI Response Handshake
      if (S_AXI_BVALID && S_AXI_BREADY) begin
        S_AXI_BVALID <= 1'b0;
        aw_captured  <= 1'b0;
        w_captured   <= 1'b0;
      end

      // FIFO Dequeue (Reg File okuduğunda)
      if (arb_to_reg_op_valid && reg_to_arb_op_ready) begin
        rptr  <= rptr + 1'b1;
        count <= count - 1'b1;
      end
    end
  end
endmodule


module DMA_reg_file (
  input  logic        clk,
  input  logic        rst_n,

  // Handshake to/from Arbiter
  output logic        reg_to_arb_op_ready,
  input  logic        arb_to_reg_op_valid,
  input  logic [31:0] arb_to_reg_op_data, 

  // Handshake to/from CPU
  input  logic        reg_to_cpu_code_ready,
  output logic        reg_to_cpu_code_valid,
  output logic [71:0] reg_to_cpu_code,

  // Feedback
  input  logic        cpu_irq_pulse
);

  // ==========================================================================
  // 1. SABITLER ve REGISTER TANIMLARI
  // ==========================================================================

  // Sabit Adresler (Localparam kullanimi - Width belirtmeden)
  localparam ADDR_RX_FIFO    = 32'h4000_0380;
  localparam ADDR_TX_FIFO    = 32'h4000_0340;
  localparam ADDR_LDPC_IN    = 32'h4200_0000;
  localparam ADDR_LDPC_OUT   = 32'h4208_0000;
  localparam ADDR_IMEM       = 32'h0000_1000;
  localparam ADDR_DMEM       = 32'h2000_0000;
  
  // Varsayilan Degerler
  localparam DEF_RX_BASE     = 32'h2000_0040;
  localparam DEF_RX_SIZE     = 32'h0000_1000; 
  localparam DEF_LDPC_BASE   = 32'h3000_0000;
  localparam DEF_LDPC_SIZE   = 32'h0000_1000;

  // Registerlar
  logic [31:0] r_Rx_buffer_base;
  logic [31:0] r_Rx_buffer_size; 
  logic [31:0] r_Rx_buffer_ptr;

  logic [31:0] r_LDPC_out_base;
  logic [31:0] r_LDPC_out_size;
  logic [31:0] r_LDPC_out_ptr;

  // ==========================================================================
  // 2. STATE MACHINE (Localparam ile Enum yerine)
  // ==========================================================================
  // Enum bazi tool'larda sorun cikarabilir, localparam en guvenlisidir.
  localparam [2:0] S_IDLE        = 3'd0;
  localparam [2:0] S_WAIT_ADDR   = 3'd1;
  localparam [2:0] S_SEND_CMD    = 3'd2;
  localparam [2:0] S_WAIT_IRQ    = 3'd3;
  localparam [2:0] S_SETUP_PART2 = 3'd4;
  localparam [2:0] S_UPDATE_PTR  = 3'd5;

  logic [2:0] state; // State degiskeni

  // Aktif İşlem Kayıtları
  logic [7:0]  act_burst_total;
  logic [7:0]  act_burst_part2;
  logic        act_overflow_flag;
  
  logic [3:0]  act_src_sel;
  logic [2:0]  act_dst_sel;
  logic [3:0]  cfg_target_idx;

  // ==========================================================================
  // 3. ADRES HESAPLAMA (Function)
  // ==========================================================================
  function [31:0] get_addr;
    input [3:0] sel;
    begin
      case (sel)
        4'h0: get_addr = ADDR_RX_FIFO;
        4'h1: get_addr = r_Rx_buffer_base + r_Rx_buffer_ptr;
        4'h2: get_addr = ADDR_LDPC_OUT; 
        4'h3: get_addr = ADDR_LDPC_IN;
        4'h4: get_addr = r_LDPC_out_base + r_LDPC_out_ptr;
        4'h5: get_addr = ADDR_TX_FIFO;
        4'h6: get_addr = ADDR_IMEM;
        4'h7: get_addr = ADDR_DMEM;
        default: get_addr = 32'h0;
      endcase
    end
  endfunction

  // ==========================================================================
  // 4. SEQUENTIAL LOGIC
  // ==========================================================================
  
  assign reg_to_arb_op_ready = ((state == S_IDLE) && (!reg_to_cpu_code_valid)) || 
                               (state == S_WAIT_ADDR);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_Rx_buffer_base      <= DEF_RX_BASE;
      r_Rx_buffer_size      <= DEF_RX_SIZE;
      r_Rx_buffer_ptr       <= 0;

      r_LDPC_out_base       <= DEF_LDPC_BASE;
      r_LDPC_out_size       <= DEF_LDPC_SIZE;
      r_LDPC_out_ptr        <= 0;

      reg_to_cpu_code_valid <= 1'b0;
      reg_to_cpu_code       <= '0;
      
      state             <= S_IDLE;
      act_burst_total   <= '0;
      act_burst_part2   <= '0;
      act_overflow_flag <= 1'b0;
      act_src_sel       <= '0;
      act_dst_sel       <= '0;
      cfg_target_idx    <= '0;

    end else begin
      
      case (state)

        // ------------------------------------------------------------
        // IDLE
        // ------------------------------------------------------------
        S_IDLE: begin
          if (arb_to_reg_op_valid && reg_to_arb_op_ready) begin
            logic [31:0] op;
            logic [7:0]  burst_in;
            
            op = arb_to_reg_op_data;
            burst_in = op[31:24];

            // CONFIG MODE
            if (burst_in == 8'd0) begin
               logic [3:0] should_change_addr;
               logic [3:0] which_addr;
               logic [15:0] new_size;
               
               should_change_addr = op[23:20];
               which_addr         = op[19:16];
               new_size           = op[15:0];

               if (new_size != 16'd0) begin
                 if (which_addr == 4'h1) r_Rx_buffer_size <= {16'd0, new_size};
                 if (which_addr == 4'h4) r_LDPC_out_size  <= {16'd0, new_size};
               end
               
               if (should_change_addr == 4'b1111) begin
                 cfg_target_idx <= which_addr;
                 state <= S_WAIT_ADDR;
               end
            end 
            
            // TRANSFER MODE
            else begin
               act_src_sel <= op[3:0];
               act_dst_sel <= op[6:4];
               act_burst_total <= burst_in;
               
               // --- OVERFLOW HESABI ---
               begin
                 logic [31:0] current_ptr;
                 logic [31:0] buffer_sz;
                 logic        is_dynamic_dst;
                 logic [31:0] space_left_bytes;
                 logic [7:0]  space_left_beats;

                 if (op[6:4] == 3'h1) begin // RX Buffer
                    current_ptr = r_Rx_buffer_ptr;
                    buffer_sz   = r_Rx_buffer_size;
                    is_dynamic_dst = 1'b1;
                 end else if (op[6:4] == 3'h4) begin // LDPC Out
                    current_ptr = r_LDPC_out_ptr;
                    buffer_sz   = r_LDPC_out_size;
                    is_dynamic_dst = 1'b1;
                 end else begin
                    is_dynamic_dst = 1'b0;
                    current_ptr = 0; buffer_sz = 0;
                 end

                 space_left_bytes = buffer_sz - current_ptr;
                 space_left_beats = space_left_bytes[9:2];

                 if (is_dynamic_dst && ({24'd0, burst_in} > {24'd0, space_left_beats})) begin
                    // TAŞMA VAR
                    logic [7:0] part1_len;
                    part1_len = space_left_beats;
                    
                    act_burst_part2   <= burst_in - part1_len;
                    act_overflow_flag <= 1'b1; 

                    reg_to_cpu_code <= { part1_len, 
                                         get_addr({1'b0, op[6:4]}), 
                                         get_addr(op[3:0])
                                       };
                 end else begin
                    // TAŞMA YOK
                    act_overflow_flag <= 1'b0;
                    act_burst_part2   <= 0;
                    reg_to_cpu_code   <= { burst_in,
                                           get_addr({1'b0, op[6:4]}),
                                           get_addr(op[3:0])
                                         };
                 end
               end

               reg_to_cpu_code_valid <= 1'b1;
               state <= S_SEND_CMD;
            end
          end
        end

        // ------------------------------------------------------------
        // WAIT_ADDR
        // ------------------------------------------------------------
        S_WAIT_ADDR: begin
           if (arb_to_reg_op_valid && reg_to_arb_op_ready) begin
              logic [31:0] new_base;
              new_base = arb_to_reg_op_data;
              
              if (cfg_target_idx == 4'h1) begin
                  r_Rx_buffer_base <= new_base;
                  r_Rx_buffer_ptr  <= 0; 
              end else if (cfg_target_idx == 4'h4) begin
                  r_LDPC_out_base <= new_base;
                  r_LDPC_out_ptr  <= 0;
              end
              state <= S_IDLE;
           end
        end

        // ------------------------------------------------------------
        // SEND_CMD
        // ------------------------------------------------------------
        S_SEND_CMD: begin
           if (reg_to_cpu_code_ready) begin
              reg_to_cpu_code_valid <= 1'b0; 
              state <= S_WAIT_IRQ;
           end
        end

        // ------------------------------------------------------------
        // WAIT_IRQ
        // ------------------------------------------------------------
        S_WAIT_IRQ: begin
           if (cpu_irq_pulse) begin
              if (act_overflow_flag == 1'b1) begin
                 state <= S_SETUP_PART2;
              end else begin
                 state <= S_UPDATE_PTR;
              end
           end
        end

        // ------------------------------------------------------------
        // SETUP_PART2
        // ------------------------------------------------------------
        S_SETUP_PART2: begin
           logic [31:0] dst_base_addr;
           
           if (act_dst_sel == 3'h1) r_Rx_buffer_ptr <= 0;
           if (act_dst_sel == 3'h4) r_LDPC_out_ptr  <= 0;

           if (act_dst_sel == 3'h1) dst_base_addr = r_Rx_buffer_base;
           else if (act_dst_sel == 3'h4) dst_base_addr = r_LDPC_out_base;
           else dst_base_addr = 0; 

           reg_to_cpu_code <= { act_burst_part2,
                                dst_base_addr,        
                                get_addr(act_src_sel) 
                              };
           reg_to_cpu_code_valid <= 1'b1;
           
           act_overflow_flag <= 1'b0; 
           state <= S_SEND_CMD;
        end

        // ------------------------------------------------------------
        // UPDATE_PTR
        // ------------------------------------------------------------
        S_UPDATE_PTR: begin
           logic [31:0] inc_bytes;
           
           if (act_burst_part2 != 0) begin
              inc_bytes = {22'd0, act_burst_part2, 2'b00};
           end else begin
              inc_bytes = {22'd0, act_burst_total, 2'b00};
           end

           if (act_dst_sel == 3'h1) begin 
              r_Rx_buffer_ptr <= r_Rx_buffer_ptr + inc_bytes;
           end 
           else if (act_dst_sel == 3'h4) begin
              r_LDPC_out_ptr <= r_LDPC_out_ptr + inc_bytes;
           end

           act_burst_part2 <= 0; 
           state <= S_IDLE;
        end

      endcase
    end
  end

endmodule


module DMA_cpu #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Handshake from reg_file
  input  logic                   reg_to_cpu_code_valid,
  output logic                   reg_to_cpu_code_ready,
  input  logic [71:0]            reg_to_cpu_code, // [71:64]=burst, [63:32]=dst, [31:0]=src

  output logic                   cpu_irq_pulse,

  // AXI4-Full Master Interface
  output logic [ADDR_W-1:0]      M_AXI_AWADDR,
  output logic [7:0]             M_AXI_AWLEN,
  output logic [2:0]             M_AXI_AWSIZE,
  output logic [1:0]             M_AXI_AWBURST,
  output logic                   M_AXI_AWVALID,
  input  logic                   M_AXI_AWREADY,

  output logic [DATA_W-1:0]      M_AXI_WDATA,
  output logic [(DATA_W/8)-1:0]  M_AXI_WSTRB,
  output logic                   M_AXI_WLAST,
  output logic                   M_AXI_WVALID,
  input  logic                   M_AXI_WREADY,

  input  logic [1:0]             M_AXI_BRESP,
  input  logic                   M_AXI_BVALID,
  output logic                   M_AXI_BREADY,

  output logic [ADDR_W-1:0]      M_AXI_ARADDR,
  output logic [7:0]             M_AXI_ARLEN,
  output logic [2:0]             M_AXI_ARSIZE,
  output logic [1:0]             M_AXI_ARBURST,
  output logic                   M_AXI_ARVALID,
  input  logic                   M_AXI_ARREADY,

  input  logic [DATA_W-1:0]      M_AXI_RDATA,
  input  logic [1:0]             M_AXI_RRESP,
  input  logic                   M_AXI_RLAST,
  input  logic                   M_AXI_RVALID,
  output logic                   M_AXI_RREADY
);

  localparam int BYTES_PER_BEAT = DATA_W/8;
  localparam [2:0] AXI_SIZE     = (BYTES_PER_BEAT == 4) ? 3'd2 : 3'd0; 

  logic [ADDR_W-1:0] src_addr_q, dst_addr_q;
  logic [7:0]        burst_len_q;
  logic [7:0]        beats_remaining;
  logic              accept_cmd;

  typedef enum logic [2:0] {IDLE, ADDR, XFER, RESP, DONE} state_e;
  state_e state_q, state_d;

  assign reg_to_cpu_code_ready = (state_q == IDLE);

  wire [7:0]  burst_len_w = reg_to_cpu_code[71:64];
  wire [31:0] dst_addr_w  = reg_to_cpu_code[63:32];
  wire [31:0] src_addr_w  = reg_to_cpu_code[31:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cpu_irq_pulse <= 1'b0;
    else        cpu_irq_pulse <= (state_q == DONE);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      src_addr_q      <= '0;
      dst_addr_q      <= '0;
      burst_len_q     <= '0;
      beats_remaining <= '0;
    end else begin
      if (accept_cmd) begin
        src_addr_q      <= src_addr_w;
        dst_addr_q      <= dst_addr_w;
        burst_len_q     <= (burst_len_w == 0) ? 8'd1 : burst_len_w;
        beats_remaining <= (burst_len_w == 0) ? 8'd1 : burst_len_w;
      end else if (state_q == XFER && M_AXI_RVALID && M_AXI_RREADY && M_AXI_WVALID && M_AXI_WREADY) begin
        beats_remaining <= beats_remaining - 8'd1;
      end
    end
  end

  always_comb begin
    M_AXI_AWADDR  = dst_addr_q;
    M_AXI_AWLEN   = (burst_len_q == 0) ? 8'd0 : (burst_len_q - 8'd1);
    M_AXI_AWSIZE  = AXI_SIZE;
    M_AXI_AWBURST = 2'b01; // INCR
    M_AXI_AWVALID = 1'b0;

    M_AXI_WDATA   = M_AXI_RDATA;
    M_AXI_WSTRB   = {BYTES_PER_BEAT{1'b1}};
    M_AXI_WLAST   = (beats_remaining == 8'd1);
    M_AXI_WVALID  = 1'b0;
    M_AXI_BREADY  = 1'b0;

    M_AXI_ARADDR  = src_addr_q;
    M_AXI_ARLEN   = (burst_len_q == 0) ? 8'd0 : (burst_len_q - 8'd1);
    M_AXI_ARSIZE  = AXI_SIZE;
    M_AXI_ARBURST = 2'b01; // INCR
    M_AXI_ARVALID = 1'b0;
    M_AXI_RREADY  = 1'b0;

    accept_cmd    = 1'b0;
    state_d       = state_q;

    unique case (state_q)
      IDLE: begin
        if (reg_to_cpu_code_valid) begin
          accept_cmd = 1'b1;
          state_d    = ADDR;
        end
      end
      ADDR: begin
        M_AXI_ARVALID = 1'b1;
        M_AXI_AWVALID = 1'b1;
        if (M_AXI_ARVALID && M_AXI_ARREADY && M_AXI_AWVALID && M_AXI_AWREADY) begin
          state_d = XFER;
        end
      end
      XFER: begin
        M_AXI_RREADY = 1'b1;
        M_AXI_WVALID = M_AXI_RVALID; // Write only when Read is valid
        if (M_AXI_RVALID && M_AXI_RREADY && M_AXI_WVALID && M_AXI_WREADY && M_AXI_WLAST) begin
          state_d = RESP;
        end
      end
      RESP: begin
        M_AXI_BREADY = 1'b1;
        if (M_AXI_BVALID && M_AXI_BREADY) begin
          state_d = DONE;
        end
      end
      DONE: begin
        state_d = IDLE;
      end
      default: state_d = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= IDLE;
    else        state_q <= state_d;
  end

endmodule




module UART_stream #(
    parameter DATA_WIDTH = 32,      // AXI veri genişliği (32 bit)
    parameter FIFO_DEPTH = 32
)(
    //--------------------------------------
    // Global clock & reset
    //--------------------------------------
    input  logic                  aclk,
    input  logic                  aresetn,

    //--------------------------------------
    // UART RX dış dünya girişleri
    //--------------------------------------
    input  logic                  rx_i,       // UART RX hattı (idle=1)
    input  logic                  baud_tick,  // Her bit merkezinde 1 clk süren tick

    //--------------------------------------
    // GİRİŞ FIFO'su için AXI4-Stream SLAVE
    // (Dış dünya -> UART TX giriş FIFO)
    //--------------------------------------
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic                  s_axis_tlast,

    //--------------------------------------
    // ÇIKIŞ FIFO'su için AXI4-Stream MASTER
    // (UART RX çıkış FIFO -> dış dünya)
    //--------------------------------------
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic                  m_axis_tlast
);

    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

    //========================================================
    // 1) UART RX STATE MACHINE
    //========================================================
    typedef enum logic [2:0] {
        UART_RX_IDLE,        // Hat 1, start bit bekliyor
        UART_RX_START_BIT,   // Start bit'in ortasından sample al
        UART_RX_DATA_BITS,   // Data bitlerini örnekle
        UART_RX_PARITY_BIT,  // Parite kontrolü (opsiyonel)
        UART_RX_STOP_BIT,    // Stop bit(ler)ini kontrol et
        UART_RX_ERROR        // Frame/parite hata durumu
    } uart_rx_state_e;

    uart_rx_state_e rx_state;
    logic [3:0]     rx_bit_cnt;
    logic [7:0]     rx_shift;
    logic           rx_data_valid;   // 1 clk boyunca, yeni byte hazır
    logic [7:0]     rx_data;         // Çözülen 8 bit data
    logic           rx_frame_last;   // Şimdilik 0, ileride paket sonu için kullanırsın

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rx_state      <= UART_RX_IDLE;
            rx_bit_cnt    <= '0;
            rx_shift      <= '0;
            rx_data_valid <= 1'b0;
            rx_data       <= '0;
        end else begin
            rx_data_valid <= 1'b0; // default: sadece STOP_BIT sonunda 1 olacak

            if (baud_tick) begin
                case (rx_state)

                    //----------------------------------
                    // IDLE: RX hattı 1, start bit (0) bekleniyor
                    //----------------------------------
                    UART_RX_IDLE: begin
                        if (rx_i == 1'b0) begin
                            // Start bit düştü
                            rx_state   <= UART_RX_START_BIT;
                        end
                    end

                    //----------------------------------
                    // START BIT: bit ortasında tekrar bak
                    //----------------------------------
                    UART_RX_START_BIT: begin
                        if (rx_i == 1'b0) begin
                            // Gerçekten start bitmiş
                            rx_bit_cnt <= 4'd0;
                            rx_state   <= UART_RX_DATA_BITS;
                        end else begin
                            // False start, geri dön
                            rx_state   <= UART_RX_IDLE;
                        end
                    end

                    //----------------------------------
                    // DATA BITS: 8 bit oku (LSB first)
                    //----------------------------------
                    UART_RX_DATA_BITS: begin
                        // LSB first: gelen biti MSB'ye atıp sola kaydırma vb.
                        // Burada en basit haliyle:
                        rx_shift <= {rx_i, rx_shift[7:1]};   // rx_i -> bit7, eski bit7 -> bit6 ...

                        if (rx_bit_cnt == 4'd7) begin
                            // 8. bit de okununca stop bit'e geç
                            rx_state <= UART_RX_STOP_BIT;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 4'd1;
                        end
                    end

                    //----------------------------------
                    // STOP BIT
                    //----------------------------------
                    UART_RX_STOP_BIT: begin
                        if (rx_i == 1'b1) begin
                            // Geçerli frame
                            rx_data       <= rx_shift;
                            rx_data_valid <= 1'b1;   // 1 clk boyunca 1
                            rx_state      <= UART_RX_IDLE;
                        end else begin
                            // Framing error
                            rx_state      <= UART_RX_ERROR;
                        end
                    end

                    //----------------------------------
                    // ERROR
                    //----------------------------------
                    UART_RX_ERROR: begin
                        // Hat tekrar 1 olunca IDLE'a dön
                        if (rx_i == 1'b1) begin
                            rx_state <= UART_RX_IDLE;
                        end
                    end

                    default: rx_state <= UART_RX_IDLE;
                endcase
            end
        end
    end

    // Şimdilik frame sonu bilgisi yok, 0'a bağla
    assign rx_frame_last = 1'b0;


    //========================================================
    // 2) 4x8-bit -> 32-bit PACKER
    //========================================================
    logic [1:0]  pack_byte_cnt;   // 0..3 arası kaç byte topladık
    logic [31:0] pack_word, pack_word_next;
    logic        fifo_write_en;
    logic [31:0] fifo_write_data;

    // next-state logic (comb)
    always_comb begin
        pack_word_next  = pack_word;
        fifo_write_en   = 1'b0;
        fifo_write_data = 32'd0;

        if (rx_data_valid) begin
            case (pack_byte_cnt)
                2'd0: pack_word_next[7:0]   = rx_data;
                2'd1: pack_word_next[15:8]  = rx_data;
                2'd2: pack_word_next[23:16] = rx_data;
                2'd3: pack_word_next[31:24] = rx_data;
            endcase

            if (pack_byte_cnt == 2'd3) begin
                // 4. byte da geldi, artık 32-bit word hazır
                fifo_write_en   = 1'b1;
                fifo_write_data = pack_word_next;
            end
        end
    end

    // register kısmı
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            pack_byte_cnt <= 2'd0;
            pack_word     <= 32'd0;
        end else begin
            pack_word <= pack_word_next;

            if (rx_data_valid) begin
                if (pack_byte_cnt == 2'd3)
                    pack_byte_cnt <= 2'd0;
                else
                    pack_byte_cnt <= pack_byte_cnt + 2'd1;
            end
        end
    end


    //========================================================
    // 3) GİRİŞ FIFO (AXI SLAVE -> UART TX)
    //========================================================
    logic [FIFO_DEPTH-1:0][DATA_WIDTH-1:0] input_Fifo_Reg;
    logic [FIFO_DEPTH-1:0]                 input_Fifo_Last;   // TLAST bilgisi

    logic [PTR_WIDTH-1:0] input_FIFO_w_ptr, input_FIFO_r_ptr;

    logic input_fifo_full;
    logic input_fifo_empty;

    assign input_fifo_empty = (input_FIFO_w_ptr == input_FIFO_r_ptr);
    assign input_fifo_full  = ((input_FIFO_w_ptr + 1'b1) == input_FIFO_r_ptr);

    // AXI4-Stream slave: ready FIFO dolu değilken 1
    assign s_axis_tready = ~input_fifo_full;

    // Yazma tarafı: AXI4-Stream handshake
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            input_FIFO_w_ptr <= '0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                input_Fifo_Reg [input_FIFO_w_ptr] <= s_axis_tdata;
                input_Fifo_Last[input_FIFO_w_ptr] <= s_axis_tlast; // burst sonu bilgisi
                input_FIFO_w_ptr <= input_FIFO_w_ptr + 1'b1;
            end
        end
    end

    // UART TX tarafı için basit okuma iskeleti
    logic                  uart_tx_pop;
    logic [DATA_WIDTH-1:0] uart_tx_data;
    logic                  uart_tx_last;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            input_FIFO_r_ptr <= '0;
        end else begin
            if (uart_tx_pop && !input_fifo_empty) begin
                uart_tx_data <= input_Fifo_Reg [input_FIFO_r_ptr];
                uart_tx_last <= input_Fifo_Last[input_FIFO_r_ptr];
                input_FIFO_r_ptr <= input_FIFO_r_ptr + 1'b1;
            end
        end
    end


    //========================================================
    // 4) ÇIKIŞ FIFO (32-bit word'ler, AXI MASTER)
    //========================================================
    logic [FIFO_DEPTH-1:0][31:0] out_Fifo_Reg;  // 32-bit word FIFO
    logic [FIFO_DEPTH-1:0]       out_Fifo_Last; // TLAST bilgisi

    logic [PTR_WIDTH-1:0] out_FIFO_w_ptr, out_FIFO_r_ptr;

    logic output_fifo_full;
    logic output_fifo_empty;

    assign output_fifo_empty = (out_FIFO_w_ptr == out_FIFO_r_ptr);
    assign output_fifo_full  = ((out_FIFO_w_ptr + 1'b1) == out_FIFO_r_ptr);

    // Packer'dan gelen 32-bit word'ü FIFO'ya yaz
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            out_FIFO_w_ptr <= '0;
        end else begin
            if (fifo_write_en && !output_fifo_full) begin
                out_Fifo_Reg [out_FIFO_w_ptr] <= fifo_write_data;
                // TLAST mantığını isteğine göre doldur:
                out_Fifo_Last[out_FIFO_w_ptr] <= rx_frame_last; // şimdilik 0
                out_FIFO_w_ptr <= out_FIFO_w_ptr + 1'b1;
            end
        end
    end

    // AXI4-Stream master sinyalleri için register
    logic [DATA_WIDTH-1:0] m_axis_tdata_r;
    logic                  m_axis_tvalid_r;
    logic                  m_axis_tlast_r;

    assign m_axis_tdata  = m_axis_tdata_r;
    assign m_axis_tvalid = m_axis_tvalid_r;
    assign m_axis_tlast  = m_axis_tlast_r;

    // Okuma tarafı: AXI4-Stream master handshake
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            out_FIFO_r_ptr  <= '0;
            m_axis_tdata_r  <= '0;
            m_axis_tlast_r  <= 1'b0;
            m_axis_tvalid_r <= 1'b0;
        end else begin
            // FIFO boş değilse veri sun
            if (!output_fifo_empty) begin
                m_axis_tdata_r  <= out_Fifo_Reg [out_FIFO_r_ptr];
                m_axis_tlast_r  <= out_Fifo_Last[out_FIFO_r_ptr];
                m_axis_tvalid_r <= 1'b1;
            end else begin
                m_axis_tvalid_r <= 1'b0;
            end

            // Handshake gerçekleştiğinde bir sonraki elemana geç
            if (m_axis_tvalid_r && m_axis_tready) begin
                out_FIFO_r_ptr <= out_FIFO_r_ptr + 1'b1;
            end
        end
    end

endmodule



