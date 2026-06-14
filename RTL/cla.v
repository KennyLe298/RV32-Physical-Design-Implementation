`timescale 1ns / 1ps

// =============================================================================
// Carry-Lookahead Adder
// =============================================================================

module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

module gp4(input  wire [3:0] gin, pin,
           input  wire       cin,
           output wire       gout, pout,
           output wire [2:0] cout);

   wire [3:0] gen_prefix;
   assign gen_prefix[0] = gin[0];
   assign gen_prefix[1] = gin[1] | (pin[1] & gen_prefix[0]);
   assign gen_prefix[2] = gin[2] | (pin[2] & gen_prefix[1]);
   assign gen_prefix[3] = gin[3] | (pin[3] & gen_prefix[2]);

   assign gout = gen_prefix[3];
   assign pout = &pin;

   assign cout[0] = gin[0] | (pin[0] & cin);
   assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0])
                          | (pin[2] & pin[1] & pin[0] & cin);
endmodule

module gp8(input  wire [7:0] gin, pin,
           input  wire       cin,
           output wire       gout, pout,
           output wire [6:0] cout);

   wire [7:0] gen_prefix;
   assign gen_prefix[0] = gin[0];
   genvar i;
   generate
      for (i = 1; i < 8; i = i + 1) begin : GEN_PREFIX
         assign gen_prefix[i] = gin[i] | (pin[i] & gen_prefix[i-1]);
      end
   endgenerate

   assign gout = gen_prefix[7];
   assign pout = &pin;

   assign cout[0] = gin[0] | (pin[0] & cin);
   assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0])
                          | (pin[2] & pin[1] & pin[0] & cin);
   assign cout[3] = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1])
                          | (pin[3] & pin[2] & pin[1] & gin[0])
                          | (pin[3] & pin[2] & pin[1] & pin[0] & cin);
   assign cout[4] = gin[4] | (pin[4] & gin[3]) | (pin[4] & pin[3] & gin[2])
                          | (pin[4] & pin[3] & pin[2] & gin[1])
                          | (pin[4] & pin[3] & pin[2] & pin[1] & gin[0])
                          | (pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
   assign cout[5] = gin[5] | (pin[5] & gin[4]) | (pin[5] & pin[4] & gin[3])
                          | (pin[5] & pin[4] & pin[3] & gin[2])
                          | (pin[5] & pin[4] & pin[3] & pin[2] & gin[1])
                          | (pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0])
                          | (pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
   assign cout[6] = gin[6] | (pin[6] & gin[5]) | (pin[6] & pin[5] & gin[4])
                          | (pin[6] & pin[5] & pin[4] & gin[3])
                          | (pin[6] & pin[5] & pin[4] & pin[3] & gin[2])
                          | (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & gin[1])
                          | (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0])
                          | (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
endmodule


module cla
  (input  wire [31:0] a, b,
   input  wire        cin,
   output wire [31:0] sum);

   assign sum = a + b + {31'd0, cin};

endmodule
