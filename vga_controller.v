


module vga_controller #(
    parameter ADDR_WIDTH = 19,
    parameter H_VISIBLE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48,
    parameter V_VISIBLE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33,
    parameter FIFO_DEPTH = 16
)(
    input  wire        clk,        // pixel takt
    input  wire        rst_n,

    // interfejs ka SDRAM arbitru (master strana VGA kontrolera, prioritet)
    output reg                     vga_req,
    output reg  [ADDR_WIDTH-1:0]   vga_addr,
    input  wire                    vga_grant,
    input  wire [7:0]              vga_rdata,
    input  wire                    vga_rvalid,

    // interfejs ka monitoru
    output reg          hsync,
    output reg          vsync,
    output reg  [7:0]   pixel_color,
    output wire          video_active
);

    localparam H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP; // 800
    localparam V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP; // 525

    // brojaci piksela/linija
    reg [9:0] hcnt; // 0..799
    reg [9:0] vcnt; // 0..524

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hcnt <= 10'd0; vcnt <= 10'd0;
        end else begin
            if (hcnt == H_TOTAL-1) begin
                hcnt <= 10'd0;
                vcnt <= (vcnt == V_TOTAL-1) ? 10'd0 : vcnt + 10'd1;
            end else begin
                hcnt <= hcnt + 10'd1;
            end
        end
    end

    assign video_active = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync <= 1'b1; vsync <= 1'b1;
        end else begin
            // sync impulsi su aktivni na nisko
            hsync <= ~((hcnt >= H_VISIBLE + H_FP) && (hcnt < H_VISIBLE + H_FP + H_SYNC));
            vsync <= ~((vcnt >= V_VISIBLE + V_FP) && (vcnt < V_VISIBLE + V_FP + V_SYNC));
        end
    end

    //FIFO bafer za prefetch piksela 
    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [3:0] wptr, rptr;      // 4 bita
    reg [4:0] fifo_count;      // 5 bita

    wire fifo_full  = (fifo_count == FIFO_DEPTH);
    wire fifo_empty = (fifo_count == 0);

    // adresa sledeceg piksela koji treba prefetch-ovati 
    reg [ADDR_WIDTH-1:0] fetch_addr;
    reg                  frame_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fetch_addr  <= {ADDR_WIDTH{1'b0}};
            wptr <= 4'd0; rptr <= 4'd0; fifo_count <= 5'd0;
            vga_req <= 1'b0;
        end else begin
            vga_req <= 1'b0;

            // pocetak novog frejma - resetuj adresu citanja na 0
            if (hcnt == 0 && vcnt == 0)
                fetch_addr <= {ADDR_WIDTH{1'b0}};

            // zahtevaj sledeci piksel ako ima mesta u FIFO
            if (!fifo_full) begin
                vga_req  <= 1'b1;
                vga_addr <= fetch_addr;
            end

            // upis rezultata citanja u FIFO kad stigne VGA ima prioritet
            
            if (vga_rvalid) begin
                fifo_mem[wptr] <= vga_rdata;
                wptr <= wptr + 4'd1;
                fetch_addr <= fetch_addr + 1'b1;
            end

            // logika brojaca popunjenosti FIFO-a (upis/citanje istovremeno moguce)
            case ({vga_rvalid, (video_active && !fifo_empty)})
                2'b10: fifo_count <= fifo_count + 5'd1; // samo upis
                2'b01: fifo_count <= fifo_count - 5'd1; // samo citanje
                default: fifo_count <= fifo_count;      // oba ili nijedno 
            endcase

            // citanje iz FIFO za prikaz trenutnog piksela
            if (video_active && !fifo_empty) begin
                pixel_color <= fifo_mem[rptr];
                rptr <= rptr + 4'd1;
            end else if (!video_active) begin
                pixel_color <= 8'h00; // van vidljive oblasti
            end
        end
    end

endmodule
