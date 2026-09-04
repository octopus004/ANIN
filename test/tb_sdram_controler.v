`timescale 1ns/1ps

module tb_sdram_controller;

reg  [18:0] addr = 19'd0;
reg  [7:0]  wdata = 8'hA5;
reg         wr_req = 1'b0;
reg         rd_req = 1'b0;

wire        ready;
wire [7:0]  rdata;
wire        rvalid;
wire        init_done;
wire [4:0]  debug_state;

wire [12:0] DRAM_ADDR;
wire [1:0]  DRAM_BA;
wire        DRAM_CAS_N;
wire        DRAM_CKE;
wire        DRAM_CS_N;
wire [15:0] DRAM_DQ;
wire [1:0]  DRAM_DQM;
wire        DRAM_RAS_N;
wire        DRAM_WE_N;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
	 
	 wire sdram_clk;

assign #3 sdram_clk = clk;
	 
	 sdram_controller dut (
    .clk(sdram_clk),
    .rst_n(rst_n),

    .addr(addr),
    .wdata(wdata),
    .wr_req(wr_req),
    .rd_req(rd_req),

    .ready(ready),
    .rdata(rdata),
    .rvalid(rvalid),

    .DRAM_ADDR(DRAM_ADDR),
    .DRAM_BA(DRAM_BA),
    .DRAM_CAS_N(DRAM_CAS_N),
    .DRAM_CKE(DRAM_CKE),
    .DRAM_CS_N(DRAM_CS_N),
    .DRAM_DQ(DRAM_DQ),
    .DRAM_DQM(DRAM_DQM),
    .DRAM_RAS_N(DRAM_RAS_N),
    .DRAM_WE_N(DRAM_WE_N),

    .debug_state(debug_state),
    .init_done(init_done)
);

mt48lc16m16a2 sdram_model (
    .Dq    (DRAM_DQ),
    .Addr  (DRAM_ADDR),
    .Ba    (DRAM_BA),
    .Clk   (clk),
    .Cke   (DRAM_CKE),
    .Cs_n  (DRAM_CS_N),
    .Ras_n (DRAM_RAS_N),
    .Cas_n (DRAM_CAS_N),
    .We_n  (DRAM_WE_N),
    .Dqm   (DRAM_DQM)
);
    // 50 MHz clock
    always #10 clk = ~clk;

    // reset
    initial begin
          $display("START");

    #100;
    rst_n = 1'b1;
    $display("RESET RELEASED at %0t", $time);

    wait(init_done == 1'b1);
    $display("INIT DONE at %0t, state=%d", $time, debug_state);

	 
	 
	 // WRITE 0 -> A5
addr = 19'd0;
wdata = 8'hA5;

@(negedge clk);
wr_req = 1'b1;
@(negedge clk);
wr_req = 1'b0;

wait(ready == 1'b0);
wait(ready == 1'b1);


// WRITE 1 -> 5A
addr = 19'd1;
wdata = 8'h5A;

@(negedge clk);
wr_req = 1'b1;
@(negedge clk);
wr_req = 1'b0;

wait(ready == 1'b0);
wait(ready == 1'b1);


// WRITE 1023 -> 3C
addr = 19'd1023;
wdata = 8'h3C;

@(negedge clk);
wr_req = 1'b1;
@(negedge clk);
wr_req = 1'b0;

wait(ready == 1'b0);
wait(ready == 1'b1);


// WRITE 1024 -> C3
addr = 19'd1024;
wdata = 8'hC3;

@(negedge clk);
wr_req = 1'b1;
@(negedge clk);
wr_req = 1'b0;

wait(ready == 1'b0);
wait(ready == 1'b1);

$display("ALL WRITES DONE");
    //@(posedge clk);
    //wr_req = 1'b1;

    //@(posedge clk);
    //wr_req = 1'b0;
    //$display("WRITE REQUEST SENT at %0t", $time);
	//	wait (ready==1'b0);
  //  wait(ready == 1'b1);
  //  $display("WRITE DONE at %0t, state=%d", $time, debug_state);

   // @(posedge clk);
   // rd_req = 1'b1;

    //@(posedge clk);
    //rd_req = 1'b0;
    //$display("READ REQUEST SENT at %0t", $time);
//wait(ready == 1'b0);
//$display("READ ACCEPTED at %0t", $time);
  //  wait(rvalid == 1'b1);
    //$display("RVALID RECEIVED at %0t, rdata=%h, state=%d",
            // $time, rdata, debug_state);

    //if (rdata == )
      //  $display("PASS");
    //else
       // $display("FAIL");
// READ 0 -> ocekujemo A5
addr = 19'd0;

@(negedge clk);
rd_req = 1'b1;
@(negedge clk);
rd_req = 1'b0;

wait(ready == 1'b0);
wait(rvalid == 1'b1);

if (rdata == 8'hA5)
    $display("ADDR 0 PASS: %h", rdata);
else
    $display("ADDR 0 FAIL: got %h expected A5", rdata);

wait(ready == 1'b1);


// READ 1 -> ocekujemo 5A
addr = 19'd1;

@(negedge clk);
rd_req = 1'b1;
@(negedge clk);
rd_req = 1'b0;

wait(ready == 1'b0);
wait(rvalid == 1'b1);

if (rdata == 8'h5A)
    $display("ADDR 1 PASS: %h", rdata);
else
    $display("ADDR 1 FAIL: got %h expected 5A", rdata);

wait(ready == 1'b1);


// READ 1023 -> ocekujemo 3C
addr = 19'd1023;

@(negedge clk);
rd_req = 1'b1;
@(negedge clk);
rd_req = 1'b0;

wait(ready == 1'b0);
wait(rvalid == 1'b1);

if (rdata == 8'h3C)
    $display("ADDR 1023 PASS: %h", rdata);
else
    $display("ADDR 1023 FAIL: got %h expected 3C", rdata);

wait(ready == 1'b1);


// READ 1024 -> ocekujemo C3
addr = 19'd1024;

@(negedge clk);
rd_req = 1'b1;
@(negedge clk);
rd_req = 1'b0;

wait(ready == 1'b0);
wait(rvalid == 1'b1);

if (rdata == 8'hC3)
    $display("ADDR 1024 PASS: %h", rdata);
else
    $display("ADDR 1024 FAIL: got %h expected C3", rdata);

$display("MULTI-ADDRESS TEST FINISHED");

    #100;
    $stop;
    end

endmodule
