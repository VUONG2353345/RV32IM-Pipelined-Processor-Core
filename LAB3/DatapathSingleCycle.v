`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

// Don't forget your previous ALUs
//`include "divider_unsigned.v"
//`include "cla.v"

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

    // --- PHẦN BẠN CẦN LÀM: REGISTER FILE ---

    // 1. Logic đọc (Read Ports) - Bất đồng bộ
    // Nếu rs1 hoặc rs2 là 0 thì luôn trả về 0 (Hardwired x0 to 0)
    always @(*) begin
        rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
        rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];
    end

    // 2. Logic ghi (Write Port) - Đồng bộ theo xung clock
    always @(posedge clk) begin
        if (rst) begin
            // Reset toàn bộ thanh ghi về 0
            for (i = 0; i < NumRegs; i = i + 1) begin
                regs[i] <= 32'd0;
            end
        end else if (we && (rd != 5'd0)) begin
            // Chỉ ghi khi we=1 và không ghi vào thanh ghi số 0
            regs[rd] <= rd_data;
        end
    end

endmodule

module DatapathSingleCycle (
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
    
    // THÊM: Output 4 bit cho LED Extension Board để debug CLA
    output wire [3:0]        led_debug
);
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

    // program counter
    reg [`REG_SIZE:0] pcNext, pcCurrent;
    always @(posedge clk) begin
        if (rst) begin
            pcCurrent <= 32'd0;
        end else begin
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

    // --- PHẦN BẠN CẦN LÀM: LOGIC DATAPATH & CONTROL UNIT ---

    // 1. Tín hiệu kết nối RegFile
    reg reg_we;
    wire [`REG_SIZE:0] rs1_data;
    wire [`REG_SIZE:0] rs2_data;
    reg [`REG_SIZE:0] wb_data; // Dữ liệu ghi ngược vào thanh ghi

    RegFile rf (
        .clk      (clk),
        .rst      (rst),
        .we       (reg_we),
        .rd       (inst_rd),
        .rd_data  (wb_data),
        .rs1      (inst_rs1),
        .rs2      (inst_rs2),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    reg  [`REG_SIZE:0] alu_op_a;
    reg  [`REG_SIZE:0] alu_op_b;
    reg                alu_cin;       // Carry in (dùng cho phép trừ)
    reg                alu_inv_b;     // Đảo bit B (dùng cho phép trừ)
    wire [`REG_SIZE:0] alu_op_b_final; 
    wire [`REG_SIZE:0] cla_sum;

    assign alu_op_b_final = alu_inv_b ? ~alu_op_b : alu_op_b;

    // Instantiate CLA (bài lab 2)
    cla my_cla (
        .a   (alu_op_a),
        .b   (alu_op_b_final),
        .cin (alu_cin),
        .sum (cla_sum)
    );

    wire [`REG_SIZE:0] div_quo;
    wire [`REG_SIZE:0] div_rem;

    // Instantiate Divider Unsigned (bài lab 2)
    divider_unsigned my_div (
        .i_dividend (rs1_data),
        .i_divisor  (rs2_data),
        .o_quotient (div_quo),
        .o_remainder(div_rem)
    );
    
    // 4. LED Output: Lấy 4 bit thấp nhất của kết quả (wb_data) đưa ra Extension Board
    assign led_debug = wb_data[3:0]; 

    reg illegal_inst;

    // 5. Control Unit: Giải mã và thực thi lệnh
    always @(*) begin
        // --- GIÁ TRỊ MẶC ĐỊNH ---
        illegal_inst = 1'b0;
        halt = 1'b0;
        
        // PC mặc định tăng 4
        pcNext = pcCurrent + 32'd4;
        
        // RegFile mặc định
        reg_we  = 1'b0;
        wb_data = 32'd0;

        // Memory mặc định
        store_we_to_dmem = 4'b0000;
        addr_to_dmem     = 32'd0;
        store_data_to_dmem = 32'd0;

        // ALU/CLA mặc định
        alu_op_a  = rs1_data;
        alu_op_b  = rs2_data;
        alu_cin   = 1'b0;
        alu_inv_b = 1'b0;

        case (inst_opcode)
            OpLui: begin 
                reg_we  = 1'b1;
                // Lấy 20 bit cao từ lệnh, shift vào 12 bit thấp
                wb_data = {inst_from_imem[31:12], 12'b0}; 
            end

            OpAuipc: begin
                reg_we   = 1'b1;
                alu_op_a = pcCurrent;
                alu_op_b = {inst_from_imem[31:12], 12'b0};
                wb_data  = cla_sum; // PC + U-imm
            end

            OpJal: begin
                reg_we  = 1'b1;
                wb_data = pcCurrent + 32'd4; // Lưu PC+4 vào rd
                alu_op_a = pcCurrent;
                alu_op_b = imm_j_sext;
                pcNext   = cla_sum; // PC + J-imm
            end

            OpJalr: begin
                reg_we   = 1'b1;
                wb_data  = pcCurrent + 32'd4;
                alu_op_a = rs1_data;
                alu_op_b = imm_i_sext;
                pcNext   = cla_sum & ~32'd1; // (rs1 + I-imm) & ~1
            end

            OpBranch: begin
                alu_op_a  = rs1_data;
                alu_op_b  = rs2_data;
                alu_inv_b = 1'b1; // Đảo B
                alu_cin   = 1'b1; // +1 => Thực hiện phép trừ rs1 - rs2
                
                // cla_sum = A - B
                case (inst_funct3)
                    3'b000: if (cla_sum == 0) pcNext = pcCurrent + imm_b_sext; // BEQ
                    3'b001: if (cla_sum != 0) pcNext = pcCurrent + imm_b_sext; // BNE
                    // Các phép so sánh sử dụng signed/unsigned logic
                    3'b100: if ($signed(rs1_data) < $signed(rs2_data)) pcNext = pcCurrent + imm_b_sext; // BLT
                    3'b101: if ($signed(rs1_data) >= $signed(rs2_data)) pcNext = pcCurrent + imm_b_sext; // BGE
                    3'b110: if (rs1_data < rs2_data) pcNext = pcCurrent + imm_b_sext; // BLTU
                    3'b111: if (rs1_data >= rs2_data) pcNext = pcCurrent + imm_b_sext; // BGEU
                endcase
            end

            OpLoad: begin
                alu_op_a = rs1_data;
                alu_op_b = imm_i_sext;
                addr_to_dmem = cla_sum; // Tính địa chỉ nhớ
                reg_we = 1'b1;
                
                // Xử lý dữ liệu đọc về (Load Extension)
                case (inst_funct3)
                    3'b000: wb_data = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};   // LB
                    3'b001: wb_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]}; // LH
                    3'b010: wb_data = load_data_from_dmem;                                        // LW
                    3'b100: wb_data = {24'b0, load_data_from_dmem[7:0]};                          // LBU
                    3'b101: wb_data = {16'b0, load_data_from_dmem[15:0]};                         // LHU
                endcase
            end

            OpStore: begin
                alu_op_a = rs1_data;
                alu_op_b = imm_s_sext;
                addr_to_dmem = cla_sum; // Tính địa chỉ nhớ
                
                // Căn chỉnh dữ liệu ghi (Store Alignment)
                case (inst_funct3)
                    3'b000: begin // SB
                        store_data_to_dmem = rs2_data << (addr_to_dmem[1:0] * 8);
                        store_we_to_dmem   = 4'b0001 << addr_to_dmem[1:0];
                    end
                    3'b001: begin // SH
                        store_data_to_dmem = rs2_data << (addr_to_dmem[1] * 16);
                        store_we_to_dmem   = 4'b0011 << (addr_to_dmem[1] * 2);
                    end
                    3'b010: begin // SW
                        store_data_to_dmem = rs2_data;
                        store_we_to_dmem   = 4'b1111;
                    end
                endcase
            end

            OpRegImm: begin
                reg_we = 1'b1;
                alu_op_a = rs1_data;
                alu_op_b = imm_i_sext;
                
                case (inst_funct3)
                    3'b000: wb_data = cla_sum; // ADDI
                    3'b010: wb_data = ($signed(rs1_data) < $signed(imm_i_sext)) ? 32'd1 : 32'd0; // SLTI
                    3'b011: wb_data = (rs1_data < imm_i_sext) ? 32'd1 : 32'd0; // SLTIU
                    3'b100: wb_data = rs1_data ^ imm_i_sext; // XORI
                    3'b110: wb_data = rs1_data | imm_i_sext; // ORI
                    3'b111: wb_data = rs1_data & imm_i_sext; // ANDI
                    3'b001: wb_data = rs1_data << imm_shamt; // SLLI
                    3'b101: begin
                        if (inst_funct7[5]) // SRAI
                            wb_data = $signed(rs1_data) >>> imm_shamt;
                        else // SRLI
                            wb_data = rs1_data >> imm_shamt;
                    end
                endcase
            end

            OpRegReg: begin
                reg_we = 1'b1;
                
                if (inst_funct7 == 7'd1) begin // M-Extension (Nhân/Chia)
                     case (inst_funct3)
                        3'b000: wb_data = rs1_data * rs2_data; // MUL
                        
                        // DIV (Signed): Xử lý chia cho 0 và Tràn số (Overflow)
                        3'b100: begin
                            if (rs2_data == 32'd0)
                                wb_data = 32'hFFFFFFFF; // Chia cho 0 trả về -1
                            else if (rs1_data == 32'h80000000 && rs2_data == 32'hFFFFFFFF)
                                wb_data = 32'h80000000; // Tràn số (-2^31 / -1) trả về chính nó
                            else
                                wb_data = $signed(rs1_data) / $signed(rs2_data);
                        end

                        3'b101: wb_data = div_quo; // DIVU (Dùng module HW Divider)

                        // REM (Signed): Xử lý chia cho 0 và Tràn số
                        3'b110: begin
                            if (rs2_data == 32'd0)
                                wb_data = rs1_data; // Chia cho 0 trả về số bị chia
                            else if (rs1_data == 32'h80000000 && rs2_data == 32'hFFFFFFFF)
                                wb_data = 32'd0;    // Tràn số (-2^31 / -1) số dư là 0
                            else
                                wb_data = $signed(rs1_data) % $signed(rs2_data);
                        end

                        3'b111: wb_data = div_rem; // REMU (Dùng module HW Divider)
                        
                        default: wb_data = 32'd0;
                     endcase
                end else begin // Base Integer (Cộng/Trừ/Logic cơ bản)
                    case (inst_funct3)
                        3'b000: begin // ADD / SUB
                            if (inst_funct7[5]) begin // SUB
                                alu_inv_b = 1'b1;
                                alu_cin   = 1'b1;
                                wb_data   = cla_sum;
                            end else begin // ADD
                                wb_data   = cla_sum;
                            end
                        end
                        3'b001: wb_data = rs1_data << rs2_data[4:0]; // SLL
                        3'b010: wb_data = ($signed(rs1_data) < $signed(rs2_data)) ? 32'd1 : 32'd0; // SLT
                        3'b011: wb_data = (rs1_data < rs2_data) ? 32'd1 : 32'd0; // SLTU
                        3'b100: wb_data = rs1_data ^ rs2_data; // XOR
                        3'b101: begin
                            if (inst_funct7[5]) // SRA
                                wb_data = $signed(rs1_data) >>> rs2_data[4:0];
                            else // SRL
                                wb_data = rs1_data >> rs2_data[4:0];
                        end
                        3'b110: wb_data = rs1_data | rs2_data; // OR
                        3'b111: wb_data = rs1_data & rs2_data; // AND
                    endcase
                end
            end

            OpEnviron: begin
                if (inst_ecall) halt = 1'b1; // Lệnh ecall dừng vi xử lý
            end

            default: begin
                illegal_inst = 1'b1;
            end
        endcase
    end

endmodule

/* A memory module that supports 1-cycle reads and writes, with one read-only port
 * and one read+write port.
 */
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
        $readmemh("mem_initial_contents.hex", mem_array);
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
phase-shifted 90° from clock_proc.
You could think of one proc cycle being
broken down into 3 parts.
During part 1 (which starts @posedge clock_proc)
the current PC is sent to the imem.
In part 2 (starting @posedge clock_mem) we
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
    // THÊM: Output ra LED cho system wrapper
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

    DatapathSingleCycle datapath (
        .clk                 (clock_proc),
        .rst                 (rst),
        .pc_to_imem          (pc_to_imem),
        .inst_from_imem      (inst_from_imem),
        .addr_to_dmem        (mem_data_addr),
        .store_data_to_dmem  (mem_data_to_write),
        .store_we_to_dmem    (mem_data_we),
        .load_data_from_dmem (mem_data_loaded_value),
        .halt                (halt),
        // Nối dây LED
        .led_debug           (led_bcd)
    );

endmodule