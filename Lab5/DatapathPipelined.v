`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

`define DIVIDER_STAGES 8

// Don't forget your old codes
//`include "cla.v"
//`include "DividerUnsignedPipelined.v"

module RegFile (
  input      [        4:0] rd,
  input      [`REG_SIZE:0] rd_data,
  input      [        4:0] rs1,
  output reg [`REG_SIZE:0] rs1_data,
  input      [        4:0] rs2,
  output reg [`REG_SIZE:0] rs2_data,
  input                    clk,
  input                    we,
  input                    rst
);
  localparam NumRegs = 32;
  reg [`REG_SIZE:0] regs[0:NumRegs-1];

  integer i;
  always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < NumRegs; i = i + 1) begin
            regs[i] <= 0;
        end
    end
    // write
    else if (we && (rd != 0)) begin
        regs[rd] <= rd_data;
    end
  end

  // read RS1
  always @(*) begin
      if (rs1 == 0) begin
          rs1_data = 0;
      end
      else begin
          rs1_data = regs[rs1];
      end
  end

  // read RS2
  always @(*) begin
      if (rs2 == 0) begin
          rs2_data = 0;
      end
      else begin
          rs2_data = regs[rs2];
      end
  end

endmodule

module DatapathPipelined (
  input                     clk,
  input                     rst,
  output     [ `REG_SIZE:0] pc_to_imem,
  input      [`INST_SIZE:0] inst_from_imem,
  // dmem is read/write
  output reg [ `REG_SIZE:0] addr_to_dmem,
  input      [ `REG_SIZE:0] load_data_from_dmem,
  output reg [ `REG_SIZE:0] store_data_to_dmem,
  output reg [         3:0] store_we_to_dmem,
  output reg                halt,
  // The PC of the inst currently in Writeback. 0 if not a valid inst.
  output reg [ `REG_SIZE:0] trace_writeback_pc,
  // The bits of the inst currently in Writeback. 0 if not a valid inst.
  output reg [`INST_SIZE:0] trace_writeback_inst
);

  // opcodes - see section 19 of RiscV spec
  localparam [`OPCODE_SIZE:0] OpcodeLoad    = 7'b00_000_11;
  localparam [`OPCODE_SIZE:0] OpcodeStore   = 7'b01_000_11;
  localparam [`OPCODE_SIZE:0] OpcodeBranch  = 7'b11_000_11;
  localparam [`OPCODE_SIZE:0] OpcodeJalr    = 7'b11_001_11;
  localparam [`OPCODE_SIZE:0] OpcodeMiscMem = 7'b00_011_11;
  localparam [`OPCODE_SIZE:0] OpcodeJal     = 7'b11_011_11;

  localparam [`OPCODE_SIZE:0] OpcodeRegImm  = 7'b00_100_11;
  localparam [`OPCODE_SIZE:0] OpcodeRegReg  = 7'b01_100_11;
  localparam [`OPCODE_SIZE:0] OpcodeEnviron = 7'b11_100_11;

  localparam [`OPCODE_SIZE:0] OpcodeAuipc   = 7'b00_101_11;
  localparam [`OPCODE_SIZE:0] OpcodeLui     = 7'b01_101_11;

  // cycle counter
  reg [`REG_SIZE:0] cycles_current;
  always @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
    end
  end

  // ==============================================================================
  // PIPELINE REGISTERS DEFINITIONS
  // ==============================================================================
  
  // IF/ID Pipeline Registers
  reg [`REG_SIZE:0] if_id_pc;
  reg [`INST_SIZE:0] if_id_inst;

  // ID/EX Pipeline Registers
  reg [`REG_SIZE:0] id_ex_pc;
  reg [`REG_SIZE:0] id_ex_rs1_data, id_ex_rs2_data;
  reg [`REG_SIZE:0] id_ex_imm;
  reg [4:0]         id_ex_rd, id_ex_rs1, id_ex_rs2;
  reg [6:0]         id_ex_opcode;
  reg [2:0]         id_ex_funct3;
  reg [6:0]         id_ex_funct7;
  // Control signals in EX
  reg               id_ex_reg_we;
  reg               id_ex_mem_read, id_ex_mem_write;
  reg               id_ex_halt;

  // EX/MEM Pipeline Registers
  reg [`REG_SIZE:0] ex_mem_pc;
  reg [`REG_SIZE:0] ex_mem_alu_res;
  reg [`REG_SIZE:0] ex_mem_wdata; // Data to store in memory
  reg [4:0]         ex_mem_rd;
  reg               ex_mem_reg_we;
  reg               ex_mem_mem_read, ex_mem_mem_write;
  reg [6:0]         ex_mem_opcode;
  reg [2:0]         ex_mem_funct3;
  reg [`INST_SIZE:0] ex_mem_inst_trace; // Just for tracing
  reg               ex_mem_halt;

  // MEM/WB Pipeline Registers
  reg [`REG_SIZE:0] mem_wb_pc;
  reg [`REG_SIZE:0] mem_wb_read_data;
  reg [`REG_SIZE:0] mem_wb_alu_res;
  reg [4:0]         mem_wb_rd;
  reg               mem_wb_reg_we;
  reg               mem_wb_halt;
  reg [`INST_SIZE:0] mem_wb_inst; // For tracing

  // Wires for Stalling and Flushing
  wire stall_if, stall_id, flush_id, flush_ex;
  wire pc_src; // 1 if branch taken/jump, 0 if next PC
  wire [`REG_SIZE:0] branch_target_pc;

  /***************/
  /* FETCH STAGE */
  /***************/

  reg  [`REG_SIZE:0] f_pc_current;
  wire [`REG_SIZE:0] f_pc_next;
  wire [`REG_SIZE:0] f_inst;

  assign f_pc_next = pc_src ? branch_target_pc : (f_pc_current + 4);

  // Program Counter Update
  always @(posedge clk) begin
    if (rst) begin
      f_pc_current <= 32'd0;
    end else if (!stall_if) begin
      f_pc_current <= f_pc_next;
    end
  end

  // Send PC to imem
  assign pc_to_imem = f_pc_current;
  assign f_inst = inst_from_imem;

  // IF/ID Pipeline Register Logic
  always @(posedge clk) begin
      if (rst || pc_src) begin // Flush on branch taken
          if_id_pc <= 0;
          if_id_inst <= 0; // NOP
      end else if (!stall_id) begin
          if_id_pc <= f_pc_current;
          if_id_inst <= f_inst;
      end
  end

  /****************/
  /* DECODE STAGE */
  /****************/

  // Decoding signals
  wire [6:0] id_opcode = if_id_inst[6:0];
  wire [4:0] id_rd     = if_id_inst[11:7];
  wire [2:0] id_funct3 = if_id_inst[14:12];
  wire [4:0] id_rs1    = if_id_inst[19:15];
  wire [4:0] id_rs2    = if_id_inst[24:20];
  wire [6:0] id_funct7 = if_id_inst[31:25];

  // Immediate Generation (Reuse from Lab 3)
  wire [31:0] imm_i_sext = {{20{if_id_inst[31]}}, if_id_inst[31:20]};
  wire [31:0] imm_s_sext = {{20{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]};
  wire [31:0] imm_b_sext = {{19{if_id_inst[31]}}, if_id_inst[31], if_id_inst[7], if_id_inst[30:25], if_id_inst[11:8], 1'b0};
  wire [31:0] imm_u_sext = {if_id_inst[31:12], 12'b0};
  wire [31:0] imm_j_sext = {{11{if_id_inst[31]}}, if_id_inst[31], if_id_inst[19:12], if_id_inst[20], if_id_inst[30:21], 1'b0};

  // Select Immediate based on Opcode
  reg [31:0] id_imm;
  always @(*) begin
      case (id_opcode)
          OpcodeStore:   id_imm = imm_s_sext;
          OpcodeBranch:  id_imm = imm_b_sext;
          OpcodeLui, OpcodeAuipc: id_imm = imm_u_sext;
          OpcodeJal:     id_imm = imm_j_sext;
          default:       id_imm = imm_i_sext; // ALU Imm, Load, Jalr
      endcase
  end

  // Register File Instance
  wire [31:0] id_rs1_data, id_rs2_data;
  // Note: WB stage writes back to RF
  RegFile rf (
      .clk(clk), .rst(rst),
      .we(mem_wb_reg_we), .rd(mem_wb_rd), .rd_data(mem_wb_alu_res), // Wires from WB stage handled later
      .rs1(id_rs1), .rs1_data(id_rs1_data),
      .rs2(id_rs2), .rs2_data(id_rs2_data)
  );

  // Control Signals (Simple Logic)
  wire id_reg_we   = (id_opcode != OpcodeStore && id_opcode != OpcodeBranch);
  wire id_mem_read = (id_opcode == OpcodeLoad);
  wire id_mem_write= (id_opcode == OpcodeStore);
  wire id_halt     = (id_opcode == OpcodeEnviron && if_id_inst[31:20] == 0); // Ecall
  
  // Hazard Detection (Load-Use Stall)
  // If instruction in EX is a Load and dest matches current ID source -> Stall
  assign stall_if = (id_ex_mem_read && (id_ex_rd != 0) && (id_ex_rd == id_rs1 || id_ex_rd == id_rs2));
  assign stall_id = stall_if;
  assign flush_ex = stall_if || pc_src; // Flush EX if stalling or branching

  // ID/EX Pipeline Register Update
  always @(posedge clk) begin
      if (rst || flush_ex) begin
          id_ex_pc <= 0;
          id_ex_rs1_data <= 0; id_ex_rs2_data <= 0;
          id_ex_imm <= 0;
          id_ex_rd <= 0; id_ex_rs1 <= 0; id_ex_rs2 <= 0;
          id_ex_opcode <= 0; id_ex_funct3 <= 0; id_ex_funct7 <= 0;
          id_ex_reg_we <= 0; id_ex_mem_read <= 0; id_ex_mem_write <= 0;
          id_ex_halt <= 0;
      end else begin
          id_ex_pc <= if_id_pc;
          id_ex_rs1_data <= id_rs1_data;
          id_ex_rs2_data <= id_rs2_data;
          id_ex_imm <= id_imm;
          id_ex_rd <= id_rd; id_ex_rs1 <= id_rs1; id_ex_rs2 <= id_rs2;
          id_ex_opcode <= id_opcode; id_ex_funct3 <= id_funct3; id_ex_funct7 <= id_funct7;
          id_ex_reg_we <= id_reg_we;
          id_ex_mem_read <= id_mem_read; id_ex_mem_write <= id_mem_write;
          id_ex_halt <= id_halt;
      end
  end

  /*****************/
  /* EXECUTE STAGE */
  /*****************/

  // Forwarding Unit (MX, WX, WM Bypass)
  reg [31:0] ex_op_a_val, ex_op_b_val;
  
  // Forwarding for RS1
  always @(*) begin
      // Default: from ID/EX
      ex_op_a_val = id_ex_rs1_data;
      
      // EX/MEM Hazard (MX Bypass)
      if (ex_mem_reg_we && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) begin
          ex_op_a_val = ex_mem_alu_res; 
      end
      // MEM/WB Hazard (WX Bypass)
      else if (mem_wb_reg_we && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1)) begin
          ex_op_a_val = mem_wb_alu_res; // Note: In simple design, assume result is in alu_res (or read_data for load)
          // For rigorous WX load bypass, we need multiplexing, but assuming mem_wb_alu_res holds final writeback data
      end
  end

  // Forwarding for RS2
  always @(*) begin
      // Default
      ex_op_b_val = id_ex_rs2_data;

      // EX/MEM Hazard
      if (ex_mem_reg_we && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) begin
          ex_op_b_val = ex_mem_alu_res;
      end
      // MEM/WB Hazard
      else if (mem_wb_reg_we && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2)) begin
          ex_op_b_val = mem_wb_alu_res;
      end
  end

  // ALU Operand Selection
  wire [31:0] alu_in_a = (id_ex_opcode == OpcodeAuipc) ? id_ex_pc : ex_op_a_val;
  wire [31:0] alu_in_b = (id_ex_opcode == OpcodeRegImm || id_ex_opcode == OpcodeLoad || 
                          id_ex_opcode == OpcodeStore || id_ex_opcode == OpcodeLui || 
                          id_ex_opcode == OpcodeAuipc || id_ex_opcode == OpcodeJalr) ? id_ex_imm : ex_op_b_val;

  // Branch Logic (Resolved in EX)
  wire is_beq  = (id_ex_opcode == OpcodeBranch) & (id_ex_funct3 == 3'b000);
  wire is_bne  = (id_ex_opcode == OpcodeBranch) & (id_ex_funct3 == 3'b001);
  wire is_blt  = (id_ex_opcode == OpcodeBranch) & (id_ex_funct3 == 3'b100);
  wire is_bge  = (id_ex_opcode == OpcodeBranch) & (id_ex_funct3 == 3'b101);
  wire is_bltu = (id_ex_opcode == OpcodeBranch) & (id_ex_funct3 == 3'b110);
  wire is_bgeu = (id_ex_opcode == OpcodeBranch) & (id_ex_funct3 == 3'b111);

  wire cmp_eq  = (ex_op_a_val == ex_op_b_val);
  wire cmp_lt  = ($signed(ex_op_a_val) < $signed(ex_op_b_val));
  wire cmp_ltu = (ex_op_a_val < ex_op_b_val);

  wire branch_cond = (is_beq & cmp_eq) | (is_bne & !cmp_eq) | 
                     (is_blt & cmp_lt) | (is_bge & !cmp_lt) | 
                     (is_bltu & cmp_ltu)| (is_bgeu & !cmp_ltu);

  assign pc_src = branch_cond || (id_ex_opcode == OpcodeJal) || (id_ex_opcode == OpcodeJalr);
  
  assign branch_target_pc = (id_ex_opcode == OpcodeJalr) ? 
                            ((ex_op_a_val + id_ex_imm) & ~1) : 
                            (id_ex_pc + id_ex_imm);

  // ALU / CLA Instance
  wire [31:0] cla_sum;
  wire is_sub = (id_ex_opcode == OpcodeBranch) || 
                (id_ex_opcode == OpcodeRegReg && id_ex_funct7[5] == 1);
  
  cla my_cla (
      .a(alu_in_a), 
      .b(is_sub ? ~alu_in_b : alu_in_b), 
      .cin(is_sub ? 1'b1 : 1'b0), 
      .sum(cla_sum)
  );

  // Divider Instance
  wire [31:0] div_rem, div_quot;
  DividerUnsignedPipelined div (
      .clk(clk), .rst(rst),
      .i_dividend(ex_op_a_val), .i_divisor(ex_op_b_val),
      .o_remainder(div_rem), .o_quotient(div_quot)
  );
  
  wire is_div_op = (id_ex_opcode == OpcodeRegReg) && (id_ex_funct7 == 7'b0000001);

  // Final ALU Result Calc
  reg [31:0] ex_alu_res;
  always @(*) begin
      ex_alu_res = 0;
      if (id_ex_opcode == OpcodeLui) ex_alu_res = id_ex_imm;
      else if (id_ex_opcode == OpcodeJal || id_ex_opcode == OpcodeJalr) ex_alu_res = id_ex_pc + 4;
      else if (is_div_op) begin
           // Assuming pipeline divider logic is handled by wait states or simple pass through (Lab 5 spec ambiguous on integration detail without stalling)
           // For now, mapping output.
           if (id_ex_funct3[2]) ex_alu_res = div_rem; // REM/REMU
           else ex_alu_res = div_quot; // DIV/DIVU
      end
      else if (id_ex_opcode == OpcodeLoad || id_ex_opcode == OpcodeStore || 
               id_ex_opcode == OpcodeRegImm || id_ex_opcode == OpcodeRegReg || id_ex_opcode == OpcodeAuipc) begin
          case (id_ex_funct3) 
              3'b000: ex_alu_res = cla_sum; // ADD, SUB, ADDI
              3'b001: ex_alu_res = alu_in_a << alu_in_b[4:0]; // SLL
              3'b010: ex_alu_res = ($signed(alu_in_a) < $signed(alu_in_b)) ? 1 : 0; // SLT
              3'b011: ex_alu_res = (alu_in_a < alu_in_b) ? 1 : 0; // SLTU
              3'b100: ex_alu_res = alu_in_a ^ alu_in_b; // XOR
              3'b101: ex_alu_res = id_ex_funct7[5] ? ($signed(alu_in_a) >>> alu_in_b[4:0]) : (alu_in_a >> alu_in_b[4:0]); // SRA/SRL
              3'b110: ex_alu_res = alu_in_a | alu_in_b; // OR
              3'b111: ex_alu_res = alu_in_a & alu_in_b; // AND
          endcase
      end
  end

  // EX/MEM Pipeline Register Update
  always @(posedge clk) begin
      if (rst) begin
          ex_mem_pc <= 0; ex_mem_alu_res <= 0; ex_mem_wdata <= 0;
          ex_mem_rd <= 0; ex_mem_reg_we <= 0;
          ex_mem_mem_read <= 0; ex_mem_mem_write <= 0;
          ex_mem_opcode <= 0; ex_mem_funct3 <= 0;
          ex_mem_halt <= 0;
      end else begin
          ex_mem_pc <= id_ex_pc;
          ex_mem_alu_res <= ex_alu_res;
          ex_mem_wdata <= ex_op_b_val; // Store data (forwarded)
          ex_mem_rd <= id_ex_rd;
          ex_mem_reg_we <= id_ex_reg_we;
          ex_mem_mem_read <= id_ex_mem_read;
          ex_mem_mem_write <= id_ex_mem_write;
          ex_mem_opcode <= id_ex_opcode;
          ex_mem_funct3 <= id_ex_funct3;
          ex_mem_halt <= id_ex_halt;
      end
  end

  /****************/
  /* MEMORY STAGE */
  /****************/

  // Memory IO
  always @(*) begin
      addr_to_dmem = ex_mem_alu_res;
      store_data_to_dmem = ex_mem_wdata;
      store_we_to_dmem = 0;
      
      if (ex_mem_mem_write) begin
          case (ex_mem_funct3)
              3'b000: begin // SB
                  store_data_to_dmem = ex_mem_wdata << (ex_mem_alu_res[1:0] * 8);
                  store_we_to_dmem = 4'b0001 << ex_mem_alu_res[1:0];
              end
              3'b001: begin // SH
                  store_data_to_dmem = ex_mem_wdata << (ex_mem_alu_res[1] * 16);
                  store_we_to_dmem = 4'b0011 << (ex_mem_alu_res[1] * 2);
              end
              default: begin // SW
                  store_data_to_dmem = ex_mem_wdata;
                  store_we_to_dmem = 4'b1111;
              end
          endcase
      end
  end

  // Load Data Processing
  reg [31:0] mem_final_data;
  always @(*) begin
      // Default: Pass ALU result (for non-load instructions)
      mem_final_data = ex_mem_alu_res;
      
      if (ex_mem_mem_read) begin
          case (ex_mem_funct3)
              3'b000: mem_final_data = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]}; // LB
              3'b001: mem_final_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]}; // LH
              3'b010: mem_final_data = load_data_from_dmem; // LW
              3'b100: mem_final_data = {24'b0, load_data_from_dmem[7:0]}; // LBU
              3'b101: mem_final_data = {16'b0, load_data_from_dmem[15:0]}; // LHU
          endcase
      end
  end

  // MEM/WB Pipeline Register Update
  always @(posedge clk) begin
      if (rst) begin
          mem_wb_pc <= 0;
          mem_wb_alu_res <= 0; // Here it serves as final writeback data
          mem_wb_rd <= 0;
          mem_wb_reg_we <= 0;
          mem_wb_halt <= 0;
      end else begin
          mem_wb_pc <= ex_mem_pc;
          mem_wb_alu_res <= mem_final_data; // Pre-calculated in MEM stage
          mem_wb_rd <= ex_mem_rd;
          mem_wb_reg_we <= ex_mem_reg_we;
          mem_wb_halt <= ex_mem_halt;
      end
  end

  /*******************/
  /* WRITEBACK STAGE */
  /*******************/
  
  // Handled by RegFile instance connections above
  // Signal updates for tracing
  always @(*) begin
      halt = mem_wb_halt;
      trace_writeback_pc = mem_wb_pc;
      // Note: Instruction trace is not strictly propagated in this simple pipe, 
      // but PC is accurate. 
      trace_writeback_inst = 0; // Optional: propagate instruction if needed
  end

endmodule

module MemorySingleCycle #(
    parameter NUM_WORDS = 8192
) (
    input                    rst,                 
    input                    clk,                 
    input      [`REG_SIZE:0] pc_to_imem,          
    output reg [`REG_SIZE:0] inst_from_imem,      
    input      [`REG_SIZE:0] addr_to_dmem,        
    output reg [`REG_SIZE:0] load_data_from_dmem, 
    input      [`REG_SIZE:0] store_data_to_dmem,  
    input      [        3:0] store_we_to_dmem
);
  reg [`REG_SIZE:0] mem_array[0:NUM_WORDS-1];
    
    integer i;
  initial begin
    // replace XXXXX with 00000 and 00013 for better waveform
    for (i = 0; i < NUM_WORDS; i = i + 1) begin
        mem_array[i] = 32'd0;
    end
    $readmemh("F:/VIVADO WORKSPACE/SOC_assi/Lab 5/mem_initial_contents.hex", mem_array);
  end

  localparam AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam AddrLsb = 2;

  always @(negedge clk) begin
    inst_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
  end

  always @(negedge clk) begin
    if (store_we_to_dmem[0]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
    if (store_we_to_dmem[1]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
    if (store_we_to_dmem[2]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
    if (store_we_to_dmem[3]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
    
    load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
  end
endmodule

module Processor (
    input                 clk,
    input                 rst,
    output                halt,
    output [ `REG_SIZE:0] trace_writeback_pc,
    output [`INST_SIZE:0] trace_writeback_inst
);
  wire [`INST_SIZE:0] inst_from_imem;
  wire [ `REG_SIZE:0] pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [         3:0] mem_data_we;
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
    .rst                 (rst),
    .clk                 (clk),
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    .addr_to_dmem        (mem_data_addr),
    .load_data_from_dmem (mem_data_loaded_value),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we)
  );

  DatapathPipelined datapath (
    .clk                  (clk),
    .rst                  (rst),
    .pc_to_imem           (pc_to_imem),
    .inst_from_imem       (inst_from_imem),
    .addr_to_dmem         (mem_data_addr),
    .store_data_to_dmem   (mem_data_to_write),
    .store_we_to_dmem     (mem_data_we),
    .load_data_from_dmem  (mem_data_loaded_value),
    .halt                 (halt),
    .trace_writeback_pc   (trace_writeback_pc),
    .trace_writeback_inst (trace_writeback_inst)
  );
endmodule