/* INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

// Don't forget your CLA and Divider
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

  // TODO: copy your homework #3 code here
  localparam NumRegs = 32;
  reg [`REG_SIZE:0] regs[0:NumRegs-1];

  // TODO: your code here
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

module DatapathMultiCycle (
    input                    clk,
    input                    rst,
    output reg               halt,
    output     [`REG_SIZE:0] pc_to_imem,
    input      [`REG_SIZE:0] inst_from_imem,
    // addr_to_dmem is a read-write port
    output reg [`REG_SIZE:0] addr_to_dmem,
    input      [`REG_SIZE:0] load_data_from_dmem,
    output reg [`REG_SIZE:0] store_data_to_dmem,
    output reg [        3:0] store_we_to_dmem,
    
    // LED
    output wire [3:0]        led_debug
);

  // TODO: your code here (largely based on homework #3)
// components of the instruction
  wire [           6:0] inst_funct7;
  wire [           4:0] inst_rs2;
  wire [           4:0] inst_rs1;
  wire [           2:0] inst_funct3;
  wire [           4:0] inst_rd;
  wire [`OPCODE_SIZE:0] inst_opcode;

  // split R-type instruction - see section 2.2 of RiscV spec
  assign {inst_funct7, inst_rs2, inst_rs1, inst_funct3, inst_rd, inst_opcode} = inst_from_imem;

  // setup for I, S, B & J type instructions
  // I - short immediates and loads
  wire [11:0] imm_i;
  assign imm_i = inst_from_imem[31:20];
  wire [ 4:0] imm_shamt = inst_from_imem[24:20];

  // S - stores
  wire [11:0] imm_s;
  assign imm_s = {inst_funct7, inst_rd};

  // B - conditionals
  wire [12:0] imm_b;
  assign {imm_b[12], imm_b[10:1], imm_b[11], imm_b[0]} = {inst_funct7, inst_rd, 1'b0};

  // J - unconditional jumps
  wire [20:0] imm_j;
  assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {inst_from_imem[31:12], 1'b0};
  
  // U - Upper immediate (them cho LUI/AUIPC)
  wire [31:0] imm_u = {inst_from_imem[31:12], 12'b0};

  wire [`REG_SIZE:0] imm_i_sext = {{20{imm_i[11]}}, imm_i[11:0]};
  wire [`REG_SIZE:0] imm_s_sext = {{20{imm_s[11]}}, imm_s[11:0]};
  wire [`REG_SIZE:0] imm_b_sext = {{19{imm_b[12]}}, imm_b[12:0]};
  wire [`REG_SIZE:0] imm_j_sext = {{11{imm_j[20]}}, imm_j[20:0]};

  // opcodes - see section 19 of RiscV spec
  localparam [`OPCODE_SIZE:0] OpLoad    = 7'b00_000_11;
  localparam [`OPCODE_SIZE:0] OpStore   = 7'b01_000_11;
  localparam [`OPCODE_SIZE:0] OpBranch  = 7'b11_000_11;
  localparam [`OPCODE_SIZE:0] OpJalr    = 7'b11_001_11;
  localparam [`OPCODE_SIZE:0] OpMiscMem = 7'b00_011_11;
  localparam [`OPCODE_SIZE:0] OpJal     = 7'b11_011_11;

  localparam [`OPCODE_SIZE:0] OpRegImm  = 7'b00_100_11;
  localparam [`OPCODE_SIZE:0] OpRegReg  = 7'b01_100_11;
  localparam [`OPCODE_SIZE:0] OpEnviron = 7'b11_100_11;

  localparam [`OPCODE_SIZE:0] OpAuipc   = 7'b00_101_11;
  localparam [`OPCODE_SIZE:0] OpLui     = 7'b01_101_11;

  wire inst_lui    = (inst_opcode == OpLui    );
  wire inst_auipc  = (inst_opcode == OpAuipc  );
  wire inst_jal    = (inst_opcode == OpJal    );
  wire inst_jalr   = (inst_opcode == OpJalr   );

  wire inst_beq    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_bne    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b001);
  wire inst_blt    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b100);
  wire inst_bge    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b101);
  wire inst_bltu   = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b110);
  wire inst_bgeu   = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b111);

  wire inst_lb     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_lh     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b001);
  wire inst_lw     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b010);
  wire inst_lbu    = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b100);
  wire inst_lhu    = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b101);

  wire inst_sb     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_sh     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b001);
  wire inst_sw     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b010);

  wire inst_addi   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_slti   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b010);
  wire inst_sltiu  = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b011);
  wire inst_xori   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b100);
  wire inst_ori    = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b110);
  wire inst_andi   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b111);

  wire inst_slli   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b001) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_srli   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_srai   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'b0100000);

  wire inst_add    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_sub    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) & (inst_from_imem[31:25] == 7'b0100000);
  wire inst_sll    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b001) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_slt    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b010) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_sltu   = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b011) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_xor    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b100) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_srl    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_sra    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'b0100000);
  wire inst_or     = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b110) & (inst_from_imem[31:25] == 7'd0      );
  wire inst_and    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b111) & (inst_from_imem[31:25] == 7'd0      );

  wire inst_mul    = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b000    );
  wire inst_mulh   = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b001    );
  wire inst_mulhsu = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b010    );
  wire inst_mulhu  = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b011    );
  wire inst_div    = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b100    );
  wire inst_divu   = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b101    );
  wire inst_rem    = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b110    );
  wire inst_remu   = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1  ) & (inst_from_imem[14:12] == 3'b111    );

  wire inst_ecall  = (inst_opcode == OpEnviron) & (inst_from_imem[31:7] == 25'd0  );
  wire inst_fence  = (inst_opcode == OpMiscMem);
  
  // detect divide and stall
  wire is_div_op = (inst_opcode == OpRegReg) && (inst_funct7 == 7'b0000001) && (inst_funct3[2] == 1'b1);
  
  reg [2:0] div_counter;
  wire stall;

  // counter logic
  always @(posedge clk) begin
      if (rst) begin
          div_counter <= 0;
      end else begin
          if (is_div_op && div_counter < 7) 
              div_counter <= div_counter + 1;
          else if (!is_div_op) 
              div_counter <= 0;
      end
  end
  // stall 7 cycles
  assign stall = is_div_op && (div_counter < 7);
  
  // program counter
  reg [`REG_SIZE:0] pcNext, pcCurrent;
  always @(posedge clk) begin
    if (rst) begin
      pcCurrent <= 32'd0;
    end else if (!stall) begin
      pcCurrent <= pcNext;
    end
  end
  assign pc_to_imem = pcCurrent;

  // cycle/inst._from_imem counters
  reg [`REG_SIZE:0] cycles_current, num_inst_current;
  always @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
      num_inst_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
      if (!rst) begin
        num_inst_current <= num_inst_current + 1;
      end
    end
  end
  
  wire [`REG_SIZE:0] rs1_data;
  wire [`REG_SIZE:0] rs2_data;
  reg [`REG_SIZE:0] wb_data;
  reg rf_we;
    
  always @(*) begin
      if (inst_opcode == OpStore || inst_opcode == OpBranch || inst_ecall || stall)
          rf_we = 1'b0;
      else
          rf_we = 1'b1;
  end
  
  RegFile rf (
    .clk      (clk),
    .rst      (rst),
    .we       (rf_we),
    .rd       (inst_rd),
    .rd_data  (wb_data),
    .rs1      (inst_rs1),
    .rs2      (inst_rs2),
    .rs1_data (rs1_data),
    .rs2_data (rs2_data)
  );
  
  // divider pipeline
  wire [31:0] div_rem, div_quot;
  DividerUnsignedPipelined div (
      .clk(clk),
      .rst(rst),
      .i_dividend(rs1_data),
      .i_divisor(rs2_data),
      .o_remainder(div_rem),
      .o_quotient(div_quot)
  );
  // LED output
  assign led_debug = wb_data[3:0];
  
  // CLA logic
  wire [31:0] alu_op_b = (inst_opcode == OpRegImm || inst_opcode == OpLoad || inst_opcode == OpStore || inst_jalr) 
                       ? ((inst_opcode == OpStore) ? imm_s_sext : imm_i_sext) : rs2_data;
  
  wire is_sub = (inst_opcode == OpRegReg && inst_funct3 == 0 && inst_funct7 == 7'b0100000) || 
                (inst_opcode == OpBranch);

  wire [31:0] cla_sum;
  cla my_cla (
      .a(rs1_data), 
      .b(is_sub ? ~alu_op_b : alu_op_b), 
      .cin(is_sub ? 1'b1 : 1'b0), 
      .sum(cla_sum)
  );
  
  // ALU logic
  reg illegal_inst;
  reg [31:0] alu_result;

  always @(*) begin
    illegal_inst = 1'b0;
    alu_result = 0;

    if (is_div_op) begin
        if (inst_funct3 == 3'b100 || inst_funct3 == 3'b101) alu_result = div_quot;
        else alu_result = div_rem;
    end 
    else if (inst_add || inst_sub || inst_addi || inst_lb || inst_lh || inst_lw || inst_lbu || inst_lhu || inst_sb || inst_sh || inst_sw || inst_jalr) begin
         alu_result = cla_sum;
    end

    else if (inst_and  || inst_andi) alu_result = rs1_data & alu_op_b;
    else if (inst_or   || inst_ori)  alu_result = rs1_data | alu_op_b;
    else if (inst_xor  || inst_xori) alu_result = rs1_data ^ alu_op_b;
    else if (inst_sll  || inst_slli) alu_result = rs1_data << alu_op_b[4:0];
    else if (inst_srl  || inst_srli) alu_result = rs1_data >> alu_op_b[4:0];
    else if (inst_sra  || inst_srai) alu_result = $signed(rs1_data) >>> alu_op_b[4:0];
    else if (inst_slt  || inst_slti) alu_result = ($signed(rs1_data) < $signed(alu_op_b)) ? 1 : 0;
    else if (inst_sltu || inst_sltiu) alu_result = (rs1_data < alu_op_b) ? 1 : 0;
    
    else if (inst_lui)   alu_result = imm_u;
    else if (inst_auipc) alu_result = pcCurrent + imm_u;
    
    else if (!inst_beq && !inst_bne && !inst_blt && !inst_bge && !inst_bltu && !inst_bgeu && !inst_jal && !inst_ecall && !inst_fence) begin
        illegal_inst = 1'b1; // error if not found any comment
    end
  end

  // memory access
  always @(*) begin
      addr_to_dmem = alu_result;
      store_data_to_dmem = rs2_data;
      if (inst_sw && !stall)      store_we_to_dmem = 4'b1111;
      else if (inst_sh && !stall) store_we_to_dmem = 4'b0011;
      else if (inst_sb && !stall) store_we_to_dmem = 4'b0001;
      else                        store_we_to_dmem = 4'b0000;
  end

  //write back logic
  always @(*) begin
      if (inst_opcode == OpLoad) wb_data = load_data_from_dmem;
      else if (inst_jal || inst_jalr) wb_data = pcCurrent + 4;
      else wb_data = alu_result;
  end

  // next pc logic
  wire zero = (cla_sum == 0); // cla_sum at subtract mode is compare mode
  wire take_branch = (inst_beq && zero) || (inst_bne && !zero) || (inst_blt && ($signed(rs1_data) < $signed(rs2_data))) ||
                     (inst_bge && ($signed(rs1_data) >= $signed(rs2_data))) ||
                     (inst_bltu && (rs1_data < rs2_data)) || (inst_bgeu && (rs1_data >= rs2_data));

  always @(*) begin
      if (inst_jal) pcNext = pcCurrent + imm_j_sext;
      else if (inst_jalr) pcNext = (rs1_data + imm_i_sext) & ~32'b1; // JALR clear bit 0
      else if (take_branch) pcNext = pcCurrent + imm_b_sext;
      else pcNext = pcCurrent + 4;
  end
  always @(*) halt = inst_ecall;
  
endmodule

module MemorySingleCycle #(
    parameter NUM_WORDS = 512
) (
  input                    rst,                 // rst for both imem and dmem
  input                    clock_mem,           // clock for both imem and dmem
  input      [`REG_SIZE:0] pc_to_imem,          // must always be aligned to a 4B boundary
  output reg [`REG_SIZE:0] inst_from_imem,      // the value at memory location pc_to_imem
  input      [`REG_SIZE:0] addr_to_dmem,        // must always be aligned to a 4B boundary
  output reg [`REG_SIZE:0] load_data_from_dmem, // the value at memory location addr_to_dmem
  input      [`REG_SIZE:0] store_data_to_dmem,  // the value to be written to addr_to_dmem, controlled by store_we_to_dmem
  // Each bit determines whether to write the corresponding byte of store_data_to_dmem to memory location addr_to_dmem.
  // E.g., 4'b1111 will write 4 bytes. 4'b0001 will write only the least-significant byte.
  input      [        3:0] store_we_to_dmem
);

  // memory is arranged as an array of 4B words
  reg [`REG_SIZE:0] mem_array[0:NUM_WORDS-1];

  // preload instructions to mem_array
  initial begin
    $readmemh("D:/VIVADO_workspace/SOC/Completed_lab4/Lab4/Lab4.srcs/sources_1/new/mem_initial_contents.hex", mem_array);
  end

  localparam AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam AddrLsb = 2;

  always @(posedge clock_mem) begin
    inst_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
  end

  always @(negedge clock_mem) begin
    if (store_we_to_dmem[0]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
    end
    if (store_we_to_dmem[1]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
    end
    if (store_we_to_dmem[2]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
    end
    if (store_we_to_dmem[3]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
    end
    // dmem is "read-first": read returns value before the write
    load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
  end
endmodule

/*
This shows the relationship between clock_proc and clock_mem. The clock_mem is
phase-shifted 90° from clock_proc. You could think of one proc cycle being
broken down into 3 parts. During part 1 (which starts @posedge clock_proc)
the current PC is sent to the imem. In part 2 (starting @posedge clock_mem) we
read from imem. In part 3 (starting @negedge clock_mem) we read/write memory and
prepare register/PC updates, which occur at @posedge clock_proc.

        ____
 proc: |    |______
           ____
 mem:  ___|    |___
*/
module Processor (
    input  clock_proc,
    input  clock_mem,
    input  rst,
    output halt,
    
    output [3:0] led_bcd
);

  wire [`REG_SIZE:0] pc_to_imem, inst_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [        3:0] mem_data_we;

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
    .rst                 (rst),
    .clock_mem           (clock_mem),
    // imem is read-only
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    // dmem is read-write
    .addr_to_dmem        (mem_data_addr),
    .load_data_from_dmem (mem_data_loaded_value),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we)
  );

  DatapathMultiCycle datapath (
    .clk                 (clock_proc),
    .rst                 (rst),
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    .addr_to_dmem        (mem_data_addr),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we),
    .load_data_from_dmem (mem_data_loaded_value),
    .halt                (halt),
    
    .led_debug(led_bcd)
  );

endmodule
