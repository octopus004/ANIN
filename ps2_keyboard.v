

// e0 prefiks + make codovi
//   gore  = 0x75   dole = 0x72   levo = 0x6B   desno = 0x74
// break codovi  imaju prefiks E0 F0 xx i ignorisu se


`include "isa_defines.vh"

module ps2_keyboard (
    input  wire        clk,       
    input  wire        rst_n,

    // fizicki ps2 pinovi
    input  wire         ps2_clk,
    input  wire         ps2_data,

    // magistrala (periferijski slave interfejs)
    input  wire         cs,
    input  wire [15:0]  addr,
    output reg  [15:0]  dout,
    input  wire         rd,

    output reg           irq_req    // zahtev ka interrupt_ctrl (nivo, drzi se do citanja)
);

    // pravac kodovan u kbd_data 0=gore 1=dole 2=levo 3=desno
    localparam DIR_UP    = 8'd0;
    localparam DIR_DOWN  = 8'd1;
    localparam DIR_LEFT  = 8'd2;
    localparam DIR_RIGHT = 8'd3;

    // sinhronizacija ps2 clk i detekcija opadajuce ivice
    reg [2:0] clk_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) clk_sync <= 3'b111;
        else        clk_sync <= {clk_sync[1:0], ps2_clk};
    wire ps2_clk_falling = (clk_sync[2:1] == 2'b10);

    reg [1:0] data_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) data_sync <= 2'b11;
        else        data_sync <= {data_sync[0], ps2_data};
    wire ps2_data_bit = data_sync[1];

    // prijem okvira 
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [7:0] scancode;
    reg       byte_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt    <= 4'd0;
            shift_reg  <= 8'd0;
            byte_ready <= 1'b0;
        end else begin
            byte_ready <= 1'b0;
            if (ps2_clk_falling) begin
                case (bit_cnt)
                    4'd0: begin // start bit, ocekuje se 0
                        if (ps2_data_bit == 1'b0) bit_cnt <= bit_cnt + 4'd1;
                    end
                    4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
                        shift_reg <= {ps2_data_bit, shift_reg[7:1]}; // LSB prvo
                        bit_cnt   <= bit_cnt + 4'd1;
                    end
                    4'd9: begin // parity - ne proveravamo strogo
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                    4'd10: begin // stop bit
                        scancode   <= shift_reg;
                        byte_ready <= 1'b1;
                        bit_cnt    <= 4'd0;
                    end
                    default: bit_cnt <= 4'd0;
                endcase
            end
        end
    end

    // dekodovanje sekvence bajtova e0 prefiks, break f0 se ignorise
    reg extended;   // primljen e0 prefiks
    reg breaking;   // primljen f0 otpust,sledeci bajt se ignorise za irq

    reg [7:0]  kbd_data_reg;
    reg        kbd_new;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            extended     <= 1'b0;
            breaking     <= 1'b0;
            kbd_new      <= 1'b0;
            kbd_data_reg <= 8'd0;
            irq_req      <= 1'b0;
        end else begin
            // irq zahtev je nivo-osetljiv dok ga isr ne pokupi citanjem kbd_data
            if (cs && rd && (addr == `ADDR_KBD_DATA)) begin
                irq_req <= 1'b0;
                kbd_new <= 1'b0;
            end

            if (byte_ready) begin
                if (scancode == 8'hE0) begin
                    extended <= 1'b1;
                end else if (scancode == 8'hF0) begin
                    breaking <= 1'b1;
                end else begin
                    if (extended && !breaking) begin
                        case (scancode)
                            8'h75: begin kbd_data_reg <= DIR_UP;    kbd_new <= 1'b1; irq_req <= 1'b1; end
                            8'h72: begin kbd_data_reg <= DIR_DOWN;  kbd_new <= 1'b1; irq_req <= 1'b1; end
                            8'h6B: begin kbd_data_reg <= DIR_LEFT;  kbd_new <= 1'b1; irq_req <= 1'b1; end
                            8'h74: begin kbd_data_reg <= DIR_RIGHT; kbd_new <= 1'b1; irq_req <= 1'b1; end
                            default: ;
                        endcase
                    end
                    extended <= 1'b0;
                    breaking <= 1'b0;
                end
            end
        end
    end

    //citanje registara sa magistrale
    always @(posedge clk) begin
        if (cs && rd) begin
            case (addr)
                `ADDR_KBD_DATA: dout <= {8'b0, kbd_data_reg};
                `ADDR_KBD_STAT: dout <= {15'b0, kbd_new};
                default:        dout <= 16'h0000;
            endcase
        end
    end

endmodule
