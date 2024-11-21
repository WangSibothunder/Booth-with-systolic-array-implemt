module PE_Array #(
    parameter INPUT_WIDTH = 8,
    parameter NUM_CODE_WIDTH = 5,
    parameter MATRIX_SIZE = 3,
    parameter OUTPUT_WIDTH=$clog2(MATRIX_SIZE*(2**INPUT_WIDTH))-1
)(
    input clk,
    input reset_n,
    input [INPUT_WIDTH*MATRIX_SIZE-1:0] input_q, // Q array
    input [INPUT_WIDTH*MATRIX_SIZE*MATRIX_SIZE-1:0] input_k, // K matrix
    output [OUTPUT_WIDTH*MATRIX_SIZE-1:0] final_partialmul_out  // Output array
);


    wire signed [OUTPUT_WIDTH-1:0] left_final_partialmul_out [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    wire [0:0] read_req [0:MATRIX_SIZE-1][0:MATRIX_SIZE];
    wire [0:0] read_ready [0:MATRIX_SIZE-1][0:MATRIX_SIZE];
    // Generate PE array
    genvar i, j;
    generate
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin : row
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin : col
                Booth_top #(
                    .INPUT_WIDTH(INPUT_WIDTH),
                    .NUM_CODE_WIDTH(NUM_CODE_WIDTH),
                    .MATRIX_SIZE(MATRIX_SIZE),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH)
                ) pe (
                    .clk(clk),
                    .reset_n(reset_n),
                    .input_q(input_q[INPUT_WIDTH*(MATRIX_SIZE-j)-1-:INPUT_WIDTH]), // Current row of Q
                    .input_q_rev(-input_q[INPUT_WIDTH*(MATRIX_SIZE-j)-1-:INPUT_WIDTH]), // 2's complement for negation
                    .input_k(input_k[INPUT_WIDTH*(MATRIX_SIZE*MATRIX_SIZE-MATRIX_SIZE*i-j)-1-:INPUT_WIDTH]), // Current element of K
                    .left_final_partialmul_out(j > 0 ? left_final_partialmul_out[i][j-1] : 1'b0), // Output from previous row
                    .final_partialmul_out(left_final_partialmul_out[i][j]), // Final output for this PE
                    .PE_left_read_req(read_req[i][j]),
                    .PE_right_read_req(j != (MATRIX_SIZE-1) ? read_req[i][j+1] : 1'b1),
                    .PE_left_read_ready(j > 0 ? read_ready[i][j] : 1'b1),
                    .PE_right_read_ready(read_ready[i][j+1])
                );
                if(j==MATRIX_SIZE-1) assign final_partialmul_out[(MATRIX_SIZE-i)*OUTPUT_WIDTH-1-:OUTPUT_WIDTH]=left_final_partialmul_out[i][j];
            end
        end
    endgenerate
endmodule
