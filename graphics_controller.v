
//   GFX_X, GFX_Y   koordinate gornjeg-levog temena kvadrata 32x32
//   GFX_COLOR      8-bitna vrednost piksela (boja)
//   GFX_CMD        upis 1 pokrece pomeranje/iscrtavanje kvadrata
//   GFX_BUSY       kontroler zauzet (RO)
//

`include "isa_defines.vh"

module graphics_controller #(
    parameter FRAME_WIDTH  = 640,
    parameter FRAME_HEIGHT = 480,
    parameter SQ_SIZE       = 32,
    parameter ADDR_WIDTH    = 19,
    parameter BG_COLOR      = 8'h00
)(
    input  wire        clk,
    input  wire        rst_n,

    // magistrala,periferijski slave interfejs, strana CPUa
    input  wire         cs,
    input  wire [15:0]  addr,
    input  wire [15:0]  din,
    input  wire         rd,
    input  wire         wr,
    output reg  [15:0]  dout,

    // interfejs ka SDRAM arbitru, aster strana graf. kontrolera
    output reg                     gfx_req,
    output reg  [ADDR_WIDTH-1:0]   gfx_addr,
    output reg  [7:0]              gfx_wdata,
    input  wire                    gfx_grant
);

    //  registri vidljivi CPUu 
    reg [15:0] reg_x, reg_y;
    reg [7:0]  reg_color;
    reg        busy;

    // pamcenje prethodne pozicije, za brisanje stare slike
    reg [15:0] prev_x, prev_y;
    reg        prev_valid;

    //FSM 
    localparam S_IDLE  = 3'd0,
               S_LATCH = 3'd1,
               S_ERASE = 3'd2,
               S_ERASE_W = 3'd3,
               S_DRAW  = 3'd4,
               S_DRAW_W  = 3'd5,
               S_DONE  = 3'd6;

    reg [2:0] state;
    reg [4:0] row, col; // 0..31 brojaci unutar kvadrata
    reg [15:0] draw_x, draw_y;

    wire [ADDR_WIDTH-1:0] pix_addr = (draw_y + row) * FRAME_WIDTH + (draw_x + col);

    //  upis registara sa magistrale 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_x <= 16'd0; reg_y <= 16'd0; reg_color <= 8'hFF;
            state <= S_IDLE;
            busy  <= 1'b0;
            prev_valid <= 1'b0;
            gfx_req <= 1'b0;
        end else begin
            gfx_req <= 1'b0;

            if (cs && wr) begin
                case (addr)
                    `ADDR_GFX_X:     reg_x     <= din;
                    `ADDR_GFX_Y:     reg_y     <= din;
                    `ADDR_GFX_COLOR: reg_color <= din[7:0];
                    `ADDR_GFX_CMD: if (din[0] && state == S_IDLE) state <= S_LATCH;
                    default: ;
                endcase
            end

            case (state)
                S_IDLE: ; // ceka komandu

                S_LATCH: begin
                    busy   <= 1'b1;
                    draw_x <= prev_x; draw_y <= prev_y;
                    row <= 5'd0; col <= 5'd0;
                    state <= prev_valid ? S_ERASE : S_DRAW;
                    if (!prev_valid) begin
                        draw_x <= reg_x; draw_y <= reg_y;
                    end
                end

                //brisanje stare pozicije,upis boje pozadine
                S_ERASE: begin
                    gfx_addr  <= pix_addr;
                    gfx_wdata <= BG_COLOR;
                    gfx_req   <= 1'b1;
                    state     <= S_ERASE_W;
                end
                S_ERASE_W: begin
                    if (gfx_grant) begin
                        if (col == SQ_SIZE-1) begin
                            col <= 5'd0;
                            if (row == SQ_SIZE-1) begin
                                row <= 5'd0;
                                draw_x <= reg_x; draw_y <= reg_y;
                                state  <= S_DRAW;
                            end else begin
                                row <= row + 5'd1;
                                state <= S_ERASE;
                            end
                        end else begin
                            col <= col + 5'd1;
                            state <= S_ERASE;
                        end
                    end else begin
                        gfx_req <= 1'b1; // ponovi zahtev dok  ne dobije grant
                    end
                end

                //iscrtavanje na novoj poziciji
                S_DRAW: begin
                    gfx_addr  <= pix_addr;
                    gfx_wdata <= reg_color;
                    gfx_req   <= 1'b1;
                    state     <= S_DRAW_W;
                end
                S_DRAW_W: begin
                    if (gfx_grant) begin
                        if (col == SQ_SIZE-1) begin
                            col <= 5'd0;
                            if (row == SQ_SIZE-1) begin
                                state <= S_DONE;
                            end else begin
                                row <= row + 5'd1;
                                state <= S_DRAW;
                            end
                        end else begin
                            col <= col + 5'd1;
                            state <= S_DRAW;
                        end
                    end else begin
                        gfx_req <= 1'b1;
                    end
                end

                S_DONE: begin
                    prev_x <= reg_x; prev_y <= reg_y; prev_valid <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    //citanje registara sa magistrale
    always @(posedge clk) begin
        if (cs && rd) begin
            case (addr)
                `ADDR_GFX_X:     dout <= reg_x;
                `ADDR_GFX_Y:     dout <= reg_y;
                `ADDR_GFX_COLOR: dout <= {8'b0, reg_color};
                `ADDR_GFX_BUSY:  dout <= {15'b0, busy};
                default:         dout <= 16'h0000;
            endcase
        end
    end

endmodule
