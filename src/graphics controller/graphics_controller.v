//   GFX_X, GFX_Y   koordinate gornjeg-levog temena kvadrata 32x32
//   GFX_COLOR      8-bitna vrednost piksela (boja)
//   GFX_CMD        upis 1 pokrece pomeranje/iscrtavanje kvadrata
//   GFX_BUSY       kontroler zauzet (RO)
//

`include "isa_defines.vh"

module graphics_controller #(
parameter FRAME_WIDTH  = 640,
parameter FRAME_HEIGHT = 480,
parameter SQ_SIZE      = 32,
parameter ADDR_WIDTH   = 19,
parameter BG_COLOR     = 8'h00
)(
input  wire        clk,
input  wire        rst_n,

input  wire        cs,
input  wire [15:0] addr,
input  wire [15:0] din,
input  wire        rd,
input  wire        wr,
output reg  [15:0] dout,

output reg                   gfx_req,
output reg [ADDR_WIDTH-1:0]  gfx_addr,
output reg [7:0]             gfx_wdata,
input  wire                  gfx_grant,
output wire                  gfx_busy
);

reg [15:0] reg_x, reg_y;
reg [7:0]  reg_color;
reg        busy;

assign gfx_busy = busy;

reg [15:0] prev_x, prev_y;
reg        prev_valid;


localparam S_IDLE       = 4'd0,
S_LATCH      = 4'd1,

S_ERASE      = 4'd2,
S_ERASE_W    = 4'd3,
S_DRAW       = 4'd4,
S_DRAW_W     = 4'd5,

S_EDGE_ERASE = 4'd6,
S_EDGE_EW    = 4'd7,
S_EDGE_DRAW  = 4'd8,
S_EDGE_DW    = 4'd9,

S_DONE       = 4'd10;

localparam DIR_NONE  = 3'd0,
DIR_UP    = 3'd1,
DIR_DOWN  = 3'd2,
DIR_LEFT  = 3'd3,
DIR_RIGHT = 3'd4;

reg [3:0] state;
reg [2:0] direction;

reg [4:0] row, col;
reg [5:0] edge_cnt;

reg [15:0] draw_x, draw_y;

wire [ADDR_WIDTH-1:0] pix_addr =
(draw_y + row) * FRAME_WIDTH +
(draw_x + col);


/*
* cpu upis registara + FSM
*/
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
reg_x       <= 16'd0;
reg_y       <= 16'd0;
reg_color   <= 8'hFF;

prev_x      <= 16'd0;
prev_y      <= 16'd0;
prev_valid  <= 1'b0;

busy        <= 1'b0;
gfx_req     <= 1'b0;

row         <= 5'd0;
col         <= 5'd0;
edge_cnt    <= 6'd0;

draw_x      <= 16'd0;
draw_y      <= 16'd0;

direction   <= DIR_NONE;
state       <= S_IDLE;
end
else begin

gfx_req <= 1'b0;

/*
* cpu upis u gfx registre
*/
if (cs && wr) begin
case (addr)
`ADDR_GFX_X:
reg_x <= din;

`ADDR_GFX_Y:
reg_y <= din;

`ADDR_GFX_COLOR:
reg_color <= din[7:0];

`ADDR_GFX_CMD:
if (din[0] && state == S_IDLE)
state <= S_LATCH;

default: ;
endcase
end


case (state)

/*
* cekamo komandu
*/
S_IDLE: begin
end


/*
*  prvi put  full draw
*  pomeranje za 1 px  edge update
*  sve ostalo  full erase i draw
*/
S_LATCH: begin
busy     <= 1'b1;
row      <= 5'd0;
col      <= 5'd0;
edge_cnt <= 6'd0;

if (!prev_valid) begin
/*
* Prvo crtanje.
*/
draw_x <= reg_x;
draw_y <= reg_y;
state  <= S_DRAW;
end

/*
* RIGHT: X = prev_x + 1
*/
/*  else if ((reg_x == prev_x + 16'd1) &&
(reg_y == prev_y)) begin
direction <= DIR_RIGHT;
state     <= S_EDGE_ERASE;


end
*/
/*
* LEFT: X = prev_x - 1
*/
/*     else if ((reg_x + 16'd1 == prev_x) &&
(reg_y == prev_y)) begin
direction <= DIR_LEFT;
state     <= S_EDGE_ERASE;
end

/*
* DOWN: Y = prev_y + 1
*/
/*          else if ((reg_y == prev_y + 16'd1) &&
(reg_x == prev_x)) begin
direction <= DIR_DOWN;
state     <= S_EDGE_ERASE;
end

/*
* UP: Y = prev_y - 1
*/
/*          else if ((reg_y + 16'd1 == prev_y) &&
(reg_x == prev_x)) begin
direction <= DIR_UP;
state     <= S_EDGE_ERASE;
end


else begin
// direction <= DIR_NONE;

draw_x <= prev_x;
draw_y <= prev_y;

state <= S_ERASE;
end
end



S_ERASE: begin
gfx_addr  <= pix_addr;
gfx_wdata <= BG_COLOR;
gfx_req   <= 1'b1;

state <= S_ERASE_W;
//draw_x <= reg_x;
//draw_y <= reg_y;
//row    <= 5'd0;
//col    <= 5'd0;
//state<=S_DRAW;
end


S_ERASE_W: begin
if (gfx_grant) begin

if (col == SQ_SIZE-1) begin
col <= 5'd0;

if (row == SQ_SIZE-1) begin
row <= 5'd0;

draw_x <= reg_x;
draw_y <= reg_y;

state <= S_DRAW;
end
else begin
row <= row + 5'd1;
state <= S_ERASE;
end
end
else begin
col <= col + 5'd1;
state <= S_ERASE;
end
end
else begin
gfx_req <= 1'b1;
end
end



S_DRAW: begin
gfx_addr  <= pix_addr;
gfx_wdata <= reg_color;
gfx_req   <= 1'b1;

state <= S_DRAW_W;
end


S_DRAW_W: begin
if (gfx_grant) begin

if (col == SQ_SIZE-1) begin
col <= 5'd0;

if (row == SQ_SIZE-1) begin
state <= S_DONE;
end
else begin
row <= row + 5'd1;
state <= S_DRAW;
end
end
else begin
col <= col + 5'd1;
state <= S_DRAW;
end
end
else begin
gfx_req <= 1'b1;
end
end



S_EDGE_ERASE: begin

case (direction)

/*
* brisemo staru levu kolonu
* x = prev_x
* y = prev_y + edge_cnt
*/
DIR_RIGHT: begin
gfx_addr <=
(prev_y + edge_cnt) * FRAME_WIDTH
+ prev_x;
end


/*
* brisemo staru desnu kolonu
* x = prev_x + 31
*/
DIR_LEFT: begin
gfx_addr <=
(prev_y + edge_cnt) * FRAME_WIDTH
+ prev_x + (SQ_SIZE-1);
end


/*
* brišemo stari gornji red
*/
DIR_DOWN: begin
gfx_addr <=
prev_y * FRAME_WIDTH
+ prev_x + edge_cnt;
end


/*
* brišemo stari donji red
*/
DIR_UP: begin
gfx_addr <=
(prev_y + (SQ_SIZE-1)) * FRAME_WIDTH
+ prev_x + edge_cnt;
end

default:
gfx_addr <= {ADDR_WIDTH{1'b0}};

endcase

gfx_wdata <= BG_COLOR;
gfx_req   <= 1'b1;

state <= S_EDGE_EW;
end


S_EDGE_EW: begin
if (gfx_grant) begin

if (edge_cnt == SQ_SIZE-1) begin
edge_cnt <= 6'd0;
state <= S_EDGE_DRAW;
end
else begin
edge_cnt <= edge_cnt + 6'd1;
state <= S_EDGE_ERASE;
end
end
else begin
gfx_req <= 1'b1;
end
end


S_EDGE_DRAW: begin

case (direction)

/*
* nova desna kolona
*/
DIR_RIGHT: begin
gfx_addr <=
(reg_y + edge_cnt) * FRAME_WIDTH
+ reg_x + (SQ_SIZE-1);
end


/*
* nova leva kolona
*/
DIR_LEFT: begin
gfx_addr <=
(reg_y + edge_cnt) * FRAME_WIDTH
+ reg_x;
end


/*
* novi donji red
*/
DIR_DOWN: begin
gfx_addr <=
(reg_y + (SQ_SIZE-1)) * FRAME_WIDTH
+ reg_x + edge_cnt;
end


/*
* novi gornji red
*/
DIR_UP: begin
gfx_addr <=
reg_y * FRAME_WIDTH
+ reg_x + edge_cnt;
end

default:
gfx_addr <= {ADDR_WIDTH{1'b0}};

endcase

gfx_wdata <= reg_color;
gfx_req   <= 1'b1;

state <= S_EDGE_DW;
end


S_EDGE_DW: begin
if (gfx_grant) begin

if (edge_cnt == SQ_SIZE-1) begin
edge_cnt <= 6'd0;
state <= S_DONE;
end
else begin
edge_cnt <= edge_cnt + 6'd1;
state <= S_EDGE_DRAW;
end
end
else begin
gfx_req <= 1'b1;
end
end


/*
* završeno pomeranje
*/
S_DONE: begin
prev_x     <= reg_x;
prev_y     <= reg_y;
prev_valid <= 1'b1;

busy  <= 1'b0;
state <= S_IDLE;
end


default: begin
state <= S_IDLE;
end

endcase
end
end


/*
* citanje registara sa cpu magistrale
*/
always @(posedge clk) begin
if (cs && rd) begin
case (addr)
`ADDR_GFX_X:
dout <= reg_x;

`ADDR_GFX_Y:
dout <= reg_y;

`ADDR_GFX_COLOR:
dout <= {8'b0, reg_color};

`ADDR_GFX_BUSY:
dout <= {15'b0, busy};

default:
dout <= 16'h0000;
endcase
end
end

endmodule
