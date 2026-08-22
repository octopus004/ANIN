// =====================================================================
// regfile.v - 16 registara opste namene (R0-R15), 16-bitnih.
// Dva kombinaciona citanja (Rd, Rs) + jedan sinhroni upis.
// =====================================================================
module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  rd_addr,
    input  wire [3:0]  rs_addr,
    output wire [15:0] rd_data,
    output wire [15:0] rs_data,
    input  wire        we,
    input  wire [3:0]  w_addr,
    input  wire [15:0] w_data
);

    reg [15:0] regs [0:15];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 16'h0000;
        end else if (we) begin
            regs[w_addr] <= w_data;
        end
    end

    assign rd_data = regs[rd_addr];
    assign rs_data = regs[rs_addr];

endmodule
