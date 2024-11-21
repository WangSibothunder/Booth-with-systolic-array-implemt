`timescale 1ns / 1ps
module SPad #( 
    parameter MATRIX_SIZE = 3,
    parameter OUTPUT_WIDTH=$clog2(MATRIX_SIZE*(2**8))-1,
			 parameter ADDR_BITWIDTH = 3 )
		   ( input 		clk,
			 input 		reset_n,
			 input		inner_reset,
			 input 		read_req,PE_left_read_ready,
			 input signed 		[OUTPUT_WIDTH-1 : 0] 		w_data,
			 input signed 		[OUTPUT_WIDTH-1 : 0]		left_final_partialmul_out,
			 output signed 		[OUTPUT_WIDTH-1 : 0]		 r_data,
			 output reg 		Read_ready,PE_left_read_req
			 
    );
	
	reg signed [OUTPUT_WIDTH-1 : 0] mem [0 : (1 << ADDR_BITWIDTH) + 2]; 
	reg signed [OUTPUT_WIDTH-1 : 0] data;
	reg [ADDR_BITWIDTH:0] read_pointer,write_pointer,add_pointer;
/*
	状态分析:1. state_wait_other_latency :只存取由于时序产生的不对齐延时
			2. state_add_left :右侧PE没有准备好,但是左侧的时序已经对齐
*/
//==============================station machine========================

localparam state_wait_other_latency=0;
localparam state_add_left=1;
reg station;
integer i;
//==================================READ=====================================
	always@(posedge clk or negedge reset_n)
		begin : READ
			if(!reset_n) begin
				data <= 0;
				read_pointer<=0;
				
				 end
			else if(inner_reset) begin
					data <= 0;
				read_pointer<=0;
			end
			else if(Read_ready&&read_req) begin
					data <= mem[read_pointer];
					case (read_pointer)
						3'b000:read_pointer<=3'b001;
						3'b001:read_pointer<=3'b010;
						3'b010:read_pointer<=3'b011;
						3'b011:read_pointer<=3'b100;
						3'b100:read_pointer<=3'b101;
						3'b101:read_pointer<=3'b110;
						3'b110:read_pointer<=3'b111;
						3'b111:read_pointer<=4'b1001;
						4'b1001:read_pointer<=3'b000;
					endcase
			
			end
		end
	
	assign r_data = data;
//===============================write===========================
	always@(posedge clk or negedge reset_n)
		begin : WRITE
		if(!reset_n) begin 
			station<=state_wait_other_latency;
			write_pointer<=0;
			add_pointer<=0;
			Read_ready<=0;
			for(i=0;i<9;i=i+1) mem[i]<=0;
			PE_left_read_req<=0;end

		else if (inner_reset) begin 
			station<=state_wait_other_latency;
			write_pointer<=0;
			add_pointer<=0;
			Read_ready<=0;
			for(i=0;i<9;i=i+1) mem[i]<=0;
			PE_left_read_req<=0;end
		else if(w_data) begin
				if(PE_left_read_ready&PE_left_read_req) station<=1;
				PE_left_read_req<=1;

				mem[write_pointer] <= w_data;
				case (write_pointer)
						3'b000:write_pointer<=3'b001;
						3'b001:write_pointer<=3'b010;
						3'b010:write_pointer<=3'b011;
						3'b011:write_pointer<=3'b100;
						3'b100:write_pointer<=3'b101;
						3'b101:write_pointer<=3'b110;
						3'b110:write_pointer<=3'b111;
						3'b111:write_pointer<=4'b1001;
						4'b1001:write_pointer<=3'b000;
				endcase
//				if (left_final_partialmul_out&&PE_left_read_req) begin
                if (station) begin
					Read_ready<=1;
					mem[add_pointer] <= mem[add_pointer]+left_final_partialmul_out;
					case (add_pointer)
						3'b000:add_pointer<=3'b001;
						3'b001:add_pointer<=3'b010;
						3'b010:add_pointer<=3'b011;
						3'b011:add_pointer<=3'b100;
						3'b100:add_pointer<=3'b101;
						3'b101:add_pointer<=3'b110;
						3'b110:add_pointer<=3'b111;
						3'b111:add_pointer<=4'b1001;
						4'b1001:add_pointer<=3'b000;
				endcase end
		end
		end
endmodule
