module OutputBuffer #(
    parameter MATRIX_SIZE = 3,
    parameter INPUT_WIDTH=8,
    parameter ADDR_WIDTH = $clog2(MATRIX_SIZE**2<<2),
    parameter OUTPUT_WIDTH = $clog2(MATRIX_SIZE*(2**INPUT_WIDTH))-1
)(
    input clk,
    input reset_n,
    input read_en,
    input [ADDR_WIDTH-1:0] READ_ADDR,
    input [MATRIX_SIZE-1:0] write_enable, // 每个写入口的使能信号
    input [OUTPUT_WIDTH*MATRIX_SIZE-1:0] QK_RESULT , // 输入数据
    // output reg signed [(OUTPUT_WIDTH-1)*MATRIX_SIZE-1:0] buffer_output, // 输出缓冲区
    output [MATRIX_SIZE-1:0] IS_FULL,
    output reg [MATRIX_SIZE*OUTPUT_WIDTH-1:0] QK_RESULT_READ

);
reg [MATRIX_SIZE-1:0] result_Qiter;
//===================================================
//                  Internal Signals
//===================================================
reg [OUTPUT_WIDTH-1:0] BUFFER [4*MATRIX_SIZE-1:0][MATRIX_SIZE-1:0]; // 内部缓冲区
reg [$clog2(MATRIX_SIZE)-1:0] write_counter [MATRIX_SIZE-1:0];
reg [MATRIX_SIZE-1:0] done;
//===================================================
//                  Buffer Logic
//===================================================

assign IS_FULL = done;

integer i,j;
always @(posedge clk or negedge  reset_n) begin
    if (~reset_n) begin
        // buffer_output <= 0;
        done<=0;
        QK_RESULT_READ<=0;
        for(i=0;i<MATRIX_SIZE;i=i+1)begin
            write_counter[i]<=0;
        end
        for(i=0;i<MATRIX_SIZE;i=i+1) for(j=0;j<4*MATRIX_SIZE;j=j+1) BUFFER[i][j]<=0;
        result_Qiter<=0;
    end else begin  
            if(write_enable) begin 
            for(i=0;i<MATRIX_SIZE;i=i+1)begin
                if(write_enable[i]) begin             
                    if(write_counter[i]<MATRIX_SIZE) begin
                        write_counter[i]<=write_counter[i]+1;
                        BUFFER[i+MATRIX_SIZE*result_Qiter][write_counter[i]]<=QK_RESULT[(MATRIX_SIZE-i)*OUTPUT_WIDTH-1-:OUTPUT_WIDTH];
                        if(write_counter[i]==MATRIX_SIZE-1) done[i]<=1;              
                end
                end 
                end
                     
    end 
            
            else if(done)begin 
                done<=0;
                result_Qiter<=result_Qiter+1'b1;
                for(i=0;i<MATRIX_SIZE;i=i+1)begin
                    write_counter[i]<=0;
                end
            end
        if(read_en) begin
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                // 从 K_BUFFER 中读取数据
                QK_RESULT_READ[(MATRIX_SIZE-i) * OUTPUT_WIDTH -1 -: OUTPUT_WIDTH] <= BUFFER[READ_ADDR][i];//ADDR锁定是哪一行
        end
    end

    end
end
endmodule
