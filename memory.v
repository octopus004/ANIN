
module memory #(
    parameter MEM_WORDS = 65536,
    parameter INIT_FILE = ""
)(
    input  wire        clk,
    input  wire [15:0] addr,
    input  wire [15:0] din,
    input  wire        rd,
    input  wire        wr,
    output reg  [15:0] dout
);

    reg [15:0] mem [0:MEM_WORDS-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (wr)
            mem[addr] <= din;
        if (rd)
            dout <= mem[addr];
    end

endmodule
