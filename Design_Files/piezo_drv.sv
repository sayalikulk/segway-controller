module piezo_drv #(parameter fastSim = 1) (
	input logic clk, 
	input logic rst_n,
	input logic en_steer,
	input logic too_fast,
	input logic batt_low,
	output logic piezo,
	output logic piezo_n);

	localparam [14:0] G6_freq = 15'd31888;
	localparam [14:0] C7_freq = 15'd23890;
	localparam [14:0] E7_freq = 15'd18961;
	localparam [14:0] G7_freq = 15'd15944;

	localparam [14:0] G6_freq_by2 = G6_freq/2;
	localparam [14:0] C7_freq_by2 = C7_freq/2;
	localparam [14:0] E7_freq_by2 = E7_freq/2;
	localparam [14:0] G7_freq_by2 = G7_freq/2;
	
	logic [24:0] duration_timer;

	logic [27:0] repeat_timer; // 3 seconds --> 50MHz == 150,000,000 cycles

	logic [14:0] period_timer;

	logic clr_duration, clr_period, clr_repeat; //signals to clear the signals for duration and period timer
	logic en_repeat, en_duration, en_period; // Signal to enable the counters

	assign en_repeat = en_steer || batt_low;
	assign clr_repeat   = (repeat_timer >= 28'd149999999) | ~en_repeat;

	generate 
		if (fastSim == 1)
			counters_quick counters(.clk(clk), .rst_n(rst_n), .clr_duration(clr_duration), .clr_period(clr_period), .clr_repeat(clr_repeat),
									.en_duration(en_duration), .en_repeat(en_repeat), .en_period(en_period), .duration_timer(duration_timer),
									.repeat_timer(repeat_timer), .period_timer(period_timer));
		else 
			counters_slow counters(.clk(clk), .rst_n(rst_n), .clr_duration(clr_duration), .clr_period(clr_period), .clr_repeat(clr_repeat),
								   .en_duration(en_duration), .en_repeat(en_repeat), .en_period(en_period), .duration_timer(duration_timer),
								   .repeat_timer(repeat_timer), .period_timer(period_timer));
	endgenerate 

	typedef enum logic [2:0] {IDLE, G6, C7, E7_1, G7_1, E7_2, G7_2} state_t;
	state_t state, nxt_state;

	logic duration_time_hit;
	logic direction_reg, direction_reg_c;

	always_comb begin 
		
		clr_duration = 1'b0;
		clr_period   = 1'b0;
		nxt_state    = state;
		en_duration  = 1'b0;
		en_period    = 1'b0;
		duration_time_hit = 1'b0;
		direction_reg_c = direction_reg;

		piezo = 1'b0;

		case (state)

			IDLE : begin
				if (too_fast || ((en_steer&~batt_low)&&(clr_repeat || ~|repeat_timer)))  begin
					nxt_state = G6;
					clr_period = 1'b1;
					clr_duration = 1'b1;
					direction_reg_c = 1'b0;
				end

				else if (batt_low&&(clr_repeat || ~|repeat_timer)) begin
					nxt_state = G7_2;
					clr_period = 1'b1;
					clr_duration = 1'b1;
					direction_reg_c = 1'b1;
				end

			end

			G6  : begin
				en_duration = 1'b1;
				clr_period = (period_timer == G6_freq);
				en_period = !clr_period;
				piezo = (period_timer > G6_freq_by2);
				duration_time_hit = (duration_timer >= 25'h07fffff);
				clr_duration = duration_time_hit;

				if (duration_time_hit)
					nxt_state = direction_reg ? IDLE : C7;
			end

			C7 : begin
				en_duration = 1'b1;
				clr_period = (period_timer == C7_freq);
				en_period = !clr_period;
				piezo = (period_timer > C7_freq_by2);
				duration_time_hit = (duration_timer >= 25'h07fffff);
				clr_duration = duration_time_hit;

				if (duration_time_hit)
					nxt_state = direction_reg ? G6 : E7_1;

			end

			E7_1 : begin
				en_duration = 1'b1;
				clr_period = (period_timer == E7_freq);
				en_period = !clr_period;
				piezo = (period_timer > E7_freq_by2);
				duration_time_hit = (duration_timer >= 25'h07fffff);
				clr_duration = duration_time_hit;

				if (duration_time_hit)
					nxt_state = direction_reg ? C7 : too_fast ? G6 : G7_1;
			end

			G7_1 : begin
				en_duration = 1'b1;
				clr_period = (period_timer == G7_freq);
				en_period = !clr_period;
				piezo = (period_timer > G7_freq_by2);
				duration_time_hit = (duration_timer >= 25'h0bfffff);
				clr_duration = duration_time_hit;

				if (duration_time_hit) 
					nxt_state =  direction_reg ? E7_1 : E7_2;

			end

			E7_2 : begin
				en_duration = 1'b1;
				clr_period = (period_timer == E7_freq);
				en_period = !clr_period;
				piezo = (period_timer > E7_freq_by2);
				duration_time_hit = (duration_timer >= 25'h03fffff);
				clr_duration = duration_time_hit;
     			
				if (duration_time_hit) 
					nxt_state = direction_reg ? G7_1 : G7_2;
			end

			G7_2 : begin
				en_duration = 1'b1;
				clr_period = (period_timer == G7_freq);
				en_period = !clr_period;
				piezo = (period_timer > G7_freq_by2);
				duration_time_hit = (duration_timer >= 25'h1ffffff);
				clr_duration = duration_time_hit;

				if (duration_time_hit) 
					nxt_state =  direction_reg ? E7_2 : IDLE;
			end

			default : nxt_state = IDLE;
		endcase

		piezo_n = ~piezo;
	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n) begin
			state <= IDLE;
			direction_reg <= 0;
		end

		else begin
			state <= nxt_state;
			direction_reg <= direction_reg_c;
		end
	end

endmodule

module counters_slow (
	input logic clk,
	input logic rst_n,
	input logic clr_duration, 
	input logic clr_period, 
	input logic clr_repeat,
	input logic en_repeat, 
	input logic en_duration, 
	input logic en_period,
	output logic [24:0] duration_timer,
	output logic [27:0] repeat_timer,
	output logic [14:0] period_timer
);
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			duration_timer <= 0;
		else if (clr_duration)
			duration_timer <= 0;
		else if (en_duration)
			duration_timer <= duration_timer + 24'd1;
	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n)
			repeat_timer <= 0;
		else if (clr_repeat) // has 150000000 cycles 
			repeat_timer <= 0;
		else if (en_repeat)
			repeat_timer <= repeat_timer + 27'd1;
	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n)
			period_timer <=0;
		else if (clr_period)
			period_timer <=0;
		else if (en_period)
			period_timer <= period_timer + 12'd1;
	end

endmodule 

module counters_quick (
	input logic clk,
	input logic rst_n,
	input logic clr_duration, 
	input logic clr_period, 
	input logic clr_repeat,
	input logic en_repeat, 
	input logic en_duration, 
	input logic en_period,
	output logic [24:0] duration_timer,
	output logic [27:0] repeat_timer,
	output logic [14:0] period_timer
);

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			duration_timer <= 0;
		else if (clr_duration)
			duration_timer <= 0;
		else if (en_duration)
			duration_timer <= duration_timer + 24'd64;
	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n)
			repeat_timer <= 0;
		else if (clr_repeat) // has 150000000 cycles 
			repeat_timer <= 0;
		else if (en_repeat)
			repeat_timer <= repeat_timer + 27'd64;
	end

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n)
			period_timer <=0;
		else if (clr_period)
			period_timer <=0;
		else if (en_period)
			period_timer <= period_timer + 12'd64;
	end

endmodule 