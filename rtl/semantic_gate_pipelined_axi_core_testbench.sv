/**
 * @file testbench.sv
 * @author Jonathan Alan Reed
 * @license AGPL 3.0
 * @description Parametric Testbench for Semantic Gate Logic.
 * @include semantic_gate_pipelined_axi_core.sv
 * @include semantic_gate_vectors.hex
 */

`timescale 1ns/1ps

module semantic_gate_tb;
    parameter integer DIM = 16; 
    parameter integer BUS = DIM * 16;
    
    logic clk, rst_n;
    logic [15:0] mem [0:599][0:DIM-1];
    logic [BUS-1:0] tdata;
    logic [2:0] tuser;
    logic tvalid, tready;
    logic fault, calibrated;
    logic [63:0] energy;
    
    integer detections = 0;
    integer false_alarms = 0;
    integer i;

    semantic_gate_axi_wrapper #(.VECTOR_DIM(DIM), .BUS_WIDTH(BUS)) dut (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(tdata), .s_axis_tuser(tuser),
        .s_axis_tvalid(tvalid), .s_axis_tready(tready),
        .fault_detected(fault), .error_energy(energy), .calibrated(calibrated)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
      $readmemh("semantic_gate_vectors.hex", mem);
        rst_n = 0; tvalid = 0; #100; rst_n = 1;
      
        for (i = 0; i < 200; i = i + 1) begin
            drive_axi(i*3, 3'd0);
            drive_axi(i*3+1, 3'd1);
            drive_axi(i*3+2, 3'd2);
            
            // Wait for 2 clock cycles for pipeline latency
            repeat(2) @(posedge clk); #2;

            if (calibrated) begin
                if (i < 100 && fault) false_alarms++;
                else if (i >= 100 && fault) detections++;
            end
        end

        $display("\n====================================================");
        $display("   SEMANTIC GATE IP VERIFICATION SUMMARY REPORT");
        $display("====================================================");
        $display(" [CONFIG] DIMENSION    : %0d", DIM);
        $display(" [STATUS] CALIBRATION  : %s", calibrated ? "SUCCESS" : "FAILED");
        $display(" [DATA]   THRESHOLD    : %d", dut.core_inst.dynamic_threshold);
        $display(" ----------------------------------------------------");
        $display(" [RESULT] DETECTIONS   : %0d / 100", detections);
        $display(" [RESULT] FALSE ALARMS : %0d / 100", false_alarms);
        $display("====================================================\n");
        $finish;
    end

    task drive_axi(input integer row, input logic [2:0] tag);
        @(posedge clk);
        tvalid <= 1; tuser <= tag;
        for (int j=0; j<DIM; j++) tdata[(j*16)+:16] <= mem[row][j];
        wait(tready);
        @(posedge clk);
        tvalid <= 0;
    endtask
endmodule
