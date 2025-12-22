module UART_rx (
	input logic clk,
	input logic rst_n,
	input logic RX,
	input logic clr_rdy, 
	output logic [7:0] rx_data,
	output logic rdy);

	// Control Signals
	logic start, shift, receiving, set_rdy;

	// Data Recieving Logic 
	reg [8:0] rx_shift_reg;
	logic [8:0] d_rx_shift_reg;
	logic RX_ff1, RX_ff2;

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			RX_ff1 <= 1'b1;
			RX_ff2 <= 1'b1;
		end

		else begin
			RX_ff1 <= RX;
			RX_ff2 <= RX_ff1;
		end
	end

	assign d_rx_shift_reg = shift ? {RX_ff2, rx_shift_reg[8:1]} : rx_shift_reg;

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n)
			rx_shift_reg <= {9{1'b1}};
		else 
			rx_shift_reg <= d_rx_shift_reg;
	end

	// Baud Counter 
	//
	reg [12:0] baud_cnt; // the baud counter --> needs to count upto 5208
	logic [12:0] baud_cnt_c;
	logic [1:0] baud_ctrl; // Baud counter control signal

	always_comb begin 
		baud_ctrl = {start|shift, receiving};

		casex (baud_ctrl) 
			2'b00 : baud_cnt_c = baud_cnt;
			2'b01 : baud_cnt_c = baud_cnt - 1'b1;
			2'b1? : baud_cnt_c = start ? 13'd2604 : 13'd5207;
		endcase

		shift = (baud_cnt == 13'd0);  // Don't shift until the baud counter has reached half of 5208 counts
	end
	
	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n) 
			baud_cnt <= 0;
		else 
			baud_cnt <= baud_cnt_c;
	end 


	// Bit counter 
	//
	reg [3:0] bit_cnt; // Bit counter register
	logic [3:0] bit_cnt_c; // Bit counter combitional logic 
	logic [1:0] bit_cntrl; // bit cntrl logic selector 

	always_comb begin 
		bit_cntrl = {start, shift};

		casex (bit_cntrl) 
			2'b00 : bit_cnt_c = bit_cnt;
			2'b01 : bit_cnt_c = bit_cnt + 1'b1;
			2'b1? : bit_cnt_c = 4'b0;
		endcase

	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n) 
			bit_cnt <= 4'b0;
		else 
			bit_cnt <= bit_cnt_c;
	end
	
	// FSM logic 
	typedef enum reg {IDLE, RECEIVE} state_t; // ENUM states for IDLE and TRANSMITTING
	state_t state, nxt_state;

	always_comb begin
		// Pre-setting signals 
		set_rdy = 1'b0;
		start = 1'b0;
		receiving = 1'b0;
		nxt_state = state;

		case (state) 
			IDLE : begin 
				   nxt_state = ~RX_ff2 ? RECEIVE : IDLE; // 
				   start = ~RX_ff2;
				   //set_rdy = 1'b1;
			end

			RECEIVE : begin
				       nxt_state = (bit_cnt == 4'd9) & shift ? IDLE : RECEIVE;
				       set_rdy   = (bit_cnt == 4'd9) & shift;
				       receiving = 1'b1;
			end

			// No default case since both the bits are covered here 

		endcase

	end

	// To hold the state of the FSM
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			state <= IDLE;

		else 
			state <= nxt_state;
	end

	// OUTPUTS of UART

	assign rx_data = rx_shift_reg[7:0]; // The output data is the LSB 8 bits of the shift register

	// SR Flip Flop to set and reset
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			rdy <= 1'b1;
		
		else if (start | clr_rdy) 
			rdy <= 1'b0;
		
		else if (set_rdy)
			rdy <= 1'b1;
	end

endmodule

