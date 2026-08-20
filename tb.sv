
`timescale 1ns/1ps

module tb;

  reg clk, rst;
  reg all_pass;
  integer i;

  logic [31:0] in_a, in_b;
  logic [31:0] expected, actual;

  top dut (
    .clk(clk),
    .rst(rst)
  );

  always #5 clk = ~clk;


  task generator();
    in_a = 5;
    in_b = 3;
  endtask : generator

  task driver();
    dut.reg_file.register[1] = in_a;
    dut.reg_file.register[3] = in_b;
  endtask : driver

  task mon_in();
    $display("Inputs: x1=%0d x3=%0d", dut.reg_file.read_register(1), dut.reg_file.read_register(3));
  endtask : mon_in

  task predictor();
    expected = 8; 
  endtask : predictor

  task mon_out();
    @(posedge clk);
    actual = dut.reg_file.read_register(3);
    $display("Output: x3=%0d", actual);
  endtask : mon_out

  task check();
    if (actual === expected) begin
      $display("PASS: got %0d", actual);
    end else begin
      $display("FAIL: expected %0d got %0d", expected, actual);
      all_pass = 0;
    end
  endtask : check


  initial begin
    clk = 0;
    rst = 1;
    all_pass = 1;

    $display("\n========================================");
    $display("SINGLE-CYCLE RISC-V PROCESSOR SIMULATION");
    $display("========================================\n");

    #20 rst = 0;

    for (i = 0; i < 20; i = i + 1) begin
      generator();
      driver();
      mon_in();
      predictor();
      mon_out();
      check();
      #10;
    end

    $display("\n========================================");
    if (all_pass)
      $display("ALL TESTS PASSED");
    else
      $display("SOME TESTS FAILED");
    $display("========================================");

    $finish;
  end

endmodule : tb
