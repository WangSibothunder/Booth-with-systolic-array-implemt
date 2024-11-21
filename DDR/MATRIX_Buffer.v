module matrix_buffer #(
    parameter INPUT_WIDTH = 8,
    parameter MATRIX_SIZE = 3,
    parameter ADDR_WIDTH = $clog2(MATRIX_SIZE**2 << 2)
)(
    input clk,
    input reset_n,
    input K_V_read_EN, K_V_write_EN, K_V_sel,
    input [ADDR_WIDTH-1:0] K_V_addr, // K 的起始地址
    input signed [INPUT_WIDTH*MATRIX_SIZE-1:0] MATRIX_INPUT,
    output reg signed [INPUT_WIDTH*MATRIX_SIZE*MATRIX_SIZE-1:0] MATRIX_OUTPUT // 输出整个 K 矩阵
);

    //===================================================
    //                  Internal Signals
    //===================================================
    integer i, j;
    reg signed [INPUT_WIDTH*MATRIX_SIZE-1:0] BUFFER [(MATRIX_SIZE*4)-1:0]; // 分配 2 个矩阵空间

    // 用于记录写入的偏移量
    reg [ADDR_WIDTH-1:0] K_offset, S_offset;


//==================================
//                              for tb
//===================================
// initial begin 
// BUFFER[0]<={8'sd1,8'sd1,8'sd1};
// BUFFER[1]<={8'sd2,8'sd2,8'sd2};
// BUFFER[2]<={8'sd3,8'sd3,8'sd3};
// BUFFER[3]<={8'sd1,8'sd3,8'sd2};
// BUFFER[4]<={8'sd0,8'sd0,8'sd3};
// BUFFER[5]<={8'sd0,8'sd0,8'sd0};
// BUFFER[6]<={8'sd0,8'sd0,8'sd0};
// BUFFER[7]<={8'sd0,8'sd0,8'sd0};
// BUFFER[8]<={8'sd0,8'sd0,8'sd0};
// BUFFER[9]<={8'sd0,8'sd0,8'sd0};
// end
    //===================================================
    //                  Buffer Logic
    //===================================================
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            MATRIX_OUTPUT <= 0;
            K_offset <= 0;
            S_offset <= MATRIX_SIZE*2;
           for (j = 0; j < 4 * MATRIX_SIZE; j = j + 1) begin
               BUFFER[j] <= {MATRIX_SIZE*INPUT_WIDTH{1'b0}};
           end
        end
        else if (K_V_read_EN) begin
            // 读取 K 或 S 矩阵的值并拼接
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                if (K_V_sel == 0) begin // 读取 K
                    MATRIX_OUTPUT[(MATRIX_SIZE-i) * INPUT_WIDTH * MATRIX_SIZE -1 -: MATRIX_SIZE * INPUT_WIDTH] <= 
                        BUFFER[K_V_addr + i];
                end else begin // 读取 S
                    MATRIX_OUTPUT[(MATRIX_SIZE-i) * INPUT_WIDTH * MATRIX_SIZE -1 -: MATRIX_SIZE * INPUT_WIDTH] <= 
                        BUFFER[K_V_addr + i  + MATRIX_SIZE*2];
                end
            end
        end
        else if (K_V_write_EN) begin
            if (K_V_sel == 0) begin // 写入 K
                    BUFFER[K_offset ] <= MATRIX_INPUT;
                    K_offset <= K_offset + 1; // 更新 K 偏移量
            end else begin // 写入 S
                    BUFFER[S_offset] <= MATRIX_INPUT;
                    S_offset <= S_offset + 1; // 更新 S 偏移量
            end
        end
    end
endmodule
