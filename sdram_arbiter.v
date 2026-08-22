
module sdram_arbiter #(
    parameter ADDR_WIDTH = 19
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // graficki kontroler pise
    input  wire                     gfx_req,
    input  wire [ADDR_WIDTH-1:0]    gfx_addr,
    input  wire [7:0]               gfx_wdata,
    output reg                      gfx_grant,

    // vga kontroler cita
    input  wire                     vga_req,
    input  wire [ADDR_WIDTH-1:0]    vga_addr,
    output reg                      vga_grant,
    output reg  [7:0]               vga_rdata,
    output reg                      vga_rvalid,

    // ka sdram 
    output reg  [ADDR_WIDTH-1:0]    sdram_addr,
    output reg  [7:0]               sdram_din,
    output reg                      sdram_rd,
    output reg                      sdram_wr,
    input  wire [7:0]               sdram_dout
);

    localparam S_IDLE     = 2'd0,
               S_VGA_ACC  = 2'd1,
               S_GFX_ACC  = 2'd2,
               S_VGA_WAIT = 2'd3;

    reg [1:0] state;
    reg       last_was_vga; // ko je dobio pristup u prethodnom ciklusu 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            gfx_grant    <= 1'b0;
            vga_grant    <= 1'b0;
            vga_rvalid   <= 1'b0;
            sdram_rd     <= 1'b0;
            sdram_wr     <= 1'b0;
            last_was_vga <= 1'b0;
        end else begin
            gfx_grant  <= 1'b0;
            vga_grant  <= 1'b0;
            sdram_rd   <= 1'b0;
            sdram_wr   <= 1'b0;
            vga_rvalid <= 1'b0;

            // rezultat citanja iz proslog ciklusa 
            if (last_was_vga) begin
                vga_rdata  <= sdram_dout;
                vga_rvalid <= 1'b1;
            end
            last_was_vga <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (vga_req) begin
                        // vga ima prioritet
                        sdram_addr   <= vga_addr;
                        sdram_rd     <= 1'b1;
                        vga_grant    <= 1'b1;
                        last_was_vga <= 1'b1;
                        state        <= S_IDLE;
                    end else if (gfx_req) begin
                        sdram_addr <= gfx_addr;
                        sdram_din  <= gfx_wdata;
                        sdram_wr   <= 1'b1;
                        gfx_grant  <= 1'b1;
                        state      <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
