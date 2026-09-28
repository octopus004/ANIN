module vga_controller #(
parameter ADDR_WIDTH = 19
)(
input  wire                  clk,
input  wire                  rst_n,
input  wire [5:0]            debug_state,

//output wire                  vga_req,
//output wire [ADDR_WIDTH-1:0] vga_addr,
//input  wire                  vga_grant,
//input  wire [7:0]            vga_rdata,
//input  wire                  vga_rvalid,

output reg                   burst_req,
output reg  [18:0]           burst_addr,
output reg  [9:0]            burst_len,

input  wire [7:0]            burst_data,
input  wire                  burst_valid,
input  wire                  burst_done,

output wire                  hsync,
output wire                  vsync,
output reg  [7:0]            pixel_color,
output wire                  video_active
);



reg [7:0] line_buffer0 [0:639];
reg [7:0] line_buffer1 [0:639];

reg display_buf;
reg fetch_buf;

reg div2;

reg [9:0] hcnt;
reg [9:0] vcnt;



reg [9:0] fetch_x;
reg [9:0] fetch_y;

reg       fetching;

assign vga_req  = 1'b0;
assign vga_addr = {ADDR_WIDTH{1'b0}};



always @(posedge clk) begin

if (!rst_n) begin

div2 <= 1'b0;

hcnt <= 10'd0;
vcnt <= 10'd0;

display_buf <= 1'b0;
fetch_buf   <= 1'b1;

fetch_x <= 10'd0;
fetch_y <= 10'd0;

fetching  <= 1'b0;

burst_req  <= 1'b0;
burst_addr <= 19'd0;
burst_len  <= 10'd0;

end

else begin

// burst req je pulse, gasi se svaki takt

burst_req <= 1'b0;
//ucitavanje sl vga linije

if (!fetching &&
hcnt == 10'd0 &&
vcnt < 10'd479) begin

fetch_y <= vcnt + 10'd1;
fetch_x <= 10'd0;

burst_addr <= (vcnt + 10'd1) * 19'd640;
burst_len  <= 10'd640;

burst_req <= 1'b1;
fetching  <= 1'b1;

end

if (fetching && burst_valid) begin

if (fetch_buf == 1'b0)
line_buffer0[fetch_x] <= burst_data;
else
line_buffer1[fetch_x] <= burst_data;

fetch_x <= fetch_x + 10'd1;

end


if (fetching && burst_done) begin
fetching <= 1'b0;
end


div2 <= ~div2;


if (div2) begin

if (hcnt == 10'd799) begin

hcnt <= 10'd0;

if (vcnt == 10'd524) begin

vcnt <= 10'd0;

end

else begin

vcnt <= vcnt + 10'd1;


if (vcnt < 10'd479 &&
!fetching) begin

display_buf <= fetch_buf;
fetch_buf   <= ~fetch_buf;

end

end

end

else begin

hcnt <= hcnt + 10'd1;

end

end

end

end


assign hsync =
~((hcnt >= 10'd656) &&
(hcnt <  10'd752));


assign vsync =
~((vcnt >= 10'd490) &&
(vcnt <  10'd492));


assign video_active =
(hcnt < 10'd640) &&
(vcnt < 10'd480);


always @(*) begin

if (!video_active) begin

pixel_color = 8'h00;

end

else if (display_buf == 1'b0) begin

pixel_color = line_buffer0[hcnt];

end

else begin

pixel_color = line_buffer1[hcnt];

end

end


endmodule
