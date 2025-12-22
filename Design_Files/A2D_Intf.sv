module A2D_intf (
	input logic clk,
	input logic rst_n,
	input logic nxt,
	output logic [11:0] lft_ld,
	output logic [11:0] rght_ld,
	output logic [11:0] steer_pot,
	output logic [11:0] batt,
	output logic SS_n,
	output logic SCLK,
	output logic MOSI,
	input logic MISO);

	typedef enum logic [1:0] {IDLE, FLIGHT_1, LAYOVER, FLIGHT_2  } state_t;
	state_t state, nxt_state;

	// SM outputs
	logic update, en_channel;
	logic en_channel0, en_channel4, en_channel5, en_channel6;

	//////////////////// SPI MONARCH /////////////////////////////

	logic wrt, done;
	logic [15:0] wt_data, rd_data;

	SPI_mnrch SPI(.clk(clk), .rst_n(rst_n), .wrt(wrt), .wt_data(wt_data), .MISO(MISO), .MOSI(MOSI), .SCLK(SCLK), .SS_n(SS_n),
				.rd_data(rd_data), .done(done));

	////////////////////////////////////////////////////////////

	///////////////// Round Robin Counter ///////////////////////
	logic [1:0] rr_arb;

	// Choosing which channel to update based off the round robin counter value
	always_comb begin

		en_channel0 = 1'b0;
		en_channel4 = 1'b0;
		en_channel5 = 1'b0;
		en_channel6 = 1'b0;

		case (rr_arb)
			2'b00 : begin
					en_channel0 = en_channel; // only enable if the SPI is done recieving 
					wt_data     = {2'b00, 3'd0, 11'h000};
			end
			2'b01 : begin
				    en_channel4 = en_channel;
					wt_data     = {2'd00, 3'd4, 11'h000};
			end
			2'b10 : begin
				    en_channel5 = en_channel;
					wt_data     = {2'b00, 3'd5, 11'h000};
			end
			2'b11 : begin
				    en_channel6 = en_channel;
					wt_data     = {2'b00, 3'd6, 11'h000};
			end
		endcase

	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			rr_arb <= 0; // goes to channel 0 at reset
		else if (update)
			rr_arb <= rr_arb + 2'd1; // update the round robin arbiter by increasing it by one 
	end

	/////////////////////////////////////////////////////////////
	
	///////////////////// Update Channel ///////////////////////
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			lft_ld    <= 0;

		else if (en_channel0)
			lft_ld <= rd_data[11:0];
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			rght_ld   <= 0;
			
		else if (en_channel4)
			rght_ld <= rd_data[11:0];
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			steer_pot <= 0;
	
		else if (en_channel5)
			steer_pot <= rd_data[11:0];
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			batt      <= 0;

		else if (en_channel6)
			batt <= rd_data[11:0];
	end
	///////////////////////////////////////////////////////

	///////////// STATE MACHINE ////////////////////////

	//logic [3:0] wait_ff, wait_c; // Wait for the other SPI module to chill

	always_comb begin
		update = 1'b0;
		wrt    = 1'b0; 
		nxt_state = state;
		en_channel = 1'b0;
		//wait_c = 4'b0;

		case(state)
			IDLE : begin
					if (nxt) begin
						wrt = 1'b1;
						nxt_state = FLIGHT_1;
					end
			end

			FLIGHT_1 : begin
						if (done) 
							nxt_state = LAYOVER;
			end

			LAYOVER : begin
						//nxt_state = &wait_ff ? FLIGHT_2 : LAYOVER;
						nxt_state = FLIGHT_2;
						wrt = 1'b1;
						//wait_c = wait_ff + 1'b1;
			end

			FLIGHT_2 : begin
						if (done) begin
							nxt_state = IDLE;
							update = 1'b1;
							en_channel = 1'b1;
						end
			end
		endcase

	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			state <= IDLE;
			//wait_ff <= 0;
		end
		else begin
			state <= nxt_state;
			//wait_ff <= wait_c;
		end
	end
	


endmodule
