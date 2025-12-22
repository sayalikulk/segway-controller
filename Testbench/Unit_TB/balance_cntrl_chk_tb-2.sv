module balance_cntrl_chk_tb();

	// Inputs and Outputs of the DUT
	logic clk, rst_n;
	logic vld, pwr_up, rider_off, en_steer;
	logic [15:0] ptch, ptch_rt;
	logic [11:0] steer_pot;
	logic [11:0] lft_spd, rght_spd;
    logic too_fast;

	// Instatiation of Design Under Test
	balance_cntrl iDUT (.clk(clk), .rst_n(rst_n), .vld(vld), .pwr_up(pwr_up), .rider_off(rider_off), .en_steer(en_steer), .ptch(ptch), 
	     		    .ptch_rt(ptch_rt), .steer_pot(steer_pot), .lft_spd(lft_spd), .rght_spd(rght_spd), .too_fast(too_fast));
        
	
	// Register -- memory		    
	reg [48:0] mem_stim [1499 : 0]; // memory to store stimulus
	reg [24:0] mem_resp [1499 : 0]; // memory to store the response 

	integer i;

	initial begin

		// Read the hex files and store into the respective memory
		$readmemh("balance_cntrl_stim.hex", mem_stim); 
		$readmemh("balance_cntrl_resp.hex", mem_resp);

		force iDUT.ss_tmr = 8'hff; // force the ss_tmr to 8'hff

		clk = 0; 

		// Run through 1500 Test Cases 
		for (i=0; i<1500; i=i+1) begin
			@(negedge clk); // At every negedge of the clock
			{rst_n, vld, ptch, ptch_rt, pwr_up, rider_off, steer_pot, en_steer} = mem_stim[i]; // supply the stimulus
			@(posedge clk); // And at every posedge of the clock
			#1 // after one time unit
			if ({lft_spd, rght_spd, too_fast} !== mem_resp[i]) begin // Check the outputs
				$display("Error at Test Case %d", (i+1));
				$display("Signal   Expected           Recieved ");
				$display("all %h %h", mem_resp[i], {lft_spd, rght_spd, too_fast});
				$stop;
			end
		end
        
		// If nothing goes wrong, print test passing message
		$display("All Test Cases Passed");
		$stop;

	end

	// Clock toggler
	always 
		#5 clk = ~clk;

		

endmodule
