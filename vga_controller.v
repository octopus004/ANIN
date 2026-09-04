module vga_controller #(
    parameter ADDR_WIDTH = 19
)(
    input  wire                  clk,
    input  wire                  rst_n,

    output wire                  vga_req,
    output wire [ADDR_WIDTH-1:0] vga_addr,
    input  wire                  vga_grant,
    input  wire [7:0]            vga_rdata,
    input  wire                  vga_rvalid,

    output wire                  hsync,
    output wire                  vsync,
    output reg  [7:0]            pixel_color,
    output wire                  video_active
);

    reg div2 = 1'b0;
    reg [9:0] hcnt = 10'd0;
    reg [9:0] vcnt = 10'd0;

    always @(posedge clk) begin
        div2 <= ~div2;

        if (div2) begin
            if (hcnt == 10'd799) begin
                hcnt <= 10'd0;

                if (vcnt == 10'd524)
                    vcnt <= 10'd0;
                else
                    vcnt <= vcnt + 10'd1;
            end
            else begin
                hcnt <= hcnt + 10'd1;
            end
        end
    end

    assign hsync =
        ~((hcnt >= 10'd656) && (hcnt < 10'd752));

    assign vsync =
        ~((vcnt >= 10'd490) && (vcnt < 10'd492));

    assign video_active =
        (hcnt < 10'd640) && (vcnt < 10'd480);

    always @(*) begin
        if (video_active)
            pixel_color = 8'b111_000_00;   // crveno
        else
            pixel_color = 8'b000_000_00;
    end

    // bez sdram
    assign vga_req  = 1'b0;
    assign vga_addr = {ADDR_WIDTH{1'b0}};

endmodule