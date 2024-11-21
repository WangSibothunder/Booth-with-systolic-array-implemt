module Booth_Encoder #(
    parameter radix = 3
) (
    input [radix-1:0] input_num,
    output reg [5-1:0] NUM_CODE // 0x, 2x, -2x, 1x_dummy, -1x_dummy
);
    always @(*) begin
        case (input_num)
            3'b000, 3'b111: NUM_CODE = 5'b10000;
            3'b001, 3'b010: NUM_CODE = 5'b00010;
            3'b101, 3'b110: NUM_CODE = 5'b00001;
            3'b011: NUM_CODE = 5'b01000;
            3'b100: NUM_CODE = 5'b00100;
        endcase
    end
endmodule
