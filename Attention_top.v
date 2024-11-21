module Attention_top #(
    parameter INPUT_WIDTH = 8,
    parameter NUM_CODE_WIDTH = 5,
    parameter MATRIX_SIZE = 3,
    parameter ADDR_WIDTH = $clog2(MATRIX_SIZE**2<<2), 
    parameter OUTPUT_WIDTH = $clog2(MATRIX_SIZE*(2**INPUT_WIDTH))-1
)(
    input clk,
    input reset_n,
    input start,
    input softmax_req,DATA_write_EN,
    input  [INPUT_WIDTH*MATRIX_SIZE-1:0] Q_INPUT,
    input [INPUT_WIDTH*MATRIX_SIZE-1:0] MATRIX_INPUT,
    output reg [MATRIX_SIZE*OUTPUT_WIDTH-1:0] Output_RESULT,
    input output_req

    
);
wire [MATRIX_SIZE-1:0] IS_FULL;
wire [ADDR_WIDTH-1:0] K_V_addr, Q_S_addr;
wire [MATRIX_SIZE*OUTPUT_WIDTH-1:0] QK_RESULT;
wire [2:0] state;
reg [ADDR_WIDTH-1:0] READ_ADDR;
wire [MATRIX_SIZE-1:0] write_enable;
wire [INPUT_WIDTH*MATRIX_SIZE*MATRIX_SIZE-1:0] MATRIX_OUTPUT;
wire [OUTPUT_WIDTH*MATRIX_SIZE-1:0] output_buffer_READ_VALUE;
wire [INPUT_WIDTH*MATRIX_SIZE-1:0] Q_S_date;
wire  [INPUT_WIDTH*MATRIX_SIZE-1:0] Q_S_INPUT;
    // Internal signals
    wire [MATRIX_SIZE*INPUT_WIDTH-1:0] softmax_outputs_fxp;
    reg softmax_enable;
    wire [MATRIX_SIZE*32-1:0] softmax_inputs;
    wire [MATRIX_SIZE*32-1:0] softmax_outputs;
    wire softmax_ready;
    wire K_V_read_EN;
wire Q_S_read_EN;
    reg output_buffer_READ_EN;
    reg [ADDR_WIDTH-1:0] output_buffer_READ_ADDR;
    // wire [OUTPUT_WIDTH*MATRIX_SIZE-1:0] output_buffer_READ_VALUE;
    reg [4-1:0]process_cnt;

    wire Q_S_sel, K_V_sel;
    assign Q_S_sel = 0;
    assign K_V_sel = 0;


    wire Q_S_write_EN_inner;
    assign Q_S_INPUT =Q_INPUT;
    assign Q_S_write_EN_inner =DATA_write_EN;
    //===================================================
    // Instantiate Array_control module
    //===================================================

    Array_control #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .NUM_CODE_WIDTH(NUM_CODE_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) array_control_inst (
        .start(start),
        .clk(clk),
        .reset_n(reset_n),
        // .ARRAY_module_sel(softmax_req),
        .IS_FULL(IS_FULL),
        .buffer_input_q(Q_S_date),
        .buffer_input_k(MATRIX_OUTPUT),
        .buffer_read_K_EN(K_V_read_EN),
        .buffer_read_Q_EN(Q_S_read_EN),
        .write_enable(write_enable),
        .buffer_K_addr(K_V_addr),
        .buffer_Q_addr(Q_S_addr),
        .QK_RESULT(QK_RESULT),
        .state(state)
    );

    //===================================================
    // Instantiate K_buffer module
    //===================================================
    matrix_buffer #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) matrix_buffer_inst (
        .clk(clk),
        .reset_n(reset_n),
        .K_V_read_EN(K_V_read_EN),
        .K_V_write_EN(DATA_write_EN),
        .K_V_sel(K_V_sel),
        .K_V_addr(K_V_addr),
        .MATRIX_INPUT(MATRIX_INPUT),
        .MATRIX_OUTPUT(MATRIX_OUTPUT) // Output K matrix
    );

    row_buffer #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) row_buffer_inst (
        .clk(clk),
        .reset_n(reset_n),
        .write_en(Q_S_write_EN_inner),
        .Q_S_sel(Q_S_sel),
        .ROW_INPUT(Q_S_INPUT),
        .read_en(Q_S_read_EN),
        .read_addr(Q_S_addr),
        .read_data(Q_S_date) // Output Q matrix
    );
    //===================================================
    // Instantiate OutputBuffer module
    //===================================================
    OutputBuffer #(
        .MATRIX_SIZE(MATRIX_SIZE),
        .INPUT_WIDTH(INPUT_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) output_buffer_inst (
        .clk(clk),
        .reset_n(reset_n),
        .write_enable(write_enable),
        .QK_RESULT(QK_RESULT),
        .IS_FULL(IS_FULL), // Indicates buffer full
        .read_en(output_buffer_READ_EN),
        .READ_ADDR(output_buffer_READ_ADDR),
        .QK_RESULT_READ(output_buffer_READ_VALUE)
    );
// //rst
    //===================================================
    // Instantiate fxp2float module
    //===================================================
    genvar i;
    for(i=0; i<MATRIX_SIZE; i=i+1) begin
        fxp2float #(
            .MATRIX_SIZE(MATRIX_SIZE),
            .INPUT_WIDTH(INPUT_WIDTH),
            .OUTPUT_WIDTH(OUTPUT_WIDTH),
            .WII(OUTPUT_WIDTH),  // 7位整数部分
            .WIF(0)  // 0位小数部分
        ) fxp2float_inst (
            // .rstn(reset_n),
            // .clk(clk),
            .in(output_buffer_READ_VALUE[(MATRIX_SIZE-i)*OUTPUT_WIDTH-1-:OUTPUT_WIDTH]),
            .out(softmax_inputs[(MATRIX_SIZE-i)*32-1-:32])
        );
    end

    //===================================================
    // Instantiate float2fxp module
    //===================================================
    for(i=0; i<MATRIX_SIZE; i=i+1) begin
        float2fxp #(
            .WOI(1),  // 1位整数部分
            .WOF(7),  // 7位小数部分
            .ROUND(1) // 四舍五入
        ) float2fxp_inst (
            // .rstn(rstn),
            // .clk(clk),
            .in(softmax_outputs[(MATRIX_SIZE-i)*32-1-:32]),
            .out(softmax_outputs_fxp[(MATRIX_SIZE-i)*INPUT_WIDTH-1-:INPUT_WIDTH])
        );
    end

    //===================================================
    // Instantiate softmax module
    //===================================================
    softmax2 #(
        .MATRIX_SIZE(MATRIX_SIZE),
        .inputNum(MATRIX_SIZE),
        .DATA_WIDTH(32)
    ) softmax_inst (
        .clk(clk),
        .enable(softmax_enable),
        .inputs(softmax_inputs),
        .outputs(softmax_outputs),
        .ackSoft(softmax_ready)
    );
    // 控制逻辑
    reg [ADDR_WIDTH-1:0] output_READ_ADDR;

        always @(posedge clk or negedge reset_n) begin
        if(~reset_n) begin
            process_cnt <= 0;
            READ_ADDR <= 0; 
            softmax_enable <= 0;
            output_READ_ADDR<=0;
            Output_RESULT<=0;
        end

        else if(output_req) begin
            output_buffer_READ_EN<=1;
            output_buffer_READ_ADDR<=output_READ_ADDR;
            output_READ_ADDR<=output_READ_ADDR+1;
            Output_RESULT<=output_buffer_READ_VALUE;
            end

        else if(softmax_req&!DATA_write_EN) begin
            // if (process_cnt==0)begin
            //output_buffer_READ_EN <= 1;     
                
            // end
            if(process_cnt<MATRIX_SIZE) begin
            
            output_buffer_READ_ADDR <= READ_ADDR;        
            softmax_enable <= 1;  
            READ_ADDR <= READ_ADDR + 1;
            process_cnt <= process_cnt+1;
            end
            else begin
                // READ_ADDR <= 0 ;
                process_cnt<=0;
            output_buffer_READ_EN<=0;   
        end
        end 
        else begin
            output_READ_ADDR<=0;
            process_cnt <= 0;
            READ_ADDR <= 0 ;
            output_buffer_READ_EN<=0;   
            Output_RESULT<=0;
        end
    end

endmodule
