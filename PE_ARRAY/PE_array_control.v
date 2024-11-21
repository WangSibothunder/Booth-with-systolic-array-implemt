module Array_control#(
    parameter INPUT_WIDTH = 8,
    parameter NUM_CODE_WIDTH = 5,
    parameter MATRIX_SIZE = 3,
    parameter ADDR_WIDTH = $clog2(MATRIX_SIZE**2<<2),  //Q,K的buffer各自先存四个矩阵
    parameter OUTPUT_WIDTH=$clog2(MATRIX_SIZE*(2**INPUT_WIDTH))-1
)(
    input start,clk,reset_n,ARRAY_module_sel,
    input       [MATRIX_SIZE-1:0] IS_FULL,
    input        [INPUT_WIDTH*MATRIX_SIZE-1:0]      buffer_input_q,//一次读入一列
    input        [INPUT_WIDTH*MATRIX_SIZE*MATRIX_SIZE-1:0]           buffer_input_k,

    output reg         buffer_read_K_EN,buffer_read_Q_EN,
    output reg      [MATRIX_SIZE-1:0]        write_enable,state,
    output reg     [ADDR_WIDTH-1:0]        buffer_K_addr,buffer_Q_addr,
    output   [MATRIX_SIZE*OUTPUT_WIDTH-1:0]             QK_RESULT
);
//===================================================
//                 Station Machine
//===================================================
// reg [3-1:0] state;
localparam IDLE=3'd0;
localparam LOAD=3'd1;
localparam ROLLING=3'd2;
localparam WAIT=3'd3;
localparam write=3'd4;
localparam HANDSHAKE=3'd5;

//=================================================
//                 Read Pointer
//==============================================
reg [ADDR_WIDTH-1:0] Q_iter,K_iter;
localparam K_ADDR=0;
localparam Q_ADDR=$clog2(MATRIX_SIZE**2<<1);

reg  [INPUT_WIDTH*MATRIX_SIZE-1:0] input_q;
reg  [INPUT_WIDTH*MATRIX_SIZE*MATRIX_SIZE-1:0] input_k;
integer i;

//=================================================
//              buffer write logic
//=================================================

// reg reset_inner ;


//===================================================
//                  PE Array
//===================================================
wire [OUTPUT_WIDTH*MATRIX_SIZE-1:0] final_partialmul_out;
    PE_Array #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .NUM_CODE_WIDTH(NUM_CODE_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) pe_array_inst (
        .clk(clk),
        .reset_n(reset_n),
        .input_q(input_q),
        .input_k(input_k),
        .final_partialmul_out(final_partialmul_out)
    );

//=======================================================
//                   Control
//=======================================================

reg [MATRIX_SIZE*OUTPUT_WIDTH-1:0] reg_QK_result;
assign QK_RESULT=reg_QK_result;
always @(posedge clk or negedge reset_n) begin
    if(!reset_n)begin 
        // reset_inner<=0;
        state<=IDLE;
        input_k<=0;
        input_q<=0;
        Q_iter<=0;
        K_iter<=0;
        buffer_read_K_EN<=0;
        buffer_read_Q_EN<=0;
        reg_QK_result<=0;
        write_enable<=0;
        buffer_Q_addr<=0;
        buffer_K_addr<=0;
    end
    else case (state)
    IDLE: begin
        if(start) begin 
            // reset_inner<=1;
            state<=HANDSHAKE;  
            buffer_read_K_EN<=1;
            buffer_read_Q_EN<=1;
            buffer_Q_addr<=Q_iter;//Q一次读取1列
            buffer_K_addr<=K_iter*MATRIX_SIZE;//K一次读取一个矩阵
            K_iter<=K_iter+1;
            Q_iter<=Q_iter+1;
        end
        else begin 
            state<=state;
        input_k<=0;
        input_q<=0;
        Q_iter<=0;
        K_iter<=0;
        buffer_read_K_EN<=0;
        buffer_read_Q_EN<=0;
        reg_QK_result<=0;
        write_enable<=0;
        buffer_Q_addr<=0;
        buffer_K_addr<=0;
        // reset_inner<=0;
        end
    end
    HANDSHAKE: state<=LOAD;
    LOAD: begin : LOAD_Q_and_K
        state<=ROLLING;  
        input_k<=buffer_input_k;
        input_q<=buffer_input_q;
        buffer_Q_addr<=Q_iter;//Q一次读取1列
        Q_iter<=Q_iter+1;
        buffer_read_K_EN<=0;
    end
    ROLLING:begin
        if(Q_iter<MATRIX_SIZE*2-1) begin : LOAD_Q
            buffer_Q_addr<=Q_iter;//Q一次读取1列
            Q_iter<=Q_iter+1;
            input_q<=buffer_input_q;    
        end
        else begin //全部注入,等待时齐
            state<=WAIT;
            buffer_read_Q_EN<=0;
        end
    end

    WAIT:begin
            reg_QK_result<= final_partialmul_out;
            for(i=0;i<MATRIX_SIZE;i=i+1) begin
                if(final_partialmul_out[(MATRIX_SIZE-i)*OUTPUT_WIDTH-1-:OUTPUT_WIDTH]) begin 
                    if(~IS_FULL[i]) write_enable[i]<=1;
                    else begin 
                        write_enable[i]<=0;                       
                    end
                end
        end
        if(IS_FULL=={MATRIX_SIZE{1'b1}}) state<=IDLE;
    end
endcase
end




























































endmodule
