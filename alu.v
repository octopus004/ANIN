
// Podrzava: ADD, SUB, AND, OR, NOT, CMP (SUB bez upisa rezultata)
// Racuna PSW flegove: Z, N, C, V

`include "isa_defines.vh"

module alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [4:0]  opcode,
    output reg  [15:0] result,
    output reg          flag_z,
    output reg          flag_n,
    output reg          flag_c,
    output reg          flag_v
);

    reg [16:0] tmp; // sirok za carry

    always @(*) begin
        tmp    = 17'd0;
        result = 16'd0;
        flag_c = 1'b0;
        flag_v = 1'b0;

        case (opcode)
            `OP_ADD: begin
                tmp    = {1'b0, a} + {1'b0, b};
                result = tmp[15:0];
                flag_c = tmp[16];
                flag_v = (a[15] == b[15]) && (result[15] != a[15]);
            end
            `OP_SUB, `OP_CMP: begin
                tmp    = {1'b0, a} - {1'b0, b};
                result = tmp[15:0];
                flag_c = tmp[16]; // borrow
                flag_v = (a[15] != b[15]) && (result[15] != a[15]);
            end
            `OP_AND: result = a & b;
            `OP_OR:  result = a | b;
            `OP_NOT: result = ~a;
            default: result = a;
        endcase

        flag_z = (result == 16'h0000);
        flag_n = result[15];
    end

endmodule
