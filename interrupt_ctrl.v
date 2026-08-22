
//   ADDR_IRQ_MASK bit0=maska IRQ0, bit1=maska IRQ1 (1=dozvoljen)
//   ADDR_IRQ_STAT bit0=IRQ0 aktivan, bit1=IRQ1 aktivan
//   ADDR_IRQ_ACK  upis 1 na bit i gasi odgovarajuci zahtev

`include "isa_defines.vh"

module interrupt_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    // zahtevi za prekid od perifernih kontrolera (nivo-osetljivi, drze
    // se aktivnim dok se ne potvrde upisom u IRQ_ACK)
    input  wire         irq0_req,   
    input  wire         irq1_req,   

    // magistrala (periferijski slave interfejs)
    input  wire         cs,
    input  wire [15:0]  addr,
    input  wire [15:0]  din,
    input  wire         rd,
    input  wire         wr,
    output reg  [15:0]  dout,

    // izlaz ka CPU
    output wire          irq_line
);

    reg [1:0] mask;    // bit0=IRQ0 dozvoljen, bit1=IRQ1 dozvoljen
    reg [1:0] pending;  // latched zahtevi (nivo -> latch, brise se sa ACK)

    // latchovanje prekidnih zahteva (nivo-osetljivi ulazi)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending <= 2'b00;
            mask    <= 2'b00;
        end else begin
            if (irq0_req) pending[0] <= 1'b1;
            if (irq1_req) pending[1] <= 1'b1;

            if (cs && wr) begin
                case (addr)
                    `ADDR_IRQ_MASK: mask <= din[1:0];
                    `ADDR_IRQ_ACK: begin
                        if (din[0]) pending[0] <= 1'b0;
                        if (din[1]) pending[1] <= 1'b0;
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (cs && rd) begin
            case (addr)
                `ADDR_IRQ_MASK: dout <= {14'b0, mask};
                `ADDR_IRQ_STAT: dout <= {14'b0, pending};
                default:        dout <= 16'h0000;
            endcase
        end
    end

    assign irq_line = |(pending & mask);

endmodule
