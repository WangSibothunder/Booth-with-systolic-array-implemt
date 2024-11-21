`timescale 1ns / 1ps
module Booth_top #(
    parameter INPUT_WIDTH = 8,
    parameter NUM_CODE_WIDTH = 5,
    parameter MATRIX_SIZE = 3,
    parameter OUTPUT_WIDTH=$clog2(MATRIX_SIZE*(2**INPUT_WIDTH))-1
) (
    input clk,
    input reset_n,
    input signed [INPUT_WIDTH-1:0] input_q,
    input signed [INPUT_WIDTH-1:0] input_q_rev,
    input signed [INPUT_WIDTH-1:0] input_k,
    input signed [OUTPUT_WIDTH-1:0] left_final_partialmul_out, // 从左侧PE读取的最终部分乘积
    output signed [OUTPUT_WIDTH-1:0] final_partialmul_out,
    
    // output [3:0]target_count_show,
    input PE_right_read_req,PE_left_read_ready,//数据必须保证是每一行第一个算完之后加上的
    output PE_left_read_req,PE_right_read_ready
);
localparam first_PE_ready=1;
localparam first_PE_latency=0;

    // wire clk_en; // Enable signal for FIFO writing

    // Fixed NUM_CODE values for each Booth_MUL stage
    wire [NUM_CODE_WIDTH-1:0] NUM_CODE_0, NUM_CODE_1, NUM_CODE_2, NUM_CODE_3;
    wire signed    [OUTPUT_WIDTH-1:0]   buffer_read;
    wire buffer_left_read_req,buffer_right_read_ready;
    assign final_partialmul_out=(input_k&input_q)?buffer_read:left_final_partialmul_out;
    assign PE_left_read_req=(input_k&input_q)?buffer_left_read_req:PE_right_read_req;
    assign PE_right_read_ready=(input_k&input_q)?buffer_right_read_ready:PE_left_read_ready;
wire inner_reset;
assign inner_reset=(input_k==0)?1'b1:1'b0;
//==================================pipeline=======================================
    wire signed [OUTPUT_WIDTH-1:0] partialmul_out_0;
    wire signed [OUTPUT_WIDTH-1:0] partialmul_out_1;
    wire signed [OUTPUT_WIDTH-1:0] partialmul_out_2;
    wire signed [OUTPUT_WIDTH-1:0] partialmul_out_3;
    wire signed [INPUT_WIDTH-1:0] q_next_0;
    wire signed [INPUT_WIDTH-1:0] q_rev_next_0;
    wire signed [INPUT_WIDTH-1:0] q_next_1;
    wire signed [INPUT_WIDTH-1:0] q_rev_next_1;
    wire signed [INPUT_WIDTH-1:0] q_next_2;
    wire signed [INPUT_WIDTH-1:0] q_rev_next_2;

//==================================booth encoder====================================
    Booth_Encoder booth_enc0 (
        .input_num($unsigned(input_k[7:5])), // 取低3位作为输入
        .NUM_CODE(NUM_CODE_0)
    );

    Booth_Encoder booth_enc1 (
        .input_num($unsigned(input_k[5:3])), // 下一组
        .NUM_CODE(NUM_CODE_1)
    );

    Booth_Encoder booth_enc2 (
        .input_num($unsigned(input_k[3:1])), // 再下一组
        .NUM_CODE(NUM_CODE_2)
    );

    Booth_Encoder booth_enc3 (
        .input_num({$unsigned(input_k[1:0]), 1'b0}), // 最后一组
        .NUM_CODE(NUM_CODE_3)
    );
    // assign clk_en=(input_k)?clk:0;


//==================================booth MUL with pipeline design==============================
    Booth_MUL #(                    .MATRIX_SIZE(MATRIX_SIZE),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH),.INPUT_WIDTH(INPUT_WIDTH), .NUM_CODE_WIDTH(NUM_CODE_WIDTH)) Booth_MUL_0 (
        .clk(clk),
        .reset_n(reset_n),
        .input_q(input_q),
        .input_q_rev(input_q_rev),
        .NUM_CODE(NUM_CODE_0),
        .input_partialmul({OUTPUT_WIDTH{1'b0}}),
        .partialmul_out(partialmul_out_0),
        .input_q_next(q_next_0),
        .input_q_rev_next(q_rev_next_0)
    );

    Booth_MUL #(                    .MATRIX_SIZE(MATRIX_SIZE),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH),.INPUT_WIDTH(INPUT_WIDTH), .NUM_CODE_WIDTH(NUM_CODE_WIDTH)) Booth_MUL_1 (
        .clk(clk),
        .reset_n(reset_n),
        .input_q(q_next_0),
        .input_q_rev(q_rev_next_0),
        .NUM_CODE(NUM_CODE_1),
        .input_partialmul(partialmul_out_0),
        .partialmul_out(partialmul_out_1),
        .input_q_next(q_next_1),
        .input_q_rev_next(q_rev_next_1)
    );

    Booth_MUL #(                    .MATRIX_SIZE(MATRIX_SIZE),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH),.INPUT_WIDTH(INPUT_WIDTH), .NUM_CODE_WIDTH(NUM_CODE_WIDTH)) Booth_MUL_2 (
        .clk(clk),
        .reset_n(reset_n),
        .input_q(q_next_1),
        .input_q_rev(q_rev_next_1),
        .NUM_CODE(NUM_CODE_2),
        .input_partialmul(partialmul_out_1),
        .partialmul_out(partialmul_out_2),
        .input_q_next(q_next_2),
        .input_q_rev_next(q_rev_next_2)
    );

    Booth_MUL #(                    .MATRIX_SIZE(MATRIX_SIZE),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH),.INPUT_WIDTH(INPUT_WIDTH), .NUM_CODE_WIDTH(NUM_CODE_WIDTH)) Booth_MUL_3 (
        .clk(clk),
        .reset_n(reset_n),
        .input_q(q_next_2),
        .input_q_rev(q_rev_next_2),
        .NUM_CODE(NUM_CODE_3),
        .input_partialmul(partialmul_out_2),
        .partialmul_out(partialmul_out_3),
         .input_q_next(),
        .input_q_rev_next()
    );
    
//==================================buffer====================================
// assign PE_left_read_req=(partialmul_out_3)?1:0;

    SPad #(                   
                    .MATRIX_SIZE(MATRIX_SIZE),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH),
                     .ADDR_BITWIDTH(3)) spad (
    .clk(clk),
    .inner_reset(inner_reset),
    .reset_n(reset_n),
    .read_req(PE_right_read_req),//右侧发送读取请求
    .PE_left_read_ready(PE_left_read_ready),//闻讯左侧准备情况
    .w_data(partialmul_out_3),
    .r_data(buffer_read),
    .Read_ready(buffer_right_read_ready),
    .PE_left_read_req(buffer_left_read_req),
    .left_final_partialmul_out(left_final_partialmul_out)
);

endmodule
