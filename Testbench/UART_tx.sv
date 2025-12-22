
module UART_tx(
	input logic clk,
	input logic rst_n,
	input logic trmt,
	input logic [7:0] tx_data,
	output logic TX,
	output logic tx_done);

	// Control Signals 
	logic set_done, load, shift, transmitting;

	// Input Recieving Logic 
	
	reg [8:0] tx_shift_reg; // Shift register to hold the transmission bits 
	logic [8:0] d_tx_shift_reg; // Input to the shift register
	logic [1:0] in_ctrl; // Selection signal 

	always_comb begin 
		in_ctrl = {load, shift};
		casex (in_ctrl) 
			2'b00 : d_tx_shift_reg = tx_shift_reg;
			2'b01 : d_tx_shift_reg = {1'b1, tx_shift_reg[8:1]};
			2'b1? : d_tx_shift_reg = {tx_data, 1'b0};
		endcase

	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n) 
			tx_shift_reg <= {9{1'b1}};
		else 
			tx_shift_reg <= d_tx_shift_reg;
	end

	// Baud Counter 
	//
	reg [12:0] baud_cnt; // the baud counter --> needs to count upto 5208
	logic [12:0] baud_cnt_c;
	logic [1:0] baud_ctrl; // Baud counter control signal

	always_comb begin 
		baud_ctrl = {load|shift, transmitting};

		casex (baud_ctrl) 
			2'b00 : baud_cnt_c = baud_cnt;
			2'b01 : baud_cnt_c = baud_cnt + 1'b1;
			2'b1? : baud_cnt_c = 13'b0;
		endcase

		shift = (baud_cnt == 13'd5207);  // Don't shift until the baud counter has reached 5208 counts
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
		bit_cntrl = {load, shift};

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
	typedef enum reg {IDLE, TRANSMIT} state_t; // ENUM states for IDLE and TRANSMITTING
	state_t state, nxt_state;

	always_comb begin
		// Pre-setting signals 
		set_done = 1'b0;
		load = 1'b0;
		transmitting = 1'b0;
		nxt_state = state;

		case (state) 
			IDLE : begin 
				   nxt_state = trmt ? TRANSMIT : IDLE; // 
				   load = trmt;
				   set_done = 1'b1;
			end

			TRANSMIT : begin
				       nxt_state = (bit_cnt == 4'd9) & shift ? IDLE : TRANSMIT;
					   transmitting = 1'b1;
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

	assign TX = state == IDLE ? 1'b1 : tx_shift_reg[0]; // The output data is the LSB of the shift register

	// SR Flip Flop to set and reset
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			tx_done <= 1'b1;
		
		else if (load) 
			tx_done <= 1'b0;
		
		else if (set_done)
			tx_done <= 1'b1;
	end

endmodule
