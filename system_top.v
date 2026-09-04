
`include "isa_defines.vh"

module system_top #(
    parameter PROGRAM_INIT = "program.hex"
)(
    input  wire clk,
    input  wire rst_n,

    // PS/2 tastatura (fizicki pinovi)
    input  wire ps2_clk,
    input  wire ps2_data,

    // VGA izlaz ka monitoru
    output wire vga_hsync,
    output wire vga_vsync,
  output wire [3:0] vga_r,
output wire [3:0] vga_g,
output wire [3:0] vga_b



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
        end else begin
            hcnt <= hcnt + 10'd1;
        end
    end
end

assign vga_hsync =
    ~((hcnt >= 656) && (hcnt < 752));

assign vga_vsync =
    ~((vcnt >= 490) && (vcnt < 492));

wire active =
    (hcnt < 640) &&
    (vcnt < 480);

assign vga_r = active ? 4'b1111 : 4'b0000;
assign vga_g = 4'b0000;
assign vga_b = 4'b0000;




    // ---------------- sistemska magistrala (CPU je master) ----------------
    wire [15:0] bus_addr;
    wire [15:0] bus_data_out;
    reg  [15:0] bus_data_in;
    wire        bus_rd, bus_wr;
    wire        irq_line;

    // ---------------- dekodovanje adresa (chip-select) ----------------
    wire cs_mem  = (bus_addr <  16'hF000);
    wire cs_gfx  = (bus_addr >= 16'hF000) && (bus_addr <= 16'hF00F);
    wire cs_kbd  = (bus_addr >= 16'hF010) && (bus_addr <= 16'hF01F);
    wire cs_irq  = (bus_addr >= 16'hF020) && (bus_addr <= 16'hF02F);

    // ---------------- CPU ----------------
    cpu u_cpu (
        .clk(clk), .rst_n(rst_n),
        .bus_addr(bus_addr), .bus_data_out(bus_data_out), .bus_data_in(bus_data_in),
        .bus_rd(bus_rd), .bus_wr(bus_wr),
        .irq_line(irq_line)
    );

    // ---------------- interna memorija ----------------
    wire [15:0] mem_dout;
    memory #(.INIT_FILE(PROGRAM_INIT)) u_mem (
        .clk(clk),
        .addr(bus_addr),
        .din(bus_data_out),
        .rd(bus_rd && cs_mem),
        .wr(bus_wr && cs_mem),
        .dout(mem_dout)
    );

    // ---------------- kontroler prekida ----------------
    wire [15:0] irq_dout;
    wire kbd_irq_req;
    interrupt_ctrl u_irqc (
        .clk(clk), .rst_n(rst_n),
        .irq0_req(kbd_irq_req), .irq1_req(1'b0),
        .cs(cs_irq), .addr(bus_addr), .din(bus_data_out),
        .rd(bus_rd && cs_irq), .wr(bus_wr && cs_irq),
        .dout(irq_dout),
        .irq_line(irq_line)
    );

    // ---------------- PS/2 kontroler tastature ----------------
    wire [15:0] kbd_dout;
    ps2_keyboard u_kbd (
        .clk(clk), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .cs(cs_kbd), .addr(bus_addr), .dout(kbd_dout), .rd(bus_rd && cs_kbd),
        .irq_req(kbd_irq_req)
    );

    // ---------------- SDRAM (frame buffer) + arbiter ----------------
    localparam SD_ADDR_W = 19;

    wire                  gfx_req, gfx_grant;
    wire [SD_ADDR_W-1:0]  gfx_addr;
    wire [7:0]            gfx_wdata;

    wire                  vga_req, vga_grant;
    wire [SD_ADDR_W-1:0]  vga_addr;
    wire [7:0]            vga_rdata;
    wire                  vga_rvalid;

    wire [SD_ADDR_W-1:0]  sdram_addr;
    wire [7:0]            sdram_din;
    wire                  sdram_rd, sdram_wr;
    wire [7:0]            sdram_dout;

    sdram_arbiter #(.ADDR_WIDTH(SD_ADDR_W)) u_arb (
        .clk(clk), .rst_n(rst_n),
        .gfx_req(gfx_req), .gfx_addr(gfx_addr), .gfx_wdata(gfx_wdata), .gfx_grant(gfx_grant),
        .vga_req(vga_req), .vga_addr(vga_addr), .vga_grant(vga_grant),
        .vga_rdata(vga_rdata), .vga_rvalid(vga_rvalid),
        .sdram_addr(sdram_addr), .sdram_din(sdram_din),
        .sdram_rd(sdram_rd), .sdram_wr(sdram_wr), .sdram_dout(sdram_dout)
    );

    //sdram_model #(.ADDR_WIDTH(SD_ADDR_W)) u_sdram (
    //    .clk(clk),
      //  .addr(sdram_addr), .din(sdram_din),
        //.rd(sdram_rd), .wr(sdram_wr),
        //.dout(sdram_dout)
    //);

    // ---------------- graficki kontroler ----------------
    wire [15:0] gfx_dout;
    graphics_controller #(.ADDR_WIDTH(SD_ADDR_W)) u_gfxc (
        .clk(clk), .rst_n(rst_n),
        .cs(cs_gfx), .addr(bus_addr), .din(bus_data_out),
        .rd(bus_rd && cs_gfx), .wr(bus_wr && cs_gfx), .dout(gfx_dout),
        .gfx_req(gfx_req), .gfx_addr(gfx_addr), .gfx_wdata(gfx_wdata), .gfx_grant(gfx_grant)
    );

    // ---------------- VGA kontroler ----------------
    wire video_active;
	 /*
    vga_controller #(.ADDR_WIDTH(SD_ADDR_W)) u_vga (
        .clk(clk_25), .rst_n(test_rst_n),
        .vga_req(vga_req), .vga_addr(vga_addr), .vga_grant(vga_grant),
        .vga_rdata(vga_rdata), .vga_rvalid(vga_rvalid),
        .hsync(vga_hsync), .vsync(vga_vsync), .pixel_color(vga_pixel),
        .video_active(video_active)
    );
*/
    // ---------------- multipleksor citanja na magistrali ----------------
    // sve komponente registruju svoj izlaz na posedge clk (1 ciklus
    // kasnjenja, isto kao interna memorija) pa se cs signal koji je
    // vazio U trenutku zahteva mora zapamtiti da bi se ispravno
    // izabrao izvor podatka kada on postane validan
    reg cs_mem_d, cs_gfx_d, cs_kbd_d, cs_irq_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs_mem_d <= 1'b0; cs_gfx_d <= 1'b0; cs_kbd_d <= 1'b0; cs_irq_d <= 1'b0;
        end else begin
            cs_mem_d <= cs_mem && bus_rd;
            cs_gfx_d <= cs_gfx && bus_rd;
            cs_kbd_d <= cs_kbd && bus_rd;
            cs_irq_d <= cs_irq && bus_rd;
        end
    end

    always @(*) begin
        if (cs_gfx_d)      bus_data_in = gfx_dout;
        else if (cs_kbd_d) bus_data_in = kbd_dout;
        else if (cs_irq_d) bus_data_in = irq_dout;
        else                bus_data_in = mem_dout;
    end

endmodule
