
module PID_fastsim (
	input logic clk,
	input logic rst_n,
	input logic vld,
	input logic pwr_up,
	input logic rider_off,
	input logic signed [15:0] ptch,
	input logic signed [15:0] ptch_rt,
	output logic 	    [7:0]  ss_tmr,
	output logic signed [11:0] PID_cntrl );

	localparam [4:0] P_COEFF = 5'h09;

	reg [17:0] integrator;

	// SS TERM
	
	logic [26:0] ss_tmr_reg;
	logic [26:0] ss_tmr_c1, ss_tmr_c2;

	assign ss_tmr_c1 = &ss_tmr_reg[26:19] ? ss_tmr_reg : (ss_tmr_reg + 9'd256); // Fast Sim modification : increased by 256 instead of 1
	assign ss_tmr_c2 = pwr_up ? ss_tmr_c1 : 27'h0000000;

	assign ss_tmr = ss_tmr_reg [26 -: 8];

	// P TERM 
	logic signed [9:0] ptch_err_sat;
	logic signed [14:0] P_term;

        assign ptch_err_sat = ptch[15] ? (&ptch[14:9] ? ptch[9:0] : {1'b1, {9{1'b0}}}) :
					      (|ptch[14:9] ? {1'b0, {9{1'b1}}} : ptch[9:0]);
	assign P_term = $signed(P_COEFF) * ptch_err_sat;

	// I Term 
        logic signed [14:0] I_term;
        logic signed [15:0] intermediate_I;
        
	// Calculation of the integrator value 
	
	logic signed [17:0] sign_extd_ptch_err_sat, sum_ptch_err_sat, sel_ptch_err_sat, clear_ptch_err_sat;
	logic sel_ptch_lgc;
	
	assign sign_extd_ptch_err_sat = {{8{ptch_err_sat[9]}}, ptch_err_sat};
	assign sum_ptch_err_sat = integrator + sign_extd_ptch_err_sat;

	assign sel_ptch_lgc = ((sign_extd_ptch_err_sat[17] ^ sum_ptch_err_sat[17]) & ~((sign_extd_ptch_err_sat[17]^integrator[17])&|integrator)) | ~vld;
	assign sel_ptch_err_sat = sel_ptch_lgc ? integrator : sum_ptch_err_sat;

	assign clear_ptch_err_sat = rider_off ? 18'h0000 : sel_ptch_err_sat;

	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n) begin 
			integrator <= 18'h0000;
			ss_tmr_reg <= 27'h0000000;
		end
		else begin 
			integrator <= clear_ptch_err_sat;
			ss_tmr_reg <= ss_tmr_c2;
		end
	end
    
    // Fast Sim Modification --> saturation for the 15:1 bit selection
    assign intermediate_I = integrator[17] ? (&integrator[16:15] ? integrator[15:0] : 15'h8000) :
                                             (|integrator[16:15] ? 15'h7fff : integrator[15:0]);
    assign I_term = intermediate_I[15:1];
	
	// D Term 
	logic signed [12:0] D_term;	
	logic signed [12:0] D_inter;

	assign D_inter = {{3{ptch_rt[15]}}, ptch_rt[15:6]};// Divide by 64
	assign D_term = ~D_inter[12:0] + 1'b1; // 2's compilement

	// Summation of All Parts
	//
	logic signed [15:0] sum_terms;

	assign sum_terms = {{1{P_term[14]}}, P_term} + {{1{I_term[14]}}, I_term} + {{3{D_term[12]}}, D_term}; // Sign Extended Summation of All 3 parts 

	// 12 bit satuaration 
	assign PID_cntrl = sum_terms[15] ? (&sum_terms[15:11] ? sum_terms[11:0] : {1'b1, {11{1'b0}}}) :
					   (|sum_terms[15:11] ? {1'b0, {11{1'b1}}} : sum_terms[11:0]);

endmodule 
