/**
 * @file design.sv
 * @author Jonathan Alan Reed
 * @license AGPL 3.0
 * @description Pipelined Semantic Gate Core and AXI4-Stream Wrapper.
 */

`timescale 1ns/1ps

module semantic_gate_core #(
    parameter integer VECTOR_DIM = 16,
    parameter integer DATA_WIDTH = 16,
    parameter integer WARMUP_CYCLES = 5,
    parameter integer CAL_SAMPLES = 10,
    parameter integer MARGIN_DIVISOR = 5
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [DATA_WIDTH-1:0] vec_anchor [VECTOR_DIM],
    input  logic [DATA_WIDTH-1:0] vec_relation [VECTOR_DIM],
    input  logic [DATA_WIDTH-1:0] vec_actual [VECTOR_DIM],
    output logic fault_detected,
    output logic [63:0] error_energy,
    output logic calibrated
);
    logic [63:0] temp_accum; 
    logic [63:0] pred_64, act_64, diff_64;
    logic [63:0] dynamic_threshold;
    logic [63:0] cal_sum;
    logic [63:0] current_v_sum; 
    integer cycle_count;
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_detected <= 0;
            error_energy <= 0;
            cal_sum <= 0;
            cycle_count <= 0;
            dynamic_threshold <= 64'hFFFF_FFFF_FFFF_FFFF;
            calibrated <= 0;
            temp_accum <= 0;
        end else begin
            
            // Stage 1: Difference Calculation
            current_v_sum = 0; 
            for (i = 0; i < VECTOR_DIM; i = i + 1) begin
                pred_64 = 64'(vec_anchor[i]) + 64'(vec_relation[i]);
                act_64  = 64'(vec_actual[i]);
                diff_64 = (pred_64 > act_64) ? (pred_64 - act_64) : (act_64 - pred_64);
                current_v_sum = current_v_sum + diff_64;
            end

            // Stage 2: Pipelined Accumulator
            temp_accum <= current_v_sum;
            error_energy <= temp_accum;

            // Stage 3: Decision Logic
            if (cycle_count < WARMUP_CYCLES) begin
                cycle_count <= cycle_count + 1;
            end 
            else if (cycle_count < (WARMUP_CYCLES + CAL_SAMPLES)) begin
                cal_sum <= cal_sum + temp_accum;
                cycle_count <= cycle_count + 1;
            end 
            else if (cycle_count == (WARMUP_CYCLES + CAL_SAMPLES)) begin
                dynamic_threshold <= (cal_sum / CAL_SAMPLES) + (cal_sum / (CAL_SAMPLES * MARGIN_DIVISOR));
                calibrated <= 1;
                cycle_count <= cycle_count + 1;
            end 
            else begin
                fault_detected <= (temp_accum > dynamic_threshold);
            end
        end
    end
endmodule

module semantic_gate_axi_wrapper #(
    parameter integer VECTOR_DIM = 16,
    parameter integer DATA_WIDTH = 16,
    parameter integer BUS_WIDTH = VECTOR_DIM * DATA_WIDTH
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [BUS_WIDTH-1:0]  s_axis_tdata,
    input  logic [2:0]           s_axis_tuser,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    output logic fault_detected,
    output logic [63:0] error_energy,
    output logic calibrated
);
    logic [DATA_WIDTH-1:0] v_anc_reg [VECTOR_DIM];
    logic [DATA_WIDTH-1:0] v_rel_reg [VECTOR_DIM];
    logic [DATA_WIDTH-1:0] v_act_reg [VECTOR_DIM];

    assign s_axis_tready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int j=0; j<VECTOR_DIM; j++) begin
                v_anc_reg[j] <= 0; v_rel_reg[j] <= 0; v_act_reg[j] <= 0;
            end
        end else if (s_axis_tvalid && s_axis_tready) begin
            for (int i=0; i<VECTOR_DIM; i++) begin
                case (s_axis_tuser)
                    3'd0: v_anc_reg[i] <= s_axis_tdata[(i*DATA_WIDTH)+:DATA_WIDTH];
                    3'd1: v_rel_reg[i] <= s_axis_tdata[(i*DATA_WIDTH)+:DATA_WIDTH];
                    3'd2: v_act_reg[i] <= s_axis_tdata[(i*DATA_WIDTH)+:DATA_WIDTH];
                    default: ;
                endcase
            end
        end
    end

    semantic_gate_core #(.VECTOR_DIM(VECTOR_DIM), .DATA_WIDTH(DATA_WIDTH)) core_inst (
        .clk(clk), .rst_n(rst_n),
        .vec_anchor(v_anc_reg), .vec_relation(v_rel_reg), .vec_actual(v_act_reg),
        .fault_detected(fault_detected), .error_energy(error_energy), .calibrated(calibrated)
    );
endmodule