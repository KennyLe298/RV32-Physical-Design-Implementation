`timescale 1ns / 1ns


module DividerUnsignedPipelined (
    input             clk, rst, stall,   
    input      [31:0] i_dividend,
    input      [31:0] i_divisor,
    output reg [31:0] o_remainder,
    output reg [31:0] o_quotient
);
    localparam NUM_STAGES = 16;

    //INPUT REGISTER
    (* shreg_extract = "no" *) reg [31:0] dividend_r;
    (* shreg_extract = "no" *) reg [31:0] divisor_r;
    always @(posedge clk) begin
        if (rst) begin
            dividend_r <= 32'd0;
            divisor_r  <= 32'd0;
        end else begin
            dividend_r <= i_dividend;
            divisor_r  <= i_divisor;
        end
    end

    (* shreg_extract = "no" *) reg [31:0] stage_dividend  [0:NUM_STAGES-1];
    (* shreg_extract = "no" *) reg [31:0] stage_divisor   [0:NUM_STAGES-1];
    (* shreg_extract = "no" *) reg [31:0] stage_remainder [0:NUM_STAGES-1];
    (* shreg_extract = "no" *) reg [31:0] stage_quotient  [0:NUM_STAGES-1];

    // STAGE 0
    wire [31:0] s0_rem_0, s0_div_0, s0_quo_0;
    wire [31:0] s0_rem_1, s0_div_1, s0_quo_1;

    divu_1iter s0_iter0 (
        .remainder_in(32'b0),    .dividend_in(dividend_r), .quotient_in(32'b0),
        .divisor(divisor_r),
        .remainder_out(s0_rem_0), .dividend_out(s0_div_0), .quotient_out(s0_quo_0)
    );
    divu_1iter s0_iter1 (
        .remainder_in(s0_rem_0), .dividend_in(s0_div_0),  .quotient_in(s0_quo_0),
        .divisor(divisor_r),
        .remainder_out(s0_rem_1), .dividend_out(s0_div_1), .quotient_out(s0_quo_1)
    );

    always @(posedge clk) begin
        if (rst) begin
            stage_dividend[0]  <= 32'd0;
            stage_divisor[0]   <= 32'd0;
            stage_remainder[0] <= 32'd0;
            stage_quotient[0]  <= 32'd0;
        end else begin
            stage_dividend[0]  <= s0_div_1;
            stage_remainder[0] <= s0_rem_1;
            stage_quotient[0]  <= s0_quo_1;
            stage_divisor[0]   <= divisor_r;
        end
    end

    //  STAGES 1
    genvar i;
    generate
        for (i = 1; i < NUM_STAGES; i = i + 1) begin : pipe_stages
            wire [31:0] rem_0, div_0, quo_0;
            wire [31:0] rem_1, div_1, quo_1;

            wire [31:0] prev_dividend  = stage_dividend [i-1];
            wire [31:0] prev_divisor   = stage_divisor  [i-1];
            wire [31:0] prev_remainder = stage_remainder[i-1];
            wire [31:0] prev_quotient  = stage_quotient [i-1];

            divu_1iter iter0 (
                .remainder_in(prev_remainder), .dividend_in(prev_dividend),
                .quotient_in(prev_quotient),   .divisor(prev_divisor),
                .remainder_out(rem_0), .dividend_out(div_0), .quotient_out(quo_0)
            );
            divu_1iter iter1 (
                .remainder_in(rem_0), .dividend_in(div_0),  .quotient_in(quo_0),
                .divisor(prev_divisor),
                .remainder_out(rem_1), .dividend_out(div_1), .quotient_out(quo_1)
            );

            always @(posedge clk) begin
                if (rst) begin
                    stage_dividend [i] <= 32'd0;
                    stage_divisor  [i] <= 32'd0;
                    stage_remainder[i] <= 32'd0;
                    stage_quotient [i] <= 32'd0;
                end else begin
                    stage_dividend [i] <= div_1;
                    stage_remainder[i] <= rem_1;
                    stage_quotient [i] <= quo_1;
                    stage_divisor  [i] <= prev_divisor;
                end
            end
        end
    endgenerate

    always @(*) begin
        o_remainder = stage_remainder[NUM_STAGES-1];
        o_quotient  = stage_quotient [NUM_STAGES-1];
    end
    wire _unused_stall = stall;
endmodule