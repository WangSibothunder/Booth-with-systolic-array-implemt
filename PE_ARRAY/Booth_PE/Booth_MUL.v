`timescale 1ns / 1ps
module Booth_MUL #(
    parameter INPUT_WIDTH = 8,
    parameter NUM_CODE_WIDTH = 5,
    parameter MATRIX_SIZE = 3,
    parameter OUTPUT_WIDTH=$clog2(MATRIX_SIZE*(2**INPUT_WIDTH))-1
) (
    input clk,reset_n,
    input signed [INPUT_WIDTH-1:0] input_q, input_q_rev,
    input [NUM_CODE_WIDTH-1:0] NUM_CODE,
    input signed [OUTPUT_WIDTH-1:0] input_partialmul,
    output signed [OUTPUT_WIDTH-1:0] partialmul_out,
    output signed [INPUT_WIDTH-1:0] input_q_next, input_q_rev_next
);

    wire signed [OUTPUT_WIDTH-1:0] input_partialmul_opshift;
    assign input_partialmul_opshift = input_partialmul <<< 2;
    wire clk_en; // 用于控制寄存器的使能

    //将流水线的寄存器放在MUL后面,这个booth单元需要工作的时候再进行工作
    reg signed [OUTPUT_WIDTH-1:0] pipeline_reg_input_partialmul_opshift;
    reg signed [INPUT_WIDTH-1:0] pipeline_reg_input_q,pipeline_reg_input_q_rev;
    // assign clk_en=(!NUM_CODE[4])&clk;

    reg signed [OUTPUT_WIDTH-1:0] partialmul_out_inner;
    

    // 组合逻辑块

    //pipeline state1,读取数据
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)begin
            pipeline_reg_input_partialmul_opshift<=0;
            pipeline_reg_input_q<=0;
            pipeline_reg_input_q_rev<=0;
            
        end
        else if(!NUM_CODE[4]) begin
        pipeline_reg_input_partialmul_opshift<=input_partialmul_opshift;
        pipeline_reg_input_q<=input_q;
        pipeline_reg_input_q_rev<=input_q_rev;end
    end
    reg signed [INPUT_WIDTH-1:0] input_q_state2,input_q_state2_rev;
    // pipeline state2,计算上一阶段数据
    always @(posedge clk or negedge reset_n) begin//每轮算完，都应该是左边传过来之前算过的内容左移两位，再累加
        if (!reset_n) begin 
                    partialmul_out_inner<=0;
                    input_q_state2<=0;
                    input_q_state2_rev<=0;
                    end        
        else if(!NUM_CODE[4]) begin case (NUM_CODE)
            5'b01000:partialmul_out_inner<=(pipeline_reg_input_q<<<1)+pipeline_reg_input_partialmul_opshift;
            5'b00100:partialmul_out_inner<=(pipeline_reg_input_q_rev<<<1)+pipeline_reg_input_partialmul_opshift;
            5'b00010:partialmul_out_inner<=(pipeline_reg_input_q)+pipeline_reg_input_partialmul_opshift;
            5'b00001:partialmul_out_inner<=(pipeline_reg_input_q_rev)+pipeline_reg_input_partialmul_opshift;
        endcase
            input_q_state2<=pipeline_reg_input_q;
            input_q_state2_rev<=pipeline_reg_input_q_rev;
        end
    end  
    assign input_q_next=(NUM_CODE[4])?input_q:input_q_state2;
    assign input_q_rev_next=(NUM_CODE[4])?input_q_rev:input_q_state2_rev;      
    assign partialmul_out=(NUM_CODE[4])?input_partialmul_opshift:partialmul_out_inner;
endmodule
