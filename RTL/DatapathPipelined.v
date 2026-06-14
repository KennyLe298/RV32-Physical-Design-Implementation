`timescale 1ns / 1ns

`define REG_SIZE 31
`define INST_SIZE 31
`define OPCODE_SIZE 6
`define DIVIDER_STAGES 16   // matches optimized 16-stage divider


module RegFile (
  input              clk,
  input              rst,
  input              we,
  input       [4:0]  rd,
  input       [31:0] rd_data,
  input       [4:0]  rs1,
  output reg  [31:0] rs1_data,
  input       [4:0]  rs2,
  output reg  [31:0] rs2_data
);
  reg [31:0] regs [0:31];
  integer i;

  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
    end else if (we && (rd != 5'd0)) begin
      regs[rd] <= rd_data;
    end
  end

  // Internal write-through forwarding: catches the case where the WB-stage writes a register the ID-stage is reading in the same cycle.
  always @(*) begin
    rs1_data = (rs1 == 5'd0)                                  ? 32'd0 :
               (we && (rd == rs1) && (rd != 5'd0))            ? rd_data :
                                                                regs[rs1];
    rs2_data = (rs2 == 5'd0)                                  ? 32'd0 :
               (we && (rd == rs2) && (rd != 5'd0))            ? rd_data :
                                                                regs[rs2];
  end
endmodule


module DatapathPipelined (
  input                      clk,
  input                      rst,
  output      [`REG_SIZE:0]  pc_to_imem,
  input       [`INST_SIZE:0] inst_from_imem,
  output wire [`REG_SIZE:0]  addr_to_dmem,
  input       [`REG_SIZE:0]  load_data_from_dmem,
  output reg  [`REG_SIZE:0]  store_data_to_dmem,
  output reg  [3:0]          store_we_to_dmem,
  output reg                 halt,
  output reg  [`REG_SIZE:0]  trace_writeback_pc,
  output reg  [`INST_SIZE:0] trace_writeback_inst
);

  // ---- Opcodes ----
  localparam [6:0] OP_LOAD    = 7'b00_000_11;
  localparam [6:0] OP_STORE   = 7'b01_000_11;
  localparam [6:0] OP_BRANCH  = 7'b11_000_11;
  localparam [6:0] OP_JALR    = 7'b11_001_11;
  localparam [6:0] OP_JAL     = 7'b11_011_11;
  localparam [6:0] OP_REGIMM  = 7'b00_100_11;
  localparam [6:0] OP_REGREG  = 7'b01_100_11;
  localparam [6:0] OP_ENV     = 7'b11_100_11;
  localparam [6:0] OP_AUIPC   = 7'b00_101_11;
  localparam [6:0] OP_LUI     = 7'b01_101_11;

  // ---- ALU op encoding (decoded in ID, used in EX) ----
  localparam [3:0] ALU_ADD   = 4'd0;
  localparam [3:0] ALU_SUB   = 4'd1;
  localparam [3:0] ALU_SLL   = 4'd2;
  localparam [3:0] ALU_SLT   = 4'd3;
  localparam [3:0] ALU_SLTU  = 4'd4;
  localparam [3:0] ALU_XOR   = 4'd5;
  localparam [3:0] ALU_SRL   = 4'd6;
  localparam [3:0] ALU_SRA   = 4'd7;
  localparam [3:0] ALU_OR    = 4'd8;
  localparam [3:0] ALU_AND   = 4'd9;
  localparam [3:0] ALU_LUI   = 4'd10;
  localparam [3:0] ALU_AUIPC = 4'd11;
  localparam [3:0] ALU_PC4   = 4'd12;
  localparam [3:0] ALU_MUL   = 4'd13;
  localparam [3:0] ALU_DIV   = 4'd14;

  // ---- Pipeline registers ----
  reg [31:0] f_d_pc, f_d_inst;

  reg [31:0] d_x_pc, d_x_inst, d_x_rs1_data, d_x_rs2_data, d_x_imm;
  reg [4:0]  d_x_rs1_addr, d_x_rs2_addr, d_x_rd_addr;
  reg [2:0]  d_x_funct3;
  reg [6:0]  d_x_funct7;
  reg [3:0]  d_x_alu_op;
  reg        d_x_use_imm;
  reg        d_x_is_branch, d_x_is_jal, d_x_is_jalr;
  reg        d_x_is_load, d_x_is_store;
  reg        d_x_is_mul, d_x_is_div_op;
  reg        d_x_reg_we, d_x_halt;

  reg [31:0] x_m_pc, x_m_inst, x_m_alu_result, x_m_store_data;
  reg [4:0]  x_m_rd_addr, x_m_rs2_addr;
  reg        x_m_reg_we, x_m_is_load, x_m_is_store, x_m_halt;
  reg [2:0]  x_m_funct3;

  reg [31:0] m_w_pc, m_w_inst, m_w_alu_result, m_w_mem_data;
  reg [4:0]  m_w_rd_addr;
  reg        m_w_reg_we, m_w_is_load, m_w_halt;

  // ---- Hazard / stall wires ----
  wire stall_load_use, stall_div, stall_mul;
  wire branch_taken;
  wire [31:0] branch_target;

  // Combined stall: any condition that holds the front of the pipeline
  wire stall_front = stall_load_use | stall_div | stall_mul;
  // Stall that holds EX 
  wire stall_ex    = stall_div | stall_mul;

  // ===========================================================================
  // STAGE 1: FETCH
  // ===========================================================================
  reg  [31:0] pc_current;
  wire [31:0] pc_plus_4 = pc_current + 32'd4;
  wire [31:0] pc_next   = branch_taken ? branch_target : pc_plus_4;

  assign pc_to_imem = pc_current;

  always @(posedge clk) begin
    if (rst)              pc_current <= 32'd0;
    else if (!stall_front) pc_current <= pc_next;
  end

  // IF/ID: branch flushes; load-use / div / mul stalls hold contents
  always @(posedge clk) begin
    if (rst || branch_taken) begin
      f_d_pc   <= 32'd0;
      f_d_inst <= 32'd0;
    end else if (!stall_front) begin
      f_d_pc   <= pc_current;
      f_d_inst <= inst_from_imem;
    end
  end

  // ===========================================================================
  // STAGE 2: DECODE (with ALU-op pre-decode)
  // ===========================================================================
  wire [31:0] inst   = f_d_inst;
  wire [6:0]  opcode = inst[6:0];
  wire [4:0]  rd     = inst[11:7];
  wire [4:0]  rs1    = inst[19:15];
  wire [4:0]  rs2    = inst[24:20];
  wire [2:0]  funct3 = inst[14:12];
  wire [6:0]  funct7 = inst[31:25];

  wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
  wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_u = {inst[31:12], 12'b0};
  wire [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

  wire is_lui    = (opcode == OP_LUI);
  wire is_auipc  = (opcode == OP_AUIPC);
  wire is_jal    = (opcode == OP_JAL);
  wire is_jalr   = (opcode == OP_JALR);
  wire is_branch = (opcode == OP_BRANCH);
  wire is_load   = (opcode == OP_LOAD);
  wire is_store  = (opcode == OP_STORE);
  wire is_alu_i  = (opcode == OP_REGIMM);
  wire is_alu_r  = (opcode == OP_REGREG);
  wire is_ecall  = (opcode == OP_ENV) && (funct3 == 3'd0) && (inst[31:20] == 12'd0);

  wire is_mul_inst = is_alu_r && (funct7 == 7'h01) && (funct3[2] == 1'b0);
  wire is_div_inst = is_alu_r && (funct7 == 7'h01) && (funct3[2] == 1'b1);

  wire reg_we_dec  = is_lui | is_auipc | is_jal | is_jalr | is_load | is_alu_i | is_alu_r;
  wire use_imm_dec = is_alu_i | is_load | is_store | is_lui | is_auipc | is_jalr;

  reg [31:0] imm_sel;
  always @(*) begin
    case (1'b1)
      is_store           : imm_sel = imm_s;
      is_branch          : imm_sel = imm_b;
      (is_lui | is_auipc): imm_sel = imm_u;
      is_jal             : imm_sel = imm_j;
      default            : imm_sel = imm_i;
    endcase
  end

  reg [3:0] alu_op_dec;
  always @(*) begin
    alu_op_dec = ALU_ADD;
    if      (is_lui)            alu_op_dec = ALU_LUI;
    else if (is_auipc)          alu_op_dec = ALU_AUIPC;
    else if (is_jal | is_jalr)  alu_op_dec = ALU_PC4;
    else if (is_load | is_store) alu_op_dec = ALU_ADD;
    else if (is_alu_i | is_alu_r) begin
      if (is_mul_inst)      alu_op_dec = ALU_MUL;
      else if (is_div_inst) alu_op_dec = ALU_DIV;
      else case (funct3)
        3'b000: alu_op_dec = (is_alu_r && funct7 == 7'h20) ? ALU_SUB : ALU_ADD;
        3'b001: alu_op_dec = ALU_SLL;
        3'b010: alu_op_dec = ALU_SLT;
        3'b011: alu_op_dec = ALU_SLTU;
        3'b100: alu_op_dec = ALU_XOR;
        3'b101: alu_op_dec = (funct7 == 7'h20) ? ALU_SRA : ALU_SRL;
        3'b110: alu_op_dec = ALU_OR;
        3'b111: alu_op_dec = ALU_AND;
      endcase
    end
  end

  wire [31:0] wb_data, rs1_data_raw, rs2_data_raw;
  RegFile rf (
    .clk(clk), .rst(rst),
    .we(m_w_reg_we), .rd(m_w_rd_addr), .rd_data(wb_data),
    .rs1(rs1), .rs1_data(rs1_data_raw),
    .rs2(rs2), .rs2_data(rs2_data_raw)
  );

  // ID/EX register. Branch flushes; load-use injects a bubble
  always @(posedge clk) begin
    if (rst || branch_taken || (stall_load_use && !stall_ex)) begin
      d_x_pc        <= 32'd0;
      d_x_inst      <= 32'd0;
      d_x_rs1_data  <= 32'd0;
      d_x_rs2_data  <= 32'd0;
      d_x_imm       <= 32'd0;
      d_x_rs1_addr  <= 5'd0;
      d_x_rs2_addr  <= 5'd0;
      d_x_rd_addr   <= 5'd0;
      d_x_funct3    <= 3'd0;
      d_x_funct7    <= 7'd0;
      d_x_alu_op    <= ALU_ADD;
      d_x_use_imm   <= 1'b0;
      d_x_is_branch <= 1'b0;
      d_x_is_jal    <= 1'b0;
      d_x_is_jalr   <= 1'b0;
      d_x_is_load   <= 1'b0;
      d_x_is_store  <= 1'b0;
      d_x_is_mul    <= 1'b0;
      d_x_is_div_op <= 1'b0;
      d_x_reg_we    <= 1'b0;
      d_x_halt      <= 1'b0;
    end else if (!stall_ex) begin
      d_x_pc        <= f_d_pc;
      d_x_inst      <= f_d_inst;
      d_x_rs1_data  <= rs1_data_raw;
      d_x_rs2_data  <= rs2_data_raw;
      d_x_imm       <= imm_sel;
      d_x_rs1_addr  <= rs1;
      d_x_rs2_addr  <= rs2;
      d_x_rd_addr   <= rd;
      d_x_funct3    <= funct3;
      d_x_funct7    <= funct7;
      d_x_alu_op    <= alu_op_dec;
      d_x_use_imm   <= use_imm_dec;
      d_x_is_branch <= is_branch;
      d_x_is_jal    <= is_jal;
      d_x_is_jalr   <= is_jalr;
      d_x_is_load   <= is_load;
      d_x_is_store  <= is_store;
      d_x_is_mul    <= is_mul_inst;
      d_x_is_div_op <= is_div_inst;
      d_x_reg_we    <= reg_we_dec;
      d_x_halt      <= is_ecall;
    end
    // else: stall_ex => hold d_x_*
  end

  // ===========================================================================
  // STAGE 3: EXECUTE
  // ===========================================================================

  // Forwarding 
  wire fwd_a_xm = x_m_reg_we && (x_m_rd_addr != 5'd0) && (x_m_rd_addr == d_x_rs1_addr);
  wire fwd_a_mw = m_w_reg_we && (m_w_rd_addr != 5'd0) && (m_w_rd_addr == d_x_rs1_addr);
  wire fwd_b_xm = x_m_reg_we && (x_m_rd_addr != 5'd0) && (x_m_rd_addr == d_x_rs2_addr);
  wire fwd_b_mw = m_w_reg_we && (m_w_rd_addr != 5'd0) && (m_w_rd_addr == d_x_rs2_addr);

  wire [31:0] rs1_fwd = fwd_a_xm ? x_m_alu_result :
                        fwd_a_mw ? wb_data        : d_x_rs1_data;
  wire [31:0] rs2_fwd = fwd_b_xm ? x_m_alu_result :
                        fwd_b_mw ? wb_data        : d_x_rs2_data;

  wire [31:0] alu_a = rs1_fwd;
  wire [31:0] alu_b = d_x_use_imm ? d_x_imm : rs2_fwd;

  // Adder/Subtractor via cla 
  // SUB:  a - b  =  a + (~b) + 1
  wire [31:0] alu_add;
  wire [31:0] alu_sub;
  cla u_cla_add (.a(alu_a),  .b(alu_b),  .cin(1'b0), .sum(alu_add));
  cla u_cla_sub (.a(alu_a),  .b(~alu_b), .cin(1'b1), .sum(alu_sub));

  // Comparators (used by SLT/SLTU and branches)
  wire signed_lt   = $signed(alu_a) < $signed(alu_b);
  wire unsigned_lt = alu_a < alu_b;
  wire equal       = (alu_a == alu_b);

  // Shifters 
  wire [31:0] sll_res = alu_a << alu_b[4:0];
  wire [31:0] srl_res = alu_a >> alu_b[4:0];
  wire [31:0] sra_res = $signed(alu_a) >>> alu_b[4:0];

  (* use_dsp = "yes" *) reg [31:0] mul_a_r;
  (* use_dsp = "yes" *) reg [31:0] mul_b_r;
  (* use_dsp = "yes" *) reg [63:0] mul_ss_r, mul_su_r, mul_uu_r;
  always @(posedge clk) begin
    mul_a_r  <= alu_a;
    mul_b_r  <= alu_b;
    mul_ss_r <= $signed(mul_a_r) * $signed(mul_b_r);
    mul_su_r <= $signed(mul_a_r) * $signed({1'b0, mul_b_r});
    mul_uu_r <= mul_a_r          * mul_b_r;
  end

  reg [1:0] mul_count;
  always @(posedge clk) begin
    if (rst)                                  mul_count <= 2'd0;
    else if (d_x_is_mul && (mul_count != 2'd2)) mul_count <= mul_count + 2'd1;
    else                                      mul_count <= 2'd0;
  end
  assign stall_mul = d_x_is_mul && (mul_count != 2'd2);

  reg [31:0] mul_result_sel;
  always @(*) begin
    case (d_x_funct3)
      3'b000:  mul_result_sel = mul_ss_r[31:0];   // MUL
      3'b001:  mul_result_sel = mul_ss_r[63:32];  // MULH
      3'b010:  mul_result_sel = mul_su_r[63:32];  // MULHSU
      3'b011:  mul_result_sel = mul_uu_r[63:32];  // MULHU
      default: mul_result_sel = 32'd0;
    endcase
  end

  // Pipelined Divider (16 stages, 2 iters/stage)
  localparam DIV_LAT = `DIVIDER_STAGES;
  reg [$clog2(DIV_LAT):0] div_cycles;

  wire is_div  = d_x_is_div_op && (d_x_funct3 == 3'b100);
  wire is_divu = d_x_is_div_op && (d_x_funct3 == 3'b101);
  wire is_rem  = d_x_is_div_op && (d_x_funct3 == 3'b110);
  wire is_remu = d_x_is_div_op && (d_x_funct3 == 3'b111);

  wire [31:0] div_in_a = (is_div || is_rem) ? (alu_a[31] ? -alu_a : alu_a) : alu_a;
  wire [31:0] div_in_b = (is_div || is_rem) ? (alu_b[31] ? -alu_b : alu_b) : alu_b;

  wire [31:0] div_quo_u, div_rem_u;

  always @(posedge clk) begin
    if (rst)                                              div_cycles <= 0;
    else if (d_x_is_div_op && (div_cycles < DIV_LAT - 1)) div_cycles <= div_cycles + 1;
    else                                                  div_cycles <= 0;
  end

  assign stall_div = d_x_is_div_op && (div_cycles < DIV_LAT - 1);

  DividerUnsignedPipelined div_u (
    .clk(clk), .rst(rst), .stall(stall_div),
    .i_dividend(div_in_a), .i_divisor(div_in_b),
    .o_remainder(div_rem_u), .o_quotient(div_quo_u)
  );

  wire [31:0] div_quo_s = (is_div && (alu_a[31] ^ alu_b[31])) ? -div_quo_u : div_quo_u;
  wire [31:0] div_rem_s = (is_rem &&  alu_a[31])              ? -div_rem_u : div_rem_u;

  reg [31:0] div_result_sel;
  always @(*) begin
    case (d_x_funct3)
      3'b100:  div_result_sel = div_quo_s; // DIV
      3'b101:  div_result_sel = div_quo_u; // DIVU
      3'b110:  div_result_sel = div_rem_s; // REM
      3'b111:  div_result_sel = div_rem_u; // REMU
      default: div_result_sel = 32'd0;
    endcase
  end

  // Final ALU result mux (single-level case) ----
  reg [31:0] alu_result;
  always @(*) begin
    case (d_x_alu_op)
      ALU_ADD  : alu_result = alu_add;
      ALU_SUB  : alu_result = alu_sub;
      ALU_SLL  : alu_result = sll_res;
      ALU_SLT  : alu_result = {31'd0, signed_lt};
      ALU_SLTU : alu_result = {31'd0, unsigned_lt};
      ALU_XOR  : alu_result = alu_a ^ alu_b;
      ALU_SRL  : alu_result = srl_res;
      ALU_SRA  : alu_result = sra_res;
      ALU_OR   : alu_result = alu_a | alu_b;
      ALU_AND  : alu_result = alu_a & alu_b;
      ALU_LUI  : alu_result = d_x_imm;
      ALU_AUIPC: alu_result = d_x_pc + d_x_imm;
      ALU_PC4  : alu_result = d_x_pc + 32'd4;
      ALU_MUL  : alu_result = mul_result_sel;
      ALU_DIV  : alu_result = div_result_sel;
      default  : alu_result = 32'd0;
    endcase
  end

  // ---- Branch resolution ----
  reg take_branch;
  always @(*) begin
    take_branch = 1'b0;
    if (d_x_is_branch) begin
      case (d_x_funct3)
        3'b000: take_branch =  equal;
        3'b001: take_branch = ~equal;
        3'b100: take_branch =  signed_lt;
        3'b101: take_branch = ~signed_lt;
        3'b110: take_branch =  unsigned_lt;
        3'b111: take_branch = ~unsigned_lt;
        default:take_branch = 1'b0;
      endcase
    end
  end

  // JALR
  wire [31:0] jalr_target  = (alu_a + d_x_imm) & ~32'd1;
  wire [31:0] brnch_target = d_x_pc + d_x_imm;
  assign branch_target = d_x_is_jalr ? jalr_target : brnch_target;
  assign branch_taken  = (take_branch | d_x_is_jal | d_x_is_jalr) & ~stall_ex;

  // EX/MEM register
  always @(posedge clk) begin
    if (rst) begin
      x_m_pc         <= 32'd0;
      x_m_inst       <= 32'd0;
      x_m_alu_result <= 32'd0;
      x_m_store_data <= 32'd0;
      x_m_rd_addr    <= 5'd0;
      x_m_rs2_addr   <= 5'd0;
      x_m_reg_we     <= 1'b0;
      x_m_is_load    <= 1'b0;
      x_m_is_store   <= 1'b0;
      x_m_halt       <= 1'b0;
      x_m_funct3     <= 3'd0;
    end else if (!stall_ex) begin
      x_m_pc         <= d_x_pc;
      x_m_inst       <= d_x_inst;
      x_m_alu_result <= alu_result;
      x_m_store_data <= rs2_fwd;
      x_m_rd_addr    <= d_x_rd_addr;
      x_m_rs2_addr   <= d_x_rs2_addr;
      x_m_reg_we     <= d_x_reg_we;
      x_m_is_load    <= d_x_is_load;
      x_m_is_store   <= d_x_is_store;
      x_m_halt       <= d_x_halt;
      x_m_funct3     <= d_x_funct3;
    end else begin

      x_m_pc       <= 32'd0;
      x_m_inst     <= 32'd0;
      x_m_reg_we   <= 1'b0;
      x_m_is_load  <= 1'b0;
      x_m_is_store <= 1'b0;
      x_m_halt     <= 1'b0;
    end
  end

  // ===========================================================================
  // STAGE 4: MEMORY
  // ===========================================================================
  assign addr_to_dmem = x_m_alu_result;

  // Store-data forwarding (in case the value being stored was just produced by the instruction now in WB).
  wire [31:0] store_data_fwd =
      (m_w_reg_we && (m_w_rd_addr != 5'd0) && (m_w_rd_addr == x_m_rs2_addr))
      ? wb_data : x_m_store_data;

  always @(*) begin
    store_we_to_dmem   = 4'b0000;
    store_data_to_dmem = 32'd0;
    if (x_m_is_store) begin
      case (x_m_funct3)
        3'b000: begin // SB
          store_we_to_dmem   = 4'b0001 << x_m_alu_result[1:0];
          store_data_to_dmem = store_data_fwd << (x_m_alu_result[1:0] * 8);
        end
        3'b001: begin // SH
          store_we_to_dmem   = 4'b0011 << (x_m_alu_result[1] * 2);
          store_data_to_dmem = store_data_fwd << (x_m_alu_result[1] * 16);
        end
        3'b010: begin // SW
          store_we_to_dmem   = 4'b1111;
          store_data_to_dmem = store_data_fwd;
        end
        default: ;
      endcase
    end
  end

  // Load-data alignment / sign-extension
  reg [31:0] loaded_val;
  always @(*) begin
    loaded_val = load_data_from_dmem;
    case (x_m_funct3)
      3'b000: case (x_m_alu_result[1:0]) // LB
        2'd0: loaded_val = {{24{load_data_from_dmem[7] }}, load_data_from_dmem[7:0]};
        2'd1: loaded_val = {{24{load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
        2'd2: loaded_val = {{24{load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
        2'd3: loaded_val = {{24{load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
      endcase
      3'b001: loaded_val = x_m_alu_result[1]
                ? {{16{load_data_from_dmem[31]}}, load_data_from_dmem[31:16]}
                : {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
      3'b010: loaded_val = load_data_from_dmem;
      3'b100: case (x_m_alu_result[1:0]) // LBU
        2'd0: loaded_val = {24'd0, load_data_from_dmem[7:0]};
        2'd1: loaded_val = {24'd0, load_data_from_dmem[15:8]};
        2'd2: loaded_val = {24'd0, load_data_from_dmem[23:16]};
        2'd3: loaded_val = {24'd0, load_data_from_dmem[31:24]};
      endcase
      3'b101: loaded_val = x_m_alu_result[1]
                ? {16'd0, load_data_from_dmem[31:16]}
                : {16'd0, load_data_from_dmem[15:0]};
      default: loaded_val = load_data_from_dmem;
    endcase
  end

  // MEM/WB register
  always @(posedge clk) begin
    if (rst) begin
      m_w_pc <= 0; m_w_inst <= 0;
      m_w_alu_result <= 0; m_w_mem_data <= 0;
      m_w_rd_addr <= 0;
      m_w_reg_we <= 0; m_w_is_load <= 0; m_w_halt <= 0;
    end else begin
      m_w_pc         <= x_m_pc;
      m_w_inst       <= x_m_inst;
      m_w_alu_result <= x_m_alu_result;
      m_w_mem_data   <= loaded_val;
      m_w_rd_addr    <= x_m_rd_addr;
      m_w_reg_we     <= x_m_reg_we;
      m_w_is_load    <= x_m_is_load;
      m_w_halt       <= x_m_halt;
    end
  end

  // ===========================================================================
  // STAGE 5: WRITEBACK + TRACE
  // ===========================================================================
  assign wb_data = m_w_is_load ? m_w_mem_data : m_w_alu_result;

  always @(posedge clk) begin
    if (rst) halt <= 1'b0;
    else     halt <= m_w_halt;
  end

  always @(posedge clk) begin
    if (rst) begin
      trace_writeback_pc   <= 32'd0;
      trace_writeback_inst <= 32'd0;
    end else begin
      trace_writeback_pc   <= m_w_pc;
      trace_writeback_inst <= m_w_inst;
    end
  end

  // ===========================================================================
  // HAZARD DETECTION
  // ===========================================================================
  assign stall_load_use = d_x_is_load && (d_x_rd_addr != 5'd0) &&
                          ((d_x_rd_addr == rs1) || (d_x_rd_addr == rs2));

endmodule


// =============================================================================
// Memory & Top-level 
// =============================================================================
module MemorySingleCycle #(
    parameter NUM_WORDS = 512
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire [31:0]              pc_to_imem,
    output reg  [31:0]              inst_from_imem,
    input  wire [31:0]              addr_to_dmem,
    input  wire [31:0]              store_data_to_dmem,
    input  wire [3:0]               store_we_to_dmem,
    output reg  [31:0]              load_data_from_dmem
);
    reg [31:0] mem_array [0:NUM_WORDS-1];

    initial begin
        $readmemh("mem_initial_contents.hex", mem_array);
    end

    localparam AddrLSB = 2;
    localparam AddrMSB = $clog2(NUM_WORDS) + 1;

    wire [AddrMSB-AddrLSB:0] imem_addr = pc_to_imem[AddrMSB:AddrLSB];
    wire [AddrMSB-AddrLSB:0] dmem_addr = addr_to_dmem[AddrMSB:AddrLSB];

    always @(posedge clk) begin
        inst_from_imem <= mem_array[imem_addr];
    end

    always @(posedge clk) begin
        if (store_we_to_dmem[0]) mem_array[dmem_addr][7:0]   <= store_data_to_dmem[7:0];
        if (store_we_to_dmem[1]) mem_array[dmem_addr][15:8]  <= store_data_to_dmem[15:8];
        if (store_we_to_dmem[2]) mem_array[dmem_addr][23:16] <= store_data_to_dmem[23:16];
        if (store_we_to_dmem[3]) mem_array[dmem_addr][31:24] <= store_data_to_dmem[31:24];
        load_data_from_dmem <= mem_array[dmem_addr];
    end
endmodule


module Processor (
    input clk, input rst, output halt,
    output [`REG_SIZE:0] trace_writeback_pc,
    output [`INST_SIZE:0] trace_writeback_inst
);
    wire [`INST_SIZE:0] inst_from_imem;
    wire [`REG_SIZE:0]  pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
    wire [3:0]          mem_data_we;

    MemorySingleCycle #(.NUM_WORDS(8192)) memory (
        .rst(rst), .clk(clk),
        .pc_to_imem(pc_to_imem), .inst_from_imem(inst_from_imem),
        .addr_to_dmem(mem_data_addr), .load_data_from_dmem(mem_data_loaded_value),
        .store_data_to_dmem(mem_data_to_write), .store_we_to_dmem(mem_data_we)
    );

    DatapathPipelined datapath (
        .clk(clk), .rst(rst),
        .pc_to_imem(pc_to_imem), .inst_from_imem(inst_from_imem),
        .addr_to_dmem(mem_data_addr), .store_data_to_dmem(mem_data_to_write),
        .store_we_to_dmem(mem_data_we), .load_data_from_dmem(mem_data_loaded_value),
        .halt(halt),
        .trace_writeback_pc(trace_writeback_pc),
        .trace_writeback_inst(trace_writeback_inst)
    );
endmodule