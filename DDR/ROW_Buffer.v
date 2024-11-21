module row_buffer #(
    parameter INPUT_WIDTH = 8,         // 输入数据宽度
    parameter MATRIX_SIZE = 3,         // 矩阵大小
    parameter ADDR_WIDTH = $clog2(MATRIX_SIZE**2<<2) // 缓冲区地址宽度
)(
    input clk,
    input reset_n,
    input write_en, Q_S_sel,                           // 写入使能信号和选择信号
    input [MATRIX_SIZE*INPUT_WIDTH-1:0] ROW_INPUT,  // softmax 输出
    input read_en,                                     // 读取使能信号
    input [ADDR_WIDTH-1:0] read_addr,                  // 读取地址

    output reg [MATRIX_SIZE*INPUT_WIDTH-1:0] read_data      // 读取的数据
);

    //===================================================
    //              Internal Registers and Signals
    //===================================================
    reg [MATRIX_SIZE*INPUT_WIDTH-1:0] buffer_data [4*MATRIX_SIZE+2-1:0]; // 数据存储缓冲区
    integer j;

//==================================
//                              for tb
//===================================
// initial begin 
// buffer_data[0]<={8'sd1,8'sd0,8'sd0};
// buffer_data[1]<={8'sd2,8'sd1,8'sd0};
// buffer_data[2]<={8'sd3,8'sd2,8'sd1};
// buffer_data[3]<={8'sd1,8'sd3,8'sd2};
// buffer_data[4]<={8'sd3,8'sd3,8'sd3};
// buffer_data[5]<={8'sd3,8'sd0,8'sd0};
// buffer_data[6]<={8'sd0,8'sd0,8'sd0};
// buffer_data[7]<={8'sd0,8'sd0,8'sd0};
// buffer_data[8]<={8'sd0,8'sd0,8'sd0};
// buffer_data[9]<={8'sd0,8'sd0,8'sd0};
// end



    //===================================================
    //              Initialization and Reset
    //===================================================
    always @(posedge clk or negedge  reset_n) begin
        if (~reset_n) begin
            // 复位时，清空缓冲区
           for (j = 0; j < 4 * MATRIX_SIZE+2; j = j + 1) begin
               buffer_data[j] <= {MATRIX_SIZE*INPUT_WIDTH{1'b0}};
           end
            read_data <= {INPUT_WIDTH{1'b0}};
        end
        else begin 
            if (write_en) begin
            // write_en 为有效时，存储 softmax 输出，保持错位存储逻辑
            if (Q_S_sel == 0) begin // 存储 Q
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    buffer_data[buffer_data[4*MATRIX_SIZE+2-1-1] + j][(MATRIX_SIZE - j) * INPUT_WIDTH - 1 -: INPUT_WIDTH] 
                        <= ROW_INPUT[(MATRIX_SIZE - j) * INPUT_WIDTH - 1 -: INPUT_WIDTH];
                end
                buffer_data[4*MATRIX_SIZE+2-1-1] <= buffer_data[4*MATRIX_SIZE+2-1-1] + 1; // 更新 Q 偏移量
            end
            else begin // 存储 S
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    buffer_data[buffer_data[4*MATRIX_SIZE+2-1] + j + MATRIX_SIZE * 2][(MATRIX_SIZE - j) * INPUT_WIDTH - 1 -: INPUT_WIDTH] 
                        <= ROW_INPUT[(MATRIX_SIZE - j) * INPUT_WIDTH - 1 -: INPUT_WIDTH]; // S 存储在后半部分
                end
                buffer_data[4*MATRIX_SIZE+2-1] <= buffer_data[4*MATRIX_SIZE+2-1] + 1; // 更新 S 偏移量
            end
        end
         if (read_en) begin
            // 如果读取使能信号有效，根据 read_addr 提供数据
            if(Q_S_sel==0) read_data <= buffer_data[read_addr];
            else read_data <= buffer_data[read_addr+MATRIX_SIZE * 2] ;
        end
        end end
endmodule
